<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Core\Validator;
use Circle\Repositories\GroupRepository;
use Circle\Repositories\MemberRepository;

final class MemberController
{
    public const INVITE_DEFAULT_HOURS = 168;   // 7 days
    public const INVITE_MAX_HOURS = 720;       // 30 days
    public const INVITE_MAX_USES = 10000;

    public static function index(Request $request): void
    {
        $userId = $request->userId();
        $groupId = (int) $request->param('id');

        MemberRepository::requireActiveMember($groupId, $userId);

        $limit = $request->queryInt('limit', 50, 1, 100);
        $offset = $request->queryInt('offset', 0, 0, 1_000_000);

        Response::paginated(MemberRepository::getMembers($groupId, $limit, $offset), [
            'total' => MemberRepository::countActive($groupId),
            'limit' => $limit,
            'offset' => $offset,
        ]);
    }

    public static function updateRole(Request $request): void
    {
        $actorId = $request->userId();
        $groupId = (int) $request->param('id');
        $targetUserId = (int) $request->param('userId');
        $newRole = $request->string('role');

        MemberRepository::requireAdmin($groupId, $actorId);
        (new Validator())->enum('role', $newRole, ['admin', 'member'])->bail();

        $group = GroupRepository::findById($groupId);
        if ($group === null) {
            Response::error('not_member', 'You are not a member of this group.', 403);
        }

        if ($group['owner_user_id'] === $targetUserId) {
            Response::error('owner_protected', 'Cannot change the owner\'s role.', 422);
        }

        if (!MemberRepository::isActiveMember($groupId, $targetUserId)) {
            Response::error('member_not_found', 'That person is not a member of this group.', 404);
        }

        if ($newRole === 'member' && MemberRepository::isAdmin($groupId, $targetUserId)
            && MemberRepository::countAdmins($groupId) <= 1) {
            Response::error('last_admin', 'A group needs at least one admin.', 422);
        }

        MemberRepository::changeRole($groupId, $targetUserId, $newRole);

        Response::ok(null, 'Role updated.');
    }

    /**
     * Removes (or with ?ban=true, bans) a member from this group and every
     * descendant group. Refused while the person owns or is the last admin of
     * a descendant: the response does not name those subgroups, because the
     * acting admin may not be a member of them.
     */
    public static function remove(Request $request): void
    {
        $actorId = $request->userId();
        $groupId = (int) $request->param('id');
        $targetUserId = (int) $request->param('userId');
        $ban = filter_var($request->query('ban', 'false'), FILTER_VALIDATE_BOOLEAN);

        MemberRepository::requireAdmin($groupId, $actorId);

        $group = GroupRepository::findById($groupId);
        if ($group === null) {
            Response::error('not_member', 'You are not a member of this group.', 403);
        }

        if ($group['owner_user_id'] === $targetUserId) {
            Response::error('owner_protected', 'Cannot remove the group owner.', 422);
        }

        if ($actorId === $targetUserId) {
            Response::validationError('Use the leave endpoint to leave a group.');
        }

        if (!MemberRepository::isActiveMember($groupId, $targetUserId)) {
            Response::error('member_not_found', 'That person is not a member of this group.', 404);
        }

        if (MemberRepository::exitBlockers($groupId, $targetUserId) !== []) {
            Response::error(
                'subgroup_handover_required',
                'This member owns or is the only admin of a subgroup. Ownership must be transferred there first.',
                409
            );
        }

        Database::transaction(
            static fn (): array => MemberRepository::cascadeExit($groupId, $targetUserId, $ban ? 'banned' : 'removed')
        );

        Response::ok(null, $ban ? 'Member banned from group and removed from all subgroups.' : 'Member removed from group and all subgroups.');
    }

    /** Lifts a ban. The person is treated as removed: only a new invite link lets them back. */
    public static function unban(Request $request): void
    {
        $actorId = $request->userId();
        $groupId = (int) $request->param('id');
        $targetUserId = (int) $request->param('userId');

        MemberRepository::requireAdmin($groupId, $actorId);

        $changed = Database::execute(
            'UPDATE group_members SET status = :removed WHERE group_id = :gid AND user_id = :uid AND status = :banned',
            ['removed' => 'removed', 'gid' => $groupId, 'uid' => $targetUserId, 'banned' => 'banned']
        );
        if ($changed === 0) {
            Response::error('member_not_found', 'That person is not banned from this group.', 404);
        }

        Response::ok(null, 'Ban lifted.');
    }

    // --- Invite Links ---

