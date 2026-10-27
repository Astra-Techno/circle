<?php

declare(strict_types=1);

namespace Circle\Repositories;

use Circle\Core\Database;
use Circle\Core\Response;

/**
 * Central membership checks. Authorization is always active membership in the
 * EXACT group id: membership of a parent or child never grants access.
 */
final class MemberRepository
{
    /** @return array{role: string, status: string, rejoin_after_link_id: int|null}|null */
    public static function membership(int $groupId, int $userId): ?array
    {
        $row = Database::queryOne(
            'SELECT role, status, rejoin_after_link_id FROM group_members WHERE group_id = :gid AND user_id = :uid',
            ['gid' => $groupId, 'uid' => $userId]
        );
        if ($row === null) {
            return null;
        }
        return [
            'role' => (string) $row['role'],
            'status' => (string) $row['status'],
            'rejoin_after_link_id' => $row['rejoin_after_link_id'] !== null ? (int) $row['rejoin_after_link_id'] : null,
        ];
    }

    public static function isActiveMember(int $groupId, int $userId): bool
    {
        return self::getRole($groupId, $userId) !== null;
    }

    /**
     * Same response for "group does not exist" and "not a member", so group ids
     * cannot be probed.
     */
    public static function requireActiveMember(int $groupId, int $userId): void
    {
        if (!self::isActiveMember($groupId, $userId)) {
            Response::error('not_member', 'You are not a member of this group.', 403);
        }
    }

    public static function getRole(int $groupId, int $userId): ?string
    {
        $row = Database::queryOne(
            'SELECT role FROM group_members WHERE group_id = :gid AND user_id = :uid AND status = :s',
            ['gid' => $groupId, 'uid' => $userId, 's' => 'active']
        );
        return $row !== null ? (string) $row['role'] : null;
    }

    public static function isAdmin(int $groupId, int $userId): bool
    {
        return self::getRole($groupId, $userId) === 'admin';
    }

    public static function requireAdmin(int $groupId, int $userId): void
    {
        $role = self::getRole($groupId, $userId);
        if ($role === null) {
            Response::error('not_member', 'You are not a member of this group.', 403);
        }
        if ($role !== 'admin') {
            Response::forbidden('Admin access required.');
        }
    }

    public static function countActive(int $groupId): int
    {
        $row = Database::queryOne(
            'SELECT COUNT(*) AS cnt FROM group_members WHERE group_id = :gid AND status = :s',
            ['gid' => $groupId, 's' => 'active']
        );
        return (int) ($row['cnt'] ?? 0);
    }

    public static function countAdmins(int $groupId): int
    {
        $row = Database::queryOne(
            'SELECT COUNT(*) AS cnt FROM group_members WHERE group_id = :gid AND role = :r AND status = :s',
            ['gid' => $groupId, 'r' => 'admin', 's' => 'active']
        );
        return (int) ($row['cnt'] ?? 0);
    }

    /**
     * Adds or re-activates a membership. Never re-activates a `banned` member:
     * returns false in that case. Re-joining members always start with $role.
     */
    public static function addMember(
        int $groupId,
        int $userId,
        string $role = 'member',
        ?int $addedBy = null,
        ?int $approvedBy = null
    ): bool {
        $existing = Database::queryOne(
            'SELECT id, status FROM group_members WHERE group_id = :gid AND user_id = :uid FOR UPDATE',
            ['gid' => $groupId, 'uid' => $userId]
        );

        if ($existing === null) {
            Database::execute(
                'INSERT INTO group_members (group_id, user_id, role, status, added_by, approved_by, joined_at)
                 VALUES (:gid, :uid, :role, :status, :added, :approved, NOW())',
                [
                    'gid' => $groupId,
                    'uid' => $userId,
                    'role' => $role,
                    'status' => 'active',
                    'added' => $addedBy,
                    'approved' => $approvedBy,
                ]
            );
            return true;
        }

        if ($existing['status'] === 'banned') {
            return false;
        }
        if ($existing['status'] === 'active') {
            return true;
        }

        Database::execute(
            'UPDATE group_members
             SET role = :role, status = :status, added_by = :added, approved_by = :approved,
                 joined_at = NOW(), left_at = NULL, rejoin_after_link_id = NULL
             WHERE id = :id',
            [
                'role' => $role,
                'status' => 'active',
                'added' => $addedBy,
                'approved' => $approvedBy,
                'id' => (int) $existing['id'],
            ]
        );
        return true;
    }

    /**
     * Ends an active membership. For `removed`/`banned`, every invite link that
     * already exists for the group stops working for this person.
     */
    public static function removeMember(int $groupId, int $userId, string $reason = 'removed'): bool
    {
        if (!Database::connection()->inTransaction()) {
            return Database::transaction(static fn (): bool => self::removeMember($groupId, $userId, $reason));
        }
        Database::queryOne('SELECT id FROM `groups` WHERE id = :gid FOR UPDATE', ['gid' => $groupId]);
        $rejoinAfter = null;
        if ($reason !== 'left') {
            $row = Database::queryOne(
                'SELECT COALESCE(MAX(id), 0) AS max_id FROM invite_links WHERE group_id = :gid',
                ['gid' => $groupId]
            );
            $rejoinAfter = (int) ($row['max_id'] ?? 0);
        }

        $changed = Database::execute(
            'UPDATE group_members
             SET status = :status, left_at = NOW(), rejoin_after_link_id = :rejoin
             WHERE group_id = :gid AND user_id = :uid AND status = :active',
            ['status' => $reason, 'rejoin' => $rejoinAfter, 'gid' => $groupId, 'uid' => $userId, 'active' => 'active']
        ) > 0;
        if ($changed) {
            Database::execute("UPDATE group_invitations SET status = 'expired', updated_at = NOW(6) WHERE group_id = :gid AND (recipient_id = :recipient OR inviter_id = :inviter) AND status = 'pending'",
                ['gid' => $groupId, 'recipient' => $userId, 'inviter' => $userId]);
        }
        return $changed;
    }

