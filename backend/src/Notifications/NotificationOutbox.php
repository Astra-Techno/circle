<?php

declare(strict_types=1);

namespace Circle\Notifications;

use Circle\Core\Database;
use Circle\Core\Env;

/** Capture recipient/device snapshots in the same transaction as the mutation. */
final class NotificationOutbox
{
    public static function memoryCreated(int $memoryId): void
    {
        self::capture($memoryId, null);
    }

    public static function commentCreated(int $memoryId, int $commentId): void
    {
        self::capture($memoryId, $commentId);
    }

    private static function capture(int $memoryId, ?int $commentId): void
    {
        if (Env::get('PUSH_QUEUE_ENABLED', 'false') !== 'true') return;
        if (!Database::connection()->inTransaction()) throw new \LogicException('Notification capture requires the mutation transaction.');
        $comment = $commentId === null ? null : Database::queryOne(
            "SELECT author_id, parent_id FROM comments WHERE id = :cid AND memory_id = :mid AND status = 'active'",
            ['cid' => $commentId, 'mid' => $memoryId]
        );
        if ($commentId !== null && $comment === null) return;
        $kind = $comment === null ? 'memory.created' : ($comment['parent_id'] === null ? 'comment.created' : 'comment.reply');
        $category = $comment === null ? 'memories' : 'replies_reactions';
        $actor = $comment === null ? 'm.author_id' : ':actor';
        $recipients = $comment === null ? '' : " AND (gm.user_id = m.author_id OR gm.user_id IN
            (SELECT author_id FROM comments WHERE id = :parent_id AND memory_id = :parent_mid AND status = 'active'))";
        $params = ['mid' => $memoryId, 'key' => $kind . ':' . ($commentId ?? $memoryId), 'kind' => $kind,
            'cid' => $commentId, 'category' => '$.' . $category];
        if ($comment !== null) {
            $params['actor'] = (int) $comment['author_id'];
            $params['parent_id'] = $comment['parent_id'];
            $params['parent_mid'] = $memoryId;
        }
        Database::execute(
            "INSERT INTO notification_outbox (event_key, kind, user_id, device_id, session_id, group_id, memory_id, comment_id, expires_at)
             SELECT :key, :kind, gm.user_id, dt.id, dt.session_id, m.group_id, m.id, :cid, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 24 HOUR)
             FROM memories m
             JOIN group_members gm ON gm.group_id = m.group_id AND gm.status = 'active'
             JOIN users u ON u.id = gm.user_id AND u.status = 'active'
             JOIN notification_preferences np ON np.user_id = u.id AND np.enabled = 1
             JOIN device_tokens dt ON dt.user_id = u.id AND dt.session_id IS NOT NULL AND dt.platform = 'android'
             WHERE m.id = :mid AND m.status = 'active' AND gm.user_id <> {$actor}
             AND JSON_UNQUOTE(JSON_EXTRACT(np.categories, :category)) = 'true'
             AND EXISTS (SELECT 1 FROM refresh_tokens rt WHERE rt.user_id = dt.user_id AND rt.session_id = dt.session_id
                 AND rt.revoked_at IS NULL AND rt.expires_at > UTC_TIMESTAMP())
             {$recipients}
             ON DUPLICATE KEY UPDATE event_key = notification_outbox.event_key",
            $params
        );
    }
}