    public static function createInviteLink(Request $request): void
    {
        $userId = $request->userId();
        $groupId = (int) $request->param('id');

        MemberRepository::requireActiveMember($groupId, $userId);
        $group = GroupRepository::findById($groupId);
        if ($group === null) {
            Response::error('not_member', 'You are not a member of this group.', 403);
        }
        if ($group['link_sharing'] === 'admins') {
            MemberRepository::requireAdmin($groupId, $userId);
        }

        $maxUses = $request->input('max_uses');
        $hours = $request->input('expires_in_hours', self::INVITE_DEFAULT_HOURS);

        $v = new Validator();
        if ($maxUses !== null) {
            $v->intRange('max_uses', $maxUses, 1, self::INVITE_MAX_USES);
        }
        $v->intRange('expires_in_hours', $hours, 1, self::INVITE_MAX_HOURS);
        $v->bail();

        Response::created(
            self::insertInviteLink($groupId, $userId, (int) $hours, $maxUses !== null ? (int) $maxUses : null),
            'Invite link created.'
        );
    }

    /**
     * Admins see every link of the group. Raw tokens are never stored, so they
     * cannot be shown again; this list is for auditing and revoking.
     */
    public static function listInviteLinks(Request $request): void
    {
        $groupId = (int) $request->param('id');
        MemberRepository::requireAdmin($groupId, $request->userId());

        $rows = Database::query(
            'SELECT il.id, il.created_by, u.display_name AS created_by_name, il.created_at, il.expires_at,
                    il.max_uses, il.use_count, il.revoked_at,
                    CASE
                        WHEN il.revoked_at IS NOT NULL THEN :revoked
                        WHEN il.expires_at IS NOT NULL AND il.expires_at <= NOW() THEN :expired
                        WHEN il.max_uses IS NOT NULL AND il.use_count >= il.max_uses THEN :exhausted
                        ELSE :active
                    END AS status
             FROM invite_links il
             JOIN users u ON u.id = il.created_by
             WHERE il.group_id = :gid
             ORDER BY il.id DESC
             LIMIT 200',
            ['revoked' => 'revoked', 'expired' => 'expired', 'exhausted' => 'exhausted', 'active' => 'active', 'gid' => $groupId]
        );

        Response::ok(array_map(static fn (array $r): array => [
            ...$r,
            'id' => (int) $r['id'],
            'created_by' => (int) $r['created_by'],
            'max_uses' => $r['max_uses'] !== null ? (int) $r['max_uses'] : null,
            'use_count' => (int) $r['use_count'],
        ], $rows));
    }

    /** Admins can revoke any link of the group; members can revoke links they created. */
    public static function revokeInviteLink(Request $request): void
    {
        $userId = $request->userId();
        $groupId = (int) $request->param('id');
        $linkId = (int) $request->param('linkId');

        $role = MemberRepository::getRole($groupId, $userId);
        if ($role === null) {
            Response::error('not_member', 'You are not a member of this group.', 403);
        }

        $link = Database::queryOne(
            'SELECT id, created_by FROM invite_links WHERE id = :id AND group_id = :gid',
            ['id' => $linkId, 'gid' => $groupId]
        );
        if ($link === null) {
            Response::notFound('Invite link not found.');
        }
        if ($role !== 'admin' && (int) $link['created_by'] !== $userId) {
            Response::forbidden('Admin access required.');
        }

        Database::execute(
            'UPDATE invite_links SET revoked_at = NOW(), revoked_by = :by WHERE id = :id AND revoked_at IS NULL',
            ['by' => $userId, 'id' => $linkId]
        );

        Response::ok(['id' => $linkId, 'revoked' => true], 'Invite link revoked.');
    }

    /** Revokes every active link of the group and returns one fresh default link. */
    public static function resetInviteLinks(Request $request): void
    {
        $userId = $request->userId();
        $groupId = (int) $request->param('id');
        MemberRepository::requireAdmin($groupId, $userId);

        $link = Database::transaction(static function () use ($groupId, $userId): array {
            Database::execute(
                'UPDATE invite_links SET revoked_at = NOW(), revoked_by = :by WHERE group_id = :gid AND revoked_at IS NULL',
                ['by' => $userId, 'gid' => $groupId]
            );
            return self::insertInviteLink($groupId, $userId, self::INVITE_DEFAULT_HOURS, null);
        });

        Response::created($link, 'All previous invite links revoked; new link created.');
    }

