<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;

/**
 * Persistent activity/notification inbox for the signed-in user.
 */
final class ActivityController
{
    /** List activity items (newest first). */
    public static function index(Request $r): void
    {
        Response::header('Cache-Control', 'private, no-store');
        $userId = $r->userId();
        $limit = $r->queryInt('limit', 30, 1, 100);
        $offset = $r->queryInt('offset', 0, 0, 1000000);
        $unreadOnly = $r->query('unread') === 'true';

        $where = "a.user_id = :u
            AND (a.group_id IS NULL OR EXISTS (SELECT 1 FROM group_members gm WHERE gm.group_id=a.group_id AND gm.user_id=a.user_id AND gm.status='active'))
            AND (a.actor_id IS NULL OR (EXISTS (SELECT 1 FROM users au WHERE au.id=a.actor_id AND au.status='active')
                AND NOT EXISTS (SELECT 1 FROM user_blocks b WHERE (b.blocker_id=a.user_id AND b.blocked_id=a.actor_id) OR (b.blocker_id=a.actor_id AND b.blocked_id=a.user_id))))
            AND (a.memory_id IS NULL OR EXISTS (SELECT 1 FROM memories m WHERE m.id=a.memory_id AND m.group_id=a.group_id AND m.status='active'))
            AND (a.comment_id IS NULL OR EXISTS (SELECT 1 FROM comments c WHERE c.id=a.comment_id AND c.memory_id=a.memory_id AND c.status='active'))
            AND (a.event_id IS NULL OR EXISTS (SELECT 1 FROM events e WHERE e.id=a.event_id AND e.group_id=a.group_id))
            AND (a.poll_id IS NULL OR EXISTS (SELECT 1 FROM polls p WHERE p.id=a.poll_id AND p.group_id=a.group_id
                AND (p.event_id IS NULL OR EXISTS (SELECT 1 FROM events pe WHERE pe.id=p.event_id AND pe.group_id=p.group_id))
                AND (p.memory_id IS NULL OR EXISTS (SELECT 1 FROM memories pm WHERE pm.id=p.memory_id AND pm.group_id=p.group_id AND pm.status='active'))))
            AND (a.capsule_id IS NULL OR EXISTS (SELECT 1 FROM capsules cap WHERE cap.id=a.capsule_id AND cap.group_id=a.group_id))
            AND (a.invitation_id IS NULL OR EXISTS (SELECT 1 FROM group_invitations gi WHERE gi.id=a.invitation_id AND gi.recipient_id=a.user_id AND gi.status='pending' AND gi.expires_at>UTC_TIMESTAMP()))";
        if ($unreadOnly) $where .= ' AND a.is_read = 0';

        $rows = Database::query(
            "SELECT a.*, u.display_name AS actor_name, g.name AS group_name
             FROM activity_items a
             LEFT JOIN users u ON u.id = a.actor_id
             LEFT JOIN `groups` g ON g.id = a.group_id
             WHERE {$where}
             ORDER BY a.created_at DESC, a.id DESC
             LIMIT :lim OFFSET :off",
            ['u' => $userId, 'lim' => $limit + 1, 'off' => $offset]
        );
        $more = count($rows) > $limit;
        if ($more) array_pop($rows);

        $unreadCount = (int) Database::queryOne(
            "SELECT COUNT(*) AS n FROM activity_items a WHERE {$where} AND a.is_read = 0",
            ['u' => $userId]
        )['n'];

        Response::ok([
            'items'        => array_map(self::format(...), $rows),
            'has_more'     => $more,
            'unread_count' => $unreadCount,
        ]);
    }

    /** Mark items as read. */
    public static function markRead(Request $r): void
    {
        Response::header('Cache-Control', 'private, no-store');
        $userId = $r->userId();
        $ids = $r->input('ids');

        if ($ids !== null && (!is_array($ids) || count($ids) > 100 || array_filter($ids, static fn($id) => !is_int($id) || $id < 1) !== [])) {
            Response::validationError('Choose up to 100 valid activity IDs.');
        }
        if ($ids === []) { Response::ok(null, 'No items selected.'); }
        if (is_array($ids)) {
            // Mark specific items
            $intIds = array_map('intval', array_slice($ids, 0, 100));
            $placeholders = [];
            $params = ['u' => $userId];
            foreach ($intIds as $i => $id) {
                $key = 'id' . $i;
                $placeholders[] = ':' . $key;
                $params[$key] = $id;
            }
            $in = implode(',', $placeholders);
            Database::execute(
                "UPDATE activity_items SET is_read = 1 WHERE user_id = :u AND id IN ({$in})",
                $params
            );
        } else {
            // Mark all as read
            Database::execute(
                'UPDATE activity_items SET is_read = 1 WHERE user_id = :u AND is_read = 0',
                ['u' => $userId]
            );
        }

        Response::ok(null, 'Marked as read.');
    }

    /** Write an activity item (called from other controllers). */
    public static function record(
        int $userId,
        string $kind,
        ?int $actorId = null,
        ?int $groupId = null,
        ?int $memoryId = null,
        ?int $commentId = null,
        ?int $eventId = null,
        ?int $pollId = null,
        ?int $capsuleId = null,
        ?int $invitationId = null,
        string $summary = '',
    ): void {
        Database::execute(
            'INSERT INTO activity_items (user_id, kind, actor_id, group_id, memory_id, comment_id, event_id, poll_id, capsule_id, invitation_id, summary)
             VALUES (:u, :k, :a, :g, :m, :c, :e, :p, :cap, :inv, :s)',
            [
                'u' => $userId, 'k' => $kind, 'a' => $actorId, 'g' => $groupId,
                'm' => $memoryId, 'c' => $commentId, 'e' => $eventId,
                'p' => $pollId, 'cap' => $capsuleId, 'inv' => $invitationId,
                's' => $summary,
            ]
        );
    }

    /**
     * @param array<string, mixed> $row
     * @return array<string, mixed>
     */
    private static function format(array $row): array
    {
        return [
            'id'            => (int) $row['id'],
            'kind'          => $row['kind'],
            'actor_id'      => $row['actor_id'] !== null ? (int) $row['actor_id'] : null,
            'actor_name'    => $row['actor_name'] ?? null,
            'group_id'      => $row['group_id'] !== null ? (int) $row['group_id'] : null,
            'group_name'    => $row['group_name'] ?? null,
            'memory_id'     => $row['memory_id'] !== null ? (int) $row['memory_id'] : null,
            'comment_id'    => $row['comment_id'] !== null ? (int) $row['comment_id'] : null,
            'event_id'      => $row['event_id'] !== null ? (int) $row['event_id'] : null,
            'poll_id'       => $row['poll_id'] !== null ? (int) $row['poll_id'] : null,
            'capsule_id'    => $row['capsule_id'] !== null ? (int) $row['capsule_id'] : null,
            'invitation_id' => $row['invitation_id'] !== null ? (int) $row['invitation_id'] : null,
            'summary'       => $row['summary'],
            'is_read'       => (bool) $row['is_read'],
            'created_at'    => $row['created_at'],
        ];
    }
}
