<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Core\Validator;
use Circle\Middleware\RateLimitMiddleware;
use Circle\Notifications\NotificationOutbox;
use Circle\Repositories\MemberRepository;

/** Consent invitations, not a public mobile lookup or an automatic membership grant. */
final class GroupInvitationController
{
    public static function create(Request $request): void
    {
        if (!$request->jsonIsObject() || array_diff(array_keys($request->all()), ['mobile']) !== [] || !is_string($request->input('mobile'))) {
            Response::validationError('Send only a mobile number.');
        }
        $mobile = $request->raw('mobile');
        (new Validator())->mobile($mobile)->bail();
        // A separate committed transaction makes attempts survive any later
        // authorization/lookup rollback and serializes this sender's budget.
        Database::transaction(static function () use ($request): void {
            Database::queryOne('SELECT id FROM users WHERE id = :uid FOR UPDATE', ['uid' => $request->userId()]);
            RateLimitMiddleware::consumeForUser($request->userId(), 'contact_invitation', 20, 3600, 'Too many invitations. Please try again later.');
        });
        $result = Database::transaction(static function () use ($request, $mobile): array {
            $gid = (int) $request->param('id');
            $group = Database::queryOne('SELECT * FROM `groups` WHERE id = :gid FOR UPDATE', ['gid' => $gid]);
            $sender = self::member($gid, $request->userId(), true);
            if ($group === null || $sender === null || $sender['status'] !== 'active') {
                Response::forbidden('You are not a member of this group.', 'not_member');
            }
            if ($sender['role'] !== 'admin' && $group['link_sharing'] !== 'members') Response::forbidden('Admin access required.');
            $recipient = Database::queryOne('SELECT id FROM users WHERE mobile = :mobile', ['mobile' => $mobile]);
            if ($recipient === null) return ['outcome' => 'share_link'];
            $uid = (int) $recipient['id'];
            $users = self::users($request->userId(), $uid, true);
            if (($users[$request->userId()]['status'] ?? '') !== 'active') Response::forbidden('This account is not active.', 'account_inactive');
            if (($users[$uid]['status'] ?? '') !== 'active' || ($users[$uid]['mobile'] ?? '') !== $mobile) return ['outcome' => 'share_link'];
            $member = self::member($gid, $uid, true);
            if ($uid === $request->userId() || ($member['status'] ?? '') === 'active') return ['outcome' => 'already_member'];
            if (($member['status'] ?? '') === 'banned' || (($member['status'] ?? '') === 'removed' && $sender['role'] !== 'admin') || !self::parentOk($group, $uid, true)) {
                return ['outcome' => 'unavailable'];
            }
            $old = Database::queryOne('SELECT *, expires_at <= NOW(6) AS expired, updated_at > DATE_SUB(NOW(6), INTERVAL 24 HOUR) AS cooling FROM group_invitations WHERE group_id = :gid AND recipient_id = :uid ORDER BY id DESC LIMIT 1 FOR UPDATE', ['gid' => $gid, 'uid' => $uid]);
            if ($old !== null && $old['status'] === 'pending' && !(bool) $old['expired']) {
                // Invitations predating removal cannot be used to evade it.
                if (($member['status'] ?? '') !== 'removed' || $member['left_at'] === null || $old['created_at'] > $member['left_at']) {
                    return ['outcome' => 'already_pending', 'invitation_id' => (int) $old['id']];
                }
            }
            if ($old !== null && $old['status'] !== 'pending' && (bool) $old['cooling']) return ['outcome' => 'unavailable'];
            if ($old !== null && $old['status'] === 'pending') {
                Database::execute("UPDATE group_invitations SET status = 'expired' WHERE id = :id", ['id' => (int) $old['id']]);
            }
            Database::execute("INSERT INTO group_invitations (group_id, recipient_id, inviter_id, expires_at) VALUES (:gid, :uid, :by, DATE_ADD(NOW(6), INTERVAL 7 DAY))", ['gid' => $gid, 'uid' => $uid, 'by' => $request->userId()]);
            $id = Database::lastInsertId();
            NotificationOutbox::groupInvitationCreated($id);
            return ['outcome' => 'invited', 'invitation_id' => $id];
        });
        Response::ok($result);
    }

