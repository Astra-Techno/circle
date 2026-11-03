<?php

declare(strict_types=1);
namespace Circle\Notifications;
use Circle\Core\Database;
use Circle\Core\FcmSender;

/** Called only after the worker rechecks recipient/content authorization. */
final class NotificationPreview
{
    public static function shorten(string $text, int $limit): string
    {
        $text = trim(preg_replace('/[\p{C}\s]+/u', ' ', $text) ?? '');
        return mb_strlen($text) > $limit ? mb_substr($text, 0, $limit - 1) . '…' : $text;
    }

    /**
     * @param array<string,mixed> $row
     * @return array{title:string,body:string}
     */
    public static function forRow(array $row): array
    {
        $kind = (string) $row['kind'];
        $group = Database::queryOne('SELECT name FROM `groups` WHERE id=:id', ['id'=>$row['group_id']]);
        $title = self::shorten((string)($group['name'] ?? 'CIRCLE'), 80);
        $body = FcmSender::notificationBody($kind);
        $content = null;
        if ($kind === 'memory.created') {
            $content = Database::queryOne('SELECT u.display_name AS actor,m.body AS text FROM memories m JOIN users u ON u.id=m.author_id WHERE m.id=:id', ['id'=>$row['memory_id']]);
        } elseif (in_array($kind, ['comment.created','comment.reply'], true)) {
            $content = Database::queryOne('SELECT u.display_name AS actor,c.body AS text FROM comments c JOIN users u ON u.id=c.author_id WHERE c.id=:id', ['id'=>$row['comment_id']]);
        } elseif ($kind === 'chat.message') {
            $content = Database::queryOne('SELECT u.display_name AS actor,v.body AS text FROM chat_messages m JOIN users u ON u.id=m.author_id JOIN chat_versions v ON v.id=(SELECT MAX(id) FROM chat_versions WHERE message_id=m.id) WHERE m.id=:id', ['id'=>$row['chat_message_id']]);
        } elseif (str_starts_with($kind, 'event.')) {
            $content = Database::queryOne('SELECT u.display_name AS actor,e.title AS text FROM events e JOIN users u ON u.id=e.created_by WHERE e.id=:id', ['id'=>$row['event_id']]);
        } elseif (str_starts_with($kind, 'poll.')) {
            $content = Database::queryOne('SELECT u.display_name AS actor,p.question AS text FROM polls p JOIN users u ON u.id=p.created_by WHERE p.id=:id', ['id'=>$row['poll_id']]);
        } elseif ($kind === 'group.invitation') {
            $content = Database::queryOne('SELECT u.display_name AS actor FROM group_invitations i JOIN users u ON u.id=i.inviter_id WHERE i.id=:id', ['id'=>$row['invitation_id']]);
        }
        if ($content !== null) {
            $actor = self::shorten((string)$content['actor'], 60);
            $text = self::shorten((string)($content['text'] ?? ''), 120);
            $action = match ($kind) {
                'memory.created' => 'shared a Memory',
                'comment.created' => 'commented on your Memory',
                'comment.reply' => 'replied to a comment',
                'chat.message' => 'sent a message',
                'group.invitation' => 'invited you to this circle',
                'poll.created' => 'created a poll',
                'poll.closed' => 'created a poll that has closed',
                'event.created' => 'created an event',
                'event.updated' => 'created an event that was updated',
                'event.cancelled' => 'created an event that was cancelled',
                default => '',
            };
            $body = $action !== '' ? "$actor $action" : $body;
            if ($text !== '') $body .= ': ' . $text;
        }
        return ['title'=>$title !== '' ? $title : 'CIRCLE', 'body'=>self::shorten($body, 220)];
    }
}