    /**
     * Groups in the subtree rooted at $groupId (inclusive) that would be left
     * without an owner or without any admin if $userId exited them.
     *
     * @return array<int, array{id: int, name: string, reason: string}>
     */
    public static function exitBlockers(int $groupId, int $userId): array
    {
        $rows = Database::query(
            'SELECT g.id, g.name, g.owner_user_id, gm.role,
                    (SELECT COUNT(*) FROM group_members a
                     WHERE a.group_id = g.id AND a.role = :admin AND a.status = :active_a) AS admin_count
             FROM group_closure gc
             JOIN `groups` g ON g.id = gc.descendant_id
             JOIN group_members gm ON gm.group_id = g.id AND gm.user_id = :uid AND gm.status = :active_m
             WHERE gc.ancestor_id = :gid
             ORDER BY g.depth, g.name',
            ['admin' => 'admin', 'active_a' => 'active', 'uid' => $userId, 'active_m' => 'active', 'gid' => $groupId]
        );

        $blockers = [];
        foreach ($rows as $row) {
            if ((int) $row['owner_user_id'] === $userId) {
                $blockers[] = ['id' => (int) $row['id'], 'name' => (string) $row['name'], 'reason' => 'owner'];
            } elseif ($row['role'] === 'admin' && (int) $row['admin_count'] <= 1) {
                $blockers[] = ['id' => (int) $row['id'], 'name' => (string) $row['name'], 'reason' => 'last_admin'];
            }
        }
        return $blockers;
    }

    /**
     * Ends membership in $groupId and every descendant (cascade), cancels the
     * person's pending join requests in that subtree and revokes invite links
     * they created there. Call inside a transaction, after exitBlockers().
     *
     * @return int[] ids of groups where an active membership ended
     */
    public static function cascadeExit(int $groupId, int $userId, string $reason): array
    {
        $ids = array_merge([$groupId], GroupRepository::getDescendantIds($groupId));

        $ended = [];
        foreach ($ids as $i => $gid) {
            // A ban applies to the group acted on; descendants are a plain removal
            // (re-joining them needs the parent membership anyway).
            $status = $reason === 'banned' && $i > 0 ? 'removed' : $reason;
            if (self::removeMember($gid, $userId, $status)) {
                $ended[] = $gid;
            }
        }

        Database::execute(
            'UPDATE join_requests jr
             JOIN group_closure gc ON gc.descendant_id = jr.group_id AND gc.ancestor_id = :gid
             SET jr.status = :cancelled
             WHERE jr.user_id = :uid AND jr.status = :pending',
            ['gid' => $groupId, 'cancelled' => 'cancelled', 'uid' => $userId, 'pending' => 'pending']
        );

        Database::execute(
            'UPDATE invite_links il
             JOIN group_closure gc ON gc.descendant_id = il.group_id AND gc.ancestor_id = :gid
             SET il.revoked_at = NOW(), il.revoked_by = :by
             WHERE il.created_by = :uid AND il.revoked_at IS NULL',
            ['gid' => $groupId, 'by' => $userId, 'uid' => $userId]
        );

        // Also invalidate pending child invitations where the exiting person
        // had not joined yet; parent re-entry must not revive those old grants.
        Database::execute("UPDATE group_invitations i JOIN group_closure gc ON gc.descendant_id = i.group_id AND gc.ancestor_id = :gid
            SET i.status = 'expired', i.updated_at = NOW(6)
            WHERE (i.recipient_id = :recipient OR i.inviter_id = :inviter) AND i.status = 'pending'",
            ['gid' => $groupId, 'recipient' => $userId, 'inviter' => $userId]);

        return $ended;
    }

    public static function ensureAdmin(int $groupId, int $userId): void
    {
        Database::execute(
            'UPDATE group_members SET role = :role WHERE group_id = :gid AND user_id = :uid AND status = :s',
            ['role' => 'admin', 'gid' => $groupId, 'uid' => $userId, 's' => 'active']
        );
    }

    /**
     * Get active members of a group. Never includes mobile numbers.
     * @return array<int, array<string, mixed>>
     */
    public static function getMembers(int $groupId, int $limit = 50, int $offset = 0): array
    {
        $rows = Database::query(
            "SELECT u.id, u.display_name, u.about, u.avatar_path, gm.role, gm.joined_at,
                    (g.owner_user_id = u.id) AS is_owner
             FROM group_members gm
             JOIN users u ON gm.user_id = u.id
             JOIN `groups` g ON g.id = gm.group_id
             WHERE gm.group_id = :gid AND gm.status = :s
             ORDER BY FIELD(gm.role, 'admin', 'member'), u.display_name, u.id
             LIMIT :lim OFFSET :off",
            ['gid' => $groupId, 's' => 'active', 'lim' => $limit, 'off' => $offset]
        );
        return array_map(static fn (array $r): array => [
            ...$r,
            'id' => (int) $r['id'],
            'is_owner' => (bool) $r['is_owner'],
        ], $rows);
    }

    /**
     * Promote or demote a member.
     */
    public static function changeRole(int $groupId, int $userId, string $newRole): void
    {
        Database::execute(
            'UPDATE group_members SET role = :role WHERE group_id = :gid AND user_id = :uid AND status = :s',
            ['role' => $newRole, 'gid' => $groupId, 'uid' => $userId, 's' => 'active']
        );
    }
}
