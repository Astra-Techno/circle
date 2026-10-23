<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Core\Validator;
use Circle\Repositories\MemberRepository;

final class MemoryController
{
    public static function index(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $groupId = $request->query('group_id');
        $cursor = $request->query('cursor');
        $limit = min((int) $request->query('limit', '20'), 50);

        $params = ['uid' => $userId, 's' => 'active', 'ms' => 'active'];
        $where = 'WHERE m.status = :ms AND gm.user_id = :uid AND gm.status = :s';

        if ($groupId !== '') {
            $gid = (int) $groupId;
            MemberRepository::requireActiveMember($gid, $userId);
            $where .= ' AND m.group_id = :gid';
            $params['gid'] = $gid;
        }

        if ($cursor !== '') {
            $where .= ' AND m.created_at < :cursor';
            $params['cursor'] = $cursor;
        }

        $memories = Database::query(
            "SELECT m.id, m.group_id, m.author_id, m.body, m.memory_date, m.place,
                    m.created_at, m.updated_at,
                    u.display_name AS author_name, u.avatar_path AS author_avatar,
                    g.name AS group_name, g.`type` AS group_type,
                    (SELECT COUNT(*) FROM reactions r WHERE r.memory_id = m.id) AS reaction_count,
                    (SELECT COUNT(*) FROM comments c WHERE c.memory_id = m.id AND c.status = 'active') AS comment_count,
                    EXISTS(SELECT 1 FROM reactions r WHERE r.memory_id = m.id AND r.user_id = :uid) AS user_reacted,
                    EXISTS(SELECT 1 FROM saves sv WHERE sv.memory_id = m.id AND sv.user_id = :uid) AS user_saved
             FROM memories m
             JOIN group_members gm ON m.group_id = gm.group_id
             JOIN users u ON m.author_id = u.id
             JOIN `groups` g ON m.group_id = g.id
             {$where}
             GROUP BY m.id
             ORDER BY m.created_at DESC
             LIMIT " . ($limit + 1),
            $params
        );

        $hasMore = count($memories) > $limit;
        if ($hasMore) {
            array_pop($memories);
        }

        $nextCursor = $hasMore && $memories !== [] ? end($memories)['created_at'] : null;

        Response::paginated($memories, [
            'next_cursor' => $nextCursor,
            'has_more' => $hasMore,
        ]);
    }

    public static function show(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $memoryId = (int) $request->param('id');

        $memory = self::findMemory($memoryId);
        MemberRepository::requireActiveMember((int) $memory['group_id'], $userId);

        $memory['comments'] = Database::query(
            'SELECT c.id, c.parent_id, c.author_id, c.body, c.created_at,
                    u.display_name AS author_name, u.avatar_path AS author_avatar
             FROM comments c
             JOIN users u ON c.author_id = u.id
             WHERE c.memory_id = :mid AND c.status = :s
             ORDER BY c.created_at',
            ['mid' => $memoryId, 's' => 'active']
        );

        $memory['reactions'] = Database::query(
            'SELECT r.user_id, r.emoji, u.display_name
             FROM reactions r
             JOIN users u ON r.user_id = u.id
             WHERE r.memory_id = :mid',
            ['mid' => $memoryId]
        );

        Response::ok($memory);
    }

    public static function create(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $groupId = $request->int('group_id');
        $body = $request->string('body');
        $memoryDate = $request->string('memory_date');
        $place = $request->string('place');

        $v = new Validator();
        $v->required('group_id', $groupId);
        $v->required('body', $body)->string('body', $body, 1, 2000);
        $v->bail();

        MemberRepository::requireActiveMember($groupId, $userId);

        Database::execute(
            'INSERT INTO memories (group_id, author_id, body, memory_date, place)
             VALUES (:gid, :uid, :body, :date, :place)',
            [
                'gid' => $groupId,
                'uid' => $userId,
                'body' => $body,
                'date' => $memoryDate !== '' ? $memoryDate : null,
                'place' => $place !== '' ? $place : null,
            ]
        );

        $memoryId = (int) Database::lastInsertId();
        $memory = self::findMemory($memoryId);

        Response::created($memory, 'Memory shared.');
    }

    public static function update(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $memoryId = (int) $request->param('id');

        $memory = self::findMemory($memoryId);
        MemberRepository::requireActiveMember((int) $memory['group_id'], $userId);

        if ((int) $memory['author_id'] !== $userId) {
            Response::forbidden('You can only edit your own Memories.');
        }

        $body = $request->string('body');
        $sets = [];
        $params = ['id' => $memoryId];

        if ($body !== '') {
            (new Validator())->string('body', $body, 1, 2000)->bail();
            $sets[] = 'body = :body';
            $params['body'] = $body;
        }

        $memoryDate = $request->string('memory_date');
        if ($memoryDate !== '') {
            $sets[] = 'memory_date = :md';
            $params['md'] = $memoryDate;
        }

        $place = $request->string('place');
        if ($place !== '') {
            $sets[] = 'place = :place';
            $params['place'] = $place;
        }

        if ($sets === []) {
            Response::validationError('No fields to update.');
        }

        Database::execute(
            'UPDATE memories SET ' . implode(', ', $sets) . ' WHERE id = :id',
            $params
        );

        Response::ok(self::findMemory($memoryId), 'Memory updated.');
    }

