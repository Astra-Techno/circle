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
    public static function index(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $groupId = (int) $request->param('id');

        MemberRepository::requireActiveMember($groupId, $userId);

        $limit = min((int) $request->query('limit', '50'), 100);
        $offset = max((int) $request->query('offset', '0'), 0);

        $members = MemberRepository::getMembers($groupId, $limit, $offset);
        $total = MemberRepository::countActive($groupId);

        Response::paginated($members, [
            'total' => $total,
            'limit' => $limit,
            'offset' => $offset,
        ]);
    }

    public static function updateRole(Request $request): void
    {
        $actorId = (int) $request->attr('user_id');
        $groupId = (int) $request->param('id');
        $targetUserId = (int) $request->param('userId');
        $newRole = $request->string('role');

        (new Validator())->enum('role', $newRole, ['admin', 'member'])->bail();

        MemberRepository::requireAdmin($groupId, $actorId);

        $group = GroupRepository::findById($groupId);
        if ($group === null) {
            Response::notFound('Group not found.');
        }

        // Cannot change owner's role
        if ((int) $group['owner_user_id'] === $targetUserId) {
            Response::error('owner_protected', 'Cannot change the owner\'s role.', 422);
        }

        MemberRepository::requireActiveMember($groupId, $targetUserId);
        MemberRepository::changeRole($groupId, $targetUserId, $newRole);

        Response::ok(null, 'Role updated.');
    }

    public static function remove(Request $request): void
    {
        $actorId = (int) $request->attr('user_id');
        $groupId = (int) $request->param('id');
        $targetUserId = (int) $request->param('userId');

        MemberRepository::requireAdmin($groupId, $actorId);

        $group = GroupRepository::findById($groupId);
        if ($group === null) {
            Response::notFound('Group not found.');
        }

        // Cannot remove the owner
        if ((int) $group['owner_user_id'] === $targetUserId) {
            Response::error('owner_protected', 'Cannot remove the group owner.', 422);
        }

        // Cannot remove yourself via this endpoint (use leave)
        if ($actorId === $targetUserId) {
            Response::validationError('Use the leave endpoint to leave a group.');
        }

        // Cascade: remove from this group and all descendant groups
        Database::beginTransaction();
        try {
            $descendantIds = GroupRepository::getDescendantIds($groupId);
            $allGroupIds = array_merge([$groupId], $descendantIds);

            foreach ($allGroupIds as $gid) {
                MemberRepository::removeMember($gid, $targetUserId, 'removed');
            }

            Database::commit();
            Response::ok(null, 'Member removed from group and all subgroups.');

        } catch (\Throwable $e) {
            Database::rollback();
            Response::serverError('Failed to remove member.');
        }
    }

    // --- Invite Links ---

    public static function createInviteLink(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $groupId = (int) $request->param('id');

        $group = GroupRepository::findById($groupId);
        if ($group === null) {
            Response::notFound('Group not found.');
        }

        // Check link sharing permission
        if ($group['link_sharing'] === 'admins') {
            MemberRepository::requireAdmin($groupId, $userId);
        } else {
            MemberRepository::requireActiveMember($groupId, $userId);
        }

        $maxUses = $request->input('max_uses');
        $expiresInHours = $request->int('expires_in_hours', 168); // Default 7 days

        $token = bin2hex(random_bytes(32));
        $tokenHash = hash('sha256', $token);
        $expiresAt = date('Y-m-d H:i:s', time() + ($expiresInHours * 3600));

        Database::execute(
            'INSERT INTO invite_links (group_id, token_hash, created_by, expires_at, max_uses)
             VALUES (:gid, :hash, :uid, :exp, :max)',
            [
                'gid' => $groupId,
                'hash' => $tokenHash,
                'uid' => $userId,
                'exp' => $expiresAt,
                'max' => $maxUses,
            ]
        );

        Response::created([
            'token' => $token,
            'expires_at' => $expiresAt,
            'max_uses' => $maxUses,
            'link' => '/i/' . $token,
        ], 'Invite link created.');
    }

    public static function previewInvite(Request $request): void
    {
        $token = $request->param('token');
        $tokenHash = hash('sha256', $token);

        $invite = Database::queryOne(
            'SELECT il.id, il.group_id, il.expires_at, il.max_uses, il.use_count, il.revoked_at,
                    g.name, g.`type`, g.cover_path, g.approval_mode
             FROM invite_links il
             JOIN `groups` g ON il.group_id = g.id
             WHERE il.token_hash = :hash',
            ['hash' => $tokenHash]
        );

        if ($invite === null) {
            Response::notFound('Invite link not found.');
        }

        if ($invite['revoked_at'] !== null) {
            Response::error('link_revoked', 'This invite link has been revoked.', 410);
        }

        if ($invite['expires_at'] !== null && strtotime($invite['expires_at']) < time()) {
            Response::error('link_expired', 'This invite link has expired.', 410);
        }

        if ($invite['max_uses'] !== null && (int) $invite['use_count'] >= (int) $invite['max_uses']) {
            Response::error('link_exhausted', 'This invite link has reached its usage limit.', 410);
        }

        Response::ok([
            'group_name' => $invite['name'],
            'group_type' => $invite['type'],
            'cover_path' => $invite['cover_path'],
            'approval_required' => $invite['approval_mode'] === 'manual',
            'member_count' => MemberRepository::countActive((int) $invite['group_id']),
        ]);
    }

    public static function joinViaInvite(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $token = $request->param('token');
        $tokenHash = hash('sha256', $token);

        $invite = Database::queryOne(
            'SELECT il.id, il.group_id, il.expires_at, il.max_uses, il.use_count, il.revoked_at,
                    g.approval_mode, g.parent_id
             FROM invite_links il
             JOIN `groups` g ON il.group_id = g.id
             WHERE il.token_hash = :hash',
            ['hash' => $tokenHash]
        );

        if ($invite === null) {
            Response::notFound('Invite link not found.');
        }

        if ($invite['revoked_at'] !== null) {
            Response::error('link_revoked', 'This invite link has been revoked.', 410);
        }

        if ($invite['expires_at'] !== null && strtotime($invite['expires_at']) < time()) {
            Response::error('link_expired', 'This invite link has expired.', 410);
        }

        if ($invite['max_uses'] !== null && (int) $invite['use_count'] >= (int) $invite['max_uses']) {
            Response::error('link_exhausted', 'This invite link has reached its usage limit.', 410);
        }

        $groupId = (int) $invite['group_id'];

        // Subgroup rule: must be member of parent group
        if ($invite['parent_id'] !== null) {
            $parentId = (int) $invite['parent_id'];
            if (!MemberRepository::isActiveMember($parentId, $userId)) {
                Response::error('not_parent_member', 'You must be a member of the parent group first.', 403);
            }
        }

        // Already a member?
        if (MemberRepository::isActiveMember($groupId, $userId)) {
            Response::error('already_member', 'You are already a member of this group.', 409);
        }

        Database::beginTransaction();
        try {
            if ($invite['approval_mode'] === 'manual') {
                // Create join request
                Database::execute(
                    'INSERT INTO join_requests (group_id, user_id) VALUES (:gid, :uid)
                     ON DUPLICATE KEY UPDATE status = :pending, updated_at = NOW()',
                    ['gid' => $groupId, 'uid' => $userId, 'pending' => 'pending']
                );
                Database::commit();
                Response::ok(['status' => 'pending_approval'], 'Join request sent.');
            } else {
                // Direct join
                MemberRepository::addMember($groupId, $userId);

                // Increment use count
                Database::execute(
                    'UPDATE invite_links SET use_count = use_count + 1 WHERE id = :id',
                    ['id' => $invite['id']]
                );

                Database::commit();
                Response::ok(['status' => 'joined'], 'Joined group successfully.');
            }
        } catch (\Throwable $e) {
            Database::rollback();
            Response::serverError('Failed to join group.');
        }
    }

    // --- Join Requests ---

    public static function joinRequests(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $groupId = (int) $request->param('id');

        MemberRepository::requireAdmin($groupId, $userId);

        $requests = Database::query(
            'SELECT jr.id, jr.user_id, jr.status, jr.message, jr.created_at,
                    u.display_name, u.mobile
             FROM join_requests jr
             JOIN users u ON jr.user_id = u.id
             WHERE jr.group_id = :gid AND jr.status = :s
             ORDER BY jr.created_at',
            ['gid' => $groupId, 's' => 'pending']
        );

        Response::ok($requests);
    }

    public static function approveRequest(Request $request): void
    {
        $actorId = (int) $request->attr('user_id');
        $groupId = (int) $request->param('id');
        $requestId = (int) $request->param('rid');

        MemberRepository::requireAdmin($groupId, $actorId);

        $jr = Database::queryOne(
            'SELECT id, user_id, status FROM join_requests WHERE id = :id AND group_id = :gid',
            ['id' => $requestId, 'gid' => $groupId]
        );

        if ($jr === null || $jr['status'] !== 'pending') {
            Response::notFound('Join request not found or already processed.');
        }

        Database::beginTransaction();
        try {
            Database::execute(
                'UPDATE join_requests SET status = :s, decided_by = :by WHERE id = :id',
                ['s' => 'approved', 'by' => $actorId, 'id' => $requestId]
            );

            MemberRepository::addMember($groupId, (int) $jr['user_id'], 'member', 'active', $actorId);

            Database::commit();
            Response::ok(null, 'Request approved.');

        } catch (\Throwable $e) {
            Database::rollback();
            Response::serverError('Failed to approve request.');
        }
    }

    public static function declineRequest(Request $request): void
    {
        $actorId = (int) $request->attr('user_id');
        $groupId = (int) $request->param('id');
        $requestId = (int) $request->param('rid');

        MemberRepository::requireAdmin($groupId, $actorId);

        Database::execute(
            'UPDATE join_requests SET status = :s, decided_by = :by WHERE id = :id AND group_id = :gid AND status = :pending',
            ['s' => 'declined', 'by' => $actorId, 'id' => $requestId, 'gid' => $groupId, 'pending' => 'pending']
        );

        Response::ok(null, 'Request declined.');
    }
}
