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
        $userId = $r->userId();
        $limit = $r->queryInt('limit', 30, 1, 100);
        $offset = $r->queryInt('offset', 0, 0, 1000000);
        $unreadOnly = $r->query('unread') === 'true';

        $where = 'a.user_id = :u';
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
            'SELECT COUNT(*) AS n FROM activity_items WHERE user_id = :u AND is_read = 0',
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
        $userId = $r->userId();
        $ids = $r->input('ids');

        if (is_array($ids) && !empty($ids)) {
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