    public static function delete(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $memoryId = (int) $request->param('id');

        $memory = self::findMemory($memoryId);
        $groupId = (int) $memory['group_id'];

        // Author can delete, or admin can remove
        $isAuthor = (int) $memory['author_id'] === $userId;
        $isAdmin = MemberRepository::isAdmin($groupId, $userId);

        if (!$isAuthor && !$isAdmin) {
            Response::forbidden('Only the author or an admin can remove this Memory.');
        }

        Database::execute(
            'UPDATE memories SET status = :s WHERE id = :id',
            ['s' => 'removed', 'id' => $memoryId]
        );

        Response::ok(null, 'Memory removed.');
    }

    // --- Comments ---

    public static function addComment(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $memoryId = (int) $request->param('id');
        $body = $request->string('body');
        $parentId = $request->input('parent_id');

        $v = new Validator();
        $v->required('body', $body)->string('body', $body, 1, 2000);
        $v->bail();

        $memory = self::findMemory($memoryId);
        MemberRepository::requireActiveMember((int) $memory['group_id'], $userId);

        Database::execute(
            'INSERT INTO comments (memory_id, parent_id, author_id, body)
             VALUES (:mid, :pid, :uid, :body)',
            [
                'mid' => $memoryId,
                'pid' => $parentId !== null && $parentId !== '' ? (int) $parentId : null,
                'uid' => $userId,
                'body' => $body,
            ]
        );

        $commentId = (int) Database::lastInsertId();

        $comment = Database::queryOne(
            'SELECT c.id, c.parent_id, c.author_id, c.body, c.created_at,
                    u.display_name AS author_name
             FROM comments c JOIN users u ON c.author_id = u.id
             WHERE c.id = :id',
            ['id' => $commentId]
        );

        Response::created($comment, 'Comment added.');
    }

    // --- Reactions ---

    public static function react(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $memoryId = (int) $request->param('id');
        $emoji = $request->string('emoji', '❤️');

        $memory = self::findMemory($memoryId);
        MemberRepository::requireActiveMember((int) $memory['group_id'], $userId);

        // Toggle: if already reacted, remove; otherwise add
        $existing = Database::queryOne(
            'SELECT id FROM reactions WHERE memory_id = :mid AND user_id = :uid',
            ['mid' => $memoryId, 'uid' => $userId]
        );

        if ($existing !== null) {
            Database::execute(
                'DELETE FROM reactions WHERE id = :id',
                ['id' => $existing['id']]
            );
            Response::ok(['reacted' => false], 'Reaction removed.');
        }

        Database::execute(
            'INSERT INTO reactions (memory_id, user_id, emoji) VALUES (:mid, :uid, :emoji)',
            ['mid' => $memoryId, 'uid' => $userId, 'emoji' => $emoji]
        );

        Response::ok(['reacted' => true], 'Reaction added.');
    }

    // --- Save/Bookmark ---

    public static function save(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $memoryId = (int) $request->param('id');

        $memory = self::findMemory($memoryId);
        MemberRepository::requireActiveMember((int) $memory['group_id'], $userId);

        $existing = Database::queryOne(
            'SELECT id FROM saves WHERE memory_id = :mid AND user_id = :uid',
            ['mid' => $memoryId, 'uid' => $userId]
        );

        if ($existing !== null) {
            Database::execute('DELETE FROM saves WHERE id = :id', ['id' => $existing['id']]);
            Response::ok(['saved' => false], 'Unsaved.');
        }

        Database::execute(
            'INSERT INTO saves (memory_id, user_id) VALUES (:mid, :uid)',
            ['mid' => $memoryId, 'uid' => $userId]
        );

        Response::ok(['saved' => true], 'Saved.');
    }

    // --- Helpers ---

    /** @return array<string, mixed> */
    private static function findMemory(int $id): array
    {
        $memory = Database::queryOne(
            'SELECT m.*, u.display_name AS author_name, u.avatar_path AS author_avatar,
                    g.name AS group_name, g.`type` AS group_type
             FROM memories m
             JOIN users u ON m.author_id = u.id
             JOIN `groups` g ON m.group_id = g.id
             WHERE m.id = :id AND m.status = :s',
            ['id' => $id, 's' => 'active']
        );

        if ($memory === null) {
            Response::notFound('Memory not found.');
        }

        return $memory;
    }
}