    public static function index(Request $request): void
    {
        $limit = $request->queryInt('limit', 50, 1, 100);
        $offset = $request->queryInt('offset', 0, 0, 1_000_000);
        $rows = Database::query(self::select() . ' WHERE i.recipient_id = :uid ORDER BY i.updated_at DESC, i.id DESC LIMIT :lim OFFSET :off', ['uid' => $request->userId(), 'lim' => $limit, 'off' => $offset]);
        $total = Database::queryOne('SELECT COUNT(*) AS total FROM group_invitations WHERE recipient_id = :uid', ['uid' => $request->userId()]);
        Response::paginated(array_map(self::payload(...), $rows), ['total' => (int) ($total['total'] ?? 0), 'limit' => $limit, 'offset' => $offset]);
    }

    public static function show(Request $request): void
    {
        Response::ok(['invitation' => self::payload(self::owned($request))]);
    }

    public static function accept(Request $request): void
    {
        self::emptyBody($request);
        $initial = self::owned($request);
        $result = Database::transaction(static function () use ($request, $initial): array {
            $group = Database::queryOne('SELECT * FROM `groups` WHERE id = :gid FOR UPDATE', ['gid' => (int) $initial['group_id']]);
            $row = Database::queryOne(self::select() . ' WHERE i.id = :id AND i.recipient_id = :uid FOR UPDATE', ['id' => (int) $initial['id'], 'uid' => $request->userId()]);
            if ($row === null || $group === null) Response::notFound('Invitation not found.');
            if ($row['status'] === 'accepted') return ['invitation' => self::payload($row), 'status' => 'accepted'];
            if ($row['status'] !== 'pending') return ['error' => 'unavailable'];
            if ((bool) $row['expired']) {
                Database::execute("UPDATE group_invitations SET status = 'expired' WHERE id = :id", ['id' => (int) $row['id']]);
                return ['error' => 'expired'];
            }
            if (!self::allowed($row, $group, true)) return ['error' => 'unavailable'];
            $gid = (int) $row['group_id'];
            $uid = $request->userId();
            $inviter = self::member($gid, (int) $row['inviter_id'], true);
            $needsApproval = $group['approval_mode'] === 'manual' && ($inviter['role'] ?? '') !== 'admin';
            if ($needsApproval && (self::member($gid, $uid, true)['status'] ?? '') !== 'active') {
                $pending = Database::queryOne("SELECT id FROM join_requests WHERE group_id = :gid AND user_id = :uid AND status = 'pending' FOR UPDATE", ['gid' => $gid, 'uid' => $uid]);
                if ($pending === null) Database::execute("INSERT INTO join_requests (group_id, user_id, status) VALUES (:gid, :uid, 'pending')", ['gid' => $gid, 'uid' => $uid]);
                $status = 'pending_approval';
            } else {
                if (!MemberRepository::addMember($gid, $uid, 'member', (int) $row['inviter_id'], ($inviter['role'] ?? '') === 'admin' ? (int) $row['inviter_id'] : null)) return ['error' => 'unavailable'];
                $status = 'joined';
            }
            Database::execute("UPDATE group_invitations SET status = 'accepted', updated_at = NOW(6) WHERE id = :id", ['id' => (int) $row['id']]);
            $row['status'] = 'accepted';
            return ['invitation' => self::payload($row), 'status' => $status];
        });
        if (($result['error'] ?? '') === 'expired') Response::error('invitation_expired', 'This invitation has expired.', 410);
        if (isset($result['error'])) Response::forbidden('This invitation is no longer available.', 'invitation_unavailable');
        Response::ok($result);
    }

    public static function decline(Request $request): void
    {
        self::emptyBody($request);
        $initial = self::owned($request);
        $row = Database::transaction(static function () use ($request, $initial): array {
            Database::queryOne('SELECT id FROM `groups` WHERE id = :gid FOR UPDATE', ['gid' => (int) $initial['group_id']]);
            $row = Database::queryOne(self::select() . ' WHERE i.id = :id AND i.recipient_id = :uid FOR UPDATE', ['id' => (int) $initial['id'], 'uid' => $request->userId()]);
            if ($row === null) Response::notFound('Invitation not found.');
            if ($row['status'] === 'pending') {
                $row['status'] = (bool) $row['expired'] ? 'expired' : 'declined';
                Database::execute('UPDATE group_invitations SET status = :status, updated_at = NOW(6) WHERE id = :id', ['status' => $row['status'], 'id' => (int) $row['id']]);
            }
            return $row;
        });
        Response::ok(['invitation' => self::payload($row), 'status' => $row['status']]);
    }