    /** @return array<string, mixed> */
    private static function insertInviteLink(int $groupId, int $userId, int $hours, ?int $maxUses): array
    {
        $token = rtrim(strtr(base64_encode(random_bytes(32)), '+/', '-_'), '=');

        Database::execute(
            'INSERT INTO invite_links (group_id, token_hash, created_by, expires_at, max_uses)
             VALUES (:gid, :hash, :uid, DATE_ADD(NOW(), INTERVAL :hours HOUR), :max)',
            [
                'gid' => $groupId,
                'hash' => hash('sha256', $token),
                'uid' => $userId,
                'hours' => $hours,
                'max' => $maxUses,
            ]
        );
        $id = Database::lastInsertId();
        $row = Database::queryOne('SELECT expires_at FROM invite_links WHERE id = :id', ['id' => $id]);

        return [
            'id' => $id,
            'token' => $token,
            'expires_at' => $row['expires_at'] ?? null,
            'max_uses' => $maxUses,
            'link' => '/i/' . $token,
        ];
    }

    /**
     * Looks up a link by raw token and classifies it in SQL time (UTC).
     * @return array<string, mixed>
     */
    private static function findUsableInvite(string $token): array
    {
        $invite = Database::queryOne(
            'SELECT il.id, il.group_id, il.max_uses, il.use_count, il.revoked_at,
                    (il.expires_at IS NOT NULL AND il.expires_at <= NOW()) AS expired,
                    g.name, g.`type`, g.cover_path, g.approval_mode, g.parent_id
             FROM invite_links il
             JOIN `groups` g ON il.group_id = g.id
             WHERE il.token_hash = :hash',
            ['hash' => hash('sha256', $token)]
        );

        if ($invite === null) {
            Response::notFound('Invite link not found.');
        }
        if ($invite['revoked_at'] !== null) {
            Response::error('link_revoked', 'This invite link has been revoked.', 410);
        }
        if ((int) $invite['expired'] === 1) {
            Response::error('link_expired', 'This invite link has expired.', 410);
        }
        if ($invite['max_uses'] !== null && (int) $invite['use_count'] >= (int) $invite['max_uses']) {
            Response::error('link_exhausted', 'This invite link has reached its usage limit.', 410);
        }

        return $invite;
    }

    public static function previewInvite(Request $request): void
    {
        $invite = self::findUsableInvite($request->param('token'));

        Response::ok([
            'group_name' => $invite['name'],
            'group_type' => $invite['type'],
            'cover_path' => $invite['cover_path'],
            'is_subgroup' => $invite['parent_id'] !== null,
            'approval_required' => $invite['approval_mode'] === 'manual',
            'member_count' => MemberRepository::countActive((int) $invite['group_id']),
        ]);
    }

    /**
     * Rules: subgroup links require ACTIVE membership of the direct parent;
     * banned people can never join through a link; removed people only through
     * a link created after their removal. A use is consumed atomically when a
     * member joins or a new pending request is created.
     */
    public static function joinViaInvite(Request $request): void
    {
        $userId = $request->userId();
        $invite = self::findUsableInvite($request->param('token'));
        $groupId = (int) $invite['group_id'];
        $linkId = (int) $invite['id'];

        if ($invite['parent_id'] !== null && !MemberRepository::isActiveMember((int) $invite['parent_id'], $userId)) {
            Response::error('not_parent_member', 'You must be a member of the parent group first.', 403);
        }

        $membership = MemberRepository::membership($groupId, $userId);
        if ($membership !== null) {
            if ($membership['status'] === 'active') {
                Response::error('already_member', 'You are already a member of this group.', 409);
            }
            if ($membership['status'] === 'banned') {
                Response::error('join_not_allowed', 'You can\'t join this group.', 403);
            }
            if ($membership['rejoin_after_link_id'] !== null && $linkId <= $membership['rejoin_after_link_id']) {
                Response::error('join_not_allowed', 'You can\'t join this group with this link. Ask an admin for a new one.', 403);
            }
        }

        $status = Database::transaction(static function () use ($invite, $groupId, $userId, $linkId): string {
            if ($invite['approval_mode'] === 'manual') {
                $pending = Database::queryOne(
                    'SELECT id FROM join_requests WHERE group_id = :gid AND user_id = :uid AND status = :s FOR UPDATE',
                    ['gid' => $groupId, 'uid' => $userId, 's' => 'pending']
                );
                if ($pending !== null) {
                    return 'pending_approval';
                }
                self::consumeInviteUse($linkId);
                Database::execute(
                    'INSERT INTO join_requests (group_id, user_id, status) VALUES (:gid, :uid, :s)',
                    ['gid' => $groupId, 'uid' => $userId, 's' => 'pending']
                );
                return 'pending_approval';
            }

            self::consumeInviteUse($linkId);
            if (!MemberRepository::addMember($groupId, $userId)) {
                Response::error('join_not_allowed', 'You can\'t join this group.', 403);
            }
            return 'joined';
        });

        $status === 'joined'
            ? Response::ok(['status' => 'joined', 'group_id' => $groupId], 'Joined group successfully.')
            : Response::ok(['status' => 'pending_approval', 'group_id' => $groupId], 'Join request sent.');
    }

