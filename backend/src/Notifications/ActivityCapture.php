<?php

declare(strict_types=1);
namespace Circle\Notifications;

use Circle\Core\Database;

/** In-app activity is independent of push preferences and registered devices. */
final class ActivityCapture
{
    public static function memory(int $memory, ?int $comment = null): void
    {
        if (!Database::connection()->inTransaction()) throw new \LogicException('Activity capture requires a transaction.');
        $row = Database::queryOne("SELECT m.group_id,m.author_id,c.author_id AS commenter,c.parent_id
            FROM memories m LEFT JOIN comments c ON c.id=:c AND c.memory_id=m.id AND c.status='active'
            WHERE m.id=:m AND m.status='active'", ['m'=>$memory,'c'=>$comment]);
        if ($row === null || ($comment !== null && $row['commenter'] === null)) return;
        $actor = (int) ($comment === null ? $row['author_id'] : $row['commenter']);
        $kind = $comment === null ? 'memory.created' : ($row['parent_id'] === null ? 'comment.created' : 'comment.reply');
        $recipients = Database::query("SELECT gm.user_id FROM group_members gm JOIN users u ON u.id=gm.user_id AND u.status='active'
            WHERE gm.group_id=:g AND gm.status='active' AND gm.user_id<>:actor
            AND NOT EXISTS (SELECT 1 FROM user_blocks b WHERE
                (b.blocker_id=gm.user_id AND b.blocked_id=:blocked) OR (b.blocker_id=:blocker AND b.blocked_id=gm.user_id))
            AND (:all_members=1 OR gm.user_id=:author OR gm.user_id IN (SELECT author_id FROM comments WHERE id=:parent AND status='active'))",
            ['g'=>$row['group_id'],'actor'=>$actor,'blocked'=>$actor,'blocker'=>$actor,
             'all_members'=>$comment === null ? 1 : 0,'author'=>$row['author_id'],'parent'=>$row['parent_id']]);
        foreach ($recipients as $recipient) {
            \Circle\Controllers\ActivityController::record((int) $recipient['user_id'], $kind, $actor,
                (int) $row['group_id'], $memory, $comment);
        }
    }
}