    /** Recheck before push delivery; knowing a mobile never authorizes a lookup. */
    public static function eligible(int $invitationId, int $recipientId): bool
    {
        $row = Database::queryOne(self::select() . ' WHERE i.id = :id AND i.recipient_id = :uid', ['id' => $invitationId, 'uid' => $recipientId]);
        if ($row === null || $row['status'] !== 'pending' || (bool) $row['expired']) return false;
        $group = Database::queryOne('SELECT * FROM `groups` WHERE id = :gid', ['gid' => (int) $row['group_id']]);
        return $group !== null && self::allowed($row, $group, false) && (self::member((int) $row['group_id'], $recipientId, false)['status'] ?? '') !== 'active';
    }

    /**
     * @param array<string, mixed> $row
     * @param array<string, mixed> $group
     */
    private static function allowed(array $row, array $group, bool $lock): bool
    {
        $users = self::users((int) $row['inviter_id'], (int) $row['recipient_id'], $lock);
        if (($users[(int) $row['inviter_id']]['status'] ?? '') !== 'active' || ($users[(int) $row['recipient_id']]['status'] ?? '') !== 'active') return false;
        $sender = self::member((int) $row['group_id'], (int) $row['inviter_id'], $lock);
        if ($sender === null || $sender['status'] !== 'active' || ($sender['role'] !== 'admin' && $group['link_sharing'] !== 'members')) return false;
        $member = self::member((int) $row['group_id'], (int) $row['recipient_id'], $lock);
        if (($member['status'] ?? '') === 'banned') return false;
        if (($member['status'] ?? '') === 'removed' && ($sender['role'] !== 'admin' || ($member['left_at'] !== null && $row['created_at'] <= $member['left_at']))) return false;
        return self::parentOk($group, (int) $row['recipient_id'], $lock);
    }

    /** @param array<string, mixed> $group */
    private static function parentOk(array $group, int $uid, bool $lock): bool
    {
        return $group['parent_id'] === null || (self::member((int) $group['parent_id'], $uid, $lock)['status'] ?? '') === 'active';
    }

    /** @return array<string, mixed>|null */
    private static function member(int $gid, int $uid, bool $lock): ?array
    {
        return Database::queryOne('SELECT role, status, left_at FROM group_members WHERE group_id = :gid AND user_id = :uid' . ($lock ? ' FOR UPDATE' : ''), ['gid' => $gid, 'uid' => $uid]);
    }

    /** @return array<int, array<string, mixed>> */
    private static function users(int $first, int $second, bool $lock): array
    {
        $rows = Database::query('SELECT id, status, mobile FROM users WHERE id IN (:first, :second) ORDER BY id' . ($lock ? ' FOR UPDATE' : ''), ['first' => $first, 'second' => $second]);
        $users = [];
        foreach ($rows as $row) $users[(int) $row['id']] = $row;
        return $users;
    }

    private static function select(): string
    {
        return 'SELECT i.*, g.name AS group_name, g.approval_mode, gm.role AS inviter_role, u.display_name AS inviter_name, (i.expires_at <= NOW(6)) AS expired FROM group_invitations i JOIN `groups` g ON g.id = i.group_id JOIN users u ON u.id = i.inviter_id LEFT JOIN group_members gm ON gm.group_id = i.group_id AND gm.user_id = i.inviter_id';
    }

    /** @return array<string, mixed> */
    private static function owned(Request $request): array
    {
        $row = Database::queryOne(self::select() . ' WHERE i.id = :id AND i.recipient_id = :uid', ['id' => (int) $request->param('invitationId'), 'uid' => $request->userId()]);
        if ($row === null) Response::notFound('Invitation not found.');
        return $row;
    }

    /**
     * @param array<string, mixed> $row
     * @return array<string, mixed>
     */
    private static function payload(array $row): array
    {
        return ['id' => (int) $row['id'], 'recipient_id' => (int) $row['recipient_id'], 'group_id' => (int) $row['group_id'], 'group_name' => $row['group_name'], 'inviter_name' => $row['inviter_name'], 'status' => $row['status'] === 'pending' && (bool) $row['expired'] ? 'expired' : $row['status'], 'expires_at' => $row['expires_at'], 'approval_required' => $row['approval_mode'] === 'manual' && $row['inviter_role'] !== 'admin'];
    }

    private static function emptyBody(Request $request): void
    {
        if (!$request->jsonIsObject() || $request->all() !== []) Response::validationError('Send an empty JSON object.');
    }
}
