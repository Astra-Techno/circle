<?php

declare(strict_types=1);

namespace Circle\Repositories;

use Circle\Core\Database;
use Circle\Core\Response;

final class MemberRepository
{
    public static function isActiveMember(int $groupId, int $userId): bool
    {
        $row = Database::queryOne(
            'SELECT id FROM group_members WHERE group_id = :gid AND user_id = :uid AND status = :s',
            ['gid' => $groupId, 'uid' => $userId, 's' => 'active']
        );
        return $row !== null;
    }

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
        return $row !== null ? $row['role'] : null;
    }

    public static function isAdmin(int $groupId, int $userId): bool
    {
        return self::getRole($groupId, $userId) === 'admin';
    }

    public static function requireAdmin(int $groupId, int $userId): void
    {
        if (!self::isAdmin($groupId, $userId)) {
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

    public static function addMember(
        int $groupId,
        int $userId,
        string $role = 'member',
        string $status = 'active',
        ?int $addedBy = null
    ): void {
        Database::execute(
            'INSERT INTO group_members (group_id, user_id, role, status, added_by, joined_at)
             VALUES (:gid, :uid, :role, :status, :added, ' . ($status === 'active' ? 'NOW()' : 'NULL') . ')
             ON DUPLICATE KEY UPDATE role = :role, status = :status, joined_at = ' . ($status === 'active' ? 'NOW()' : 'joined_at'),
            ['gid' => $groupId, 'uid' => $userId, 'role' => $role, 'status' => $status, 'added' => $addedBy]
        );
    }

    public static function removeMember(int $groupId, int $userId, string $reason = 'removed'): void
    {
        Database::execute(
            'UPDATE group_members SET status = :status, left_at = NOW() WHERE group_id = :gid AND user_id = :uid AND status = :active',
            ['status' => $reason, 'gid' => $groupId, 'uid' => $userId, 'active' => 'active']
        );
    }

    public static function ensureAdmin(int $groupId, int $userId): void
    {
        Database::execute(
            'UPDATE group_members SET role = :role WHERE group_id = :gid AND user_id = :uid AND status = :s',
            ['role' => 'admin', 'gid' => $groupId, 'uid' => $userId, 's' => 'active']
        );
    }

    /**
     * Get all active members of a group.
     * @return array<int, array<string, mixed>>
     */
    public static function getMembers(int $groupId, int $limit = 50, int $offset = 0): array
    {
        return Database::query(
            'SELECT u.id, u.display_name, u.about, u.avatar_path, gm.role, gm.joined_at
             FROM group_members gm
             JOIN users u ON gm.user_id = u.id
             WHERE gm.group_id = :gid AND gm.status = :s
             ORDER BY FIELD(gm.role, "admin", "member"), u.display_name
             LIMIT :lim OFFSET :off',
            ['gid' => $groupId, 's' => 'active', 'lim' => $limit, 'off' => $offset]
        );
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