    /** Atomic: fails if the link was revoked, expired or used up since it was read. */
    private static function consumeInviteUse(int $linkId): void
    {
        $updated = Database::execute(
            'UPDATE invite_links SET use_count = use_count + 1
             WHERE id = :id AND revoked_at IS NULL
               AND (expires_at IS NULL OR expires_at > NOW())
               AND (max_uses IS NULL OR use_count < max_uses)',
            ['id' => $linkId]
        );
        if ($updated !== 1) {
            Response::error('link_exhausted', 'This invite link is no longer valid.', 410);
        }
    }

    // --- Join Requests ---

    public static function joinRequests(Request $request): void
    {
        $groupId = (int) $request->param('id');

        MemberRepository::requireAdmin($groupId, $request->userId());

        // Requesters' mobile numbers are never shown to admins.
        $requests = Database::query(
            'SELECT jr.id, jr.user_id, jr.status, jr.message, jr.created_at,
                    u.display_name, u.avatar_path
             FROM join_requests jr
             JOIN users u ON jr.user_id = u.id
             WHERE jr.group_id = :gid AND jr.status = :s
             ORDER BY jr.created_at, jr.id',
            ['gid' => $groupId, 's' => 'pending']
        );

        Response::ok(array_map(static fn (array $r): array => [
            ...$r,
            'id' => (int) $r['id'],
            'user_id' => (int) $r['user_id'],
        ], $requests));
    }

    /**
     * Approval re-checks that the requester is still an active member of the
     * direct parent (and not banned); otherwise the request is cancelled.
     */
    public static function approveRequest(Request $request): void
    {
        $actorId = $request->userId();
        $groupId = (int) $request->param('id');
        $requestId = (int) $request->param('rid');

        MemberRepository::requireAdmin($groupId, $actorId);

        $outcome = Database::transaction(static function () use ($groupId, $requestId, $actorId): string {
            $jr = Database::queryOne(
                'SELECT id, user_id FROM join_requests WHERE id = :id AND group_id = :gid AND status = :s FOR UPDATE',
                ['id' => $requestId, 'gid' => $groupId, 's' => 'pending']
            );
            if ($jr === null) {
                return 'not_found';
            }
            $requesterId = (int) $jr['user_id'];

            $group = GroupRepository::findById($groupId);
            $parentOk = $group !== null
                && ($group['parent_id'] === null || MemberRepository::isActiveMember((int) $group['parent_id'], $requesterId));

            if (!$parentOk || !MemberRepository::addMember($groupId, $requesterId, 'member', null, $actorId)) {
                Database::execute(
                    'UPDATE join_requests SET status = :s, decided_by = :by WHERE id = :id',
                    ['s' => 'cancelled', 'by' => $actorId, 'id' => $requestId]
                );
                return $parentOk ? 'not_allowed' : 'not_parent_member';
            }

            Database::execute(
                'UPDATE join_requests SET status = :s, decided_by = :by WHERE id = :id',
                ['s' => 'approved', 'by' => $actorId, 'id' => $requestId]
            );
            return 'approved';
        });

        match ($outcome) {
            'not_found' => Response::notFound('Join request not found or already processed.'),
            'not_parent_member' => Response::error(
                'not_parent_member',
                'The requester is no longer a member of the parent group; the request was cancelled.',
                409
            ),
            'not_allowed' => Response::error('join_not_allowed', 'This person can\'t join this group; the request was cancelled.', 409),
            default => Response::ok(null, 'Request approved.'),
        };
    }

    public static function declineRequest(Request $request): void
    {
        $actorId = $request->userId();
        $groupId = (int) $request->param('id');
        $requestId = (int) $request->param('rid');

        MemberRepository::requireAdmin($groupId, $actorId);

        $changed = Database::execute(
            'UPDATE join_requests SET status = :s, decided_by = :by WHERE id = :id AND group_id = :gid AND status = :pending',
            ['s' => 'declined', 'by' => $actorId, 'id' => $requestId, 'gid' => $groupId, 'pending' => 'pending']
        );
        if ($changed === 0) {
            Response::notFound('Join request not found or already processed.');
        }

        Response::ok(null, 'Request declined.');
    }
}
