<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Core\Validator;
use Circle\Notifications\NotificationOutbox;
use Circle\Media\Uuid;
use Circle\Repositories\MediaRepository;
use Circle\Repositories\MemberRepository;

final class MemoryController
{
    /** Reactions are limited to a short, fixed set. */
    public const REACTIONS = ['❤️', '😂', '😮', '😢', '🙏', '👍', '🎉', '🔥'];

    private const DEFAULT_LIMIT = 20;
    private const MAX_LIMIT = 50;
    public const MAX_MEDIA_PER_MEMORY = 10;

    /**
     * Memories from groups where the caller is an active member (optionally one
     * exact group), newest first, keyset-paginated on (created_at, id).
     */
    public static function index(Request $request): void
    {
        $userId = $request->userId();
        $groupId = $request->query('group_id');
        $limit = $request->queryInt('limit', self::DEFAULT_LIMIT, 1, self::MAX_LIMIT);

        $saved = $request->query['saved'] ?? 'false';
        if (!is_string($saved) || !in_array($saved, ['true', 'false'], true)) {
            Response::validationError('saved must be true or false.');
        }
        $query = $request->query['q'] ?? '';
        if (!is_string($query) || strlen($query) > 800) {
            Response::validationError('q must be valid UTF-8 text with at most 200 characters.');
        }
        $query = trim($query);
        $queryLength = preg_match_all('/./us', $query);
        if ($queryLength === false || $queryLength > 200) {
            Response::validationError('q must be valid UTF-8 text with at most 200 characters.');
        }

        $params = ['viewer' => $userId, 'gm_status' => 'active', 'm_status' => 'active'];
        $where = 'WHERE m.status = :m_status AND gm.user_id = :viewer AND gm.status = :gm_status';

        if ($groupId !== '') {
            $gid = ctype_digit($groupId) ? (int) $groupId : 0;
            MemberRepository::requireActiveMember($gid, $userId);
            $where .= ' AND m.group_id = :gid';
            $params['gid'] = $gid;
        }

        if ($saved === 'true') {
            $where .= ' AND EXISTS(SELECT 1 FROM saves filtered_save WHERE filtered_save.memory_id = m.id AND filtered_save.user_id = :filter_saved_uid)';
            $params['filter_saved_uid'] = $userId;
        }
        if ($queryLength > 0) {
            // Literal substring matching: clients do not supply SQL LIKE wildcards.
            $pattern = '%' . strtr($query, ['!' => '!!', '%' => '!%', '_' => '!_']) . '%';
            $where .= " AND (m.body LIKE :query_body ESCAPE '!' OR m.place LIKE :query_place ESCAPE '!')";
            // Native PDO prepares require a unique placeholder for each occurrence.
            $params['query_body'] = $pattern;
            $params['query_place'] = $pattern;
        }

        $cursor = $request->query('cursor');
        if ($cursor !== '') {
            [$cAt, $cId] = self::decodeCursor($cursor);
            $where .= ' AND (m.created_at < :c_at OR (m.created_at = :c_at_eq AND m.id < :c_id))';
            $params['c_at'] = $cAt;
            $params['c_at_eq'] = $cAt;
            $params['c_id'] = $cId;
        }

        $params['reacted_uid'] = $userId;
        $params['saved_uid'] = $userId;
        $params['c_status'] = 'active';
        $params['lim'] = $limit + 1;

        $memories = Database::query(
            "SELECT m.id, m.group_id, m.author_id, m.body, m.memory_date, m.place,
                    m.created_at, m.updated_at,
                    u.display_name AS author_name, u.avatar_path AS author_avatar,
                    g.name AS group_name, g.`type` AS group_type,
                    (SELECT COUNT(*) FROM reactions r WHERE r.memory_id = m.id) AS reaction_count,
                    (SELECT COUNT(*) FROM comments c WHERE c.memory_id = m.id AND c.status = :c_status) AS comment_count,
                    EXISTS(SELECT 1 FROM reactions r2 WHERE r2.memory_id = m.id AND r2.user_id = :reacted_uid) AS user_reacted,
                    EXISTS(SELECT 1 FROM saves sv WHERE sv.memory_id = m.id AND sv.user_id = :saved_uid) AS user_saved
             FROM memories m
             JOIN group_members gm ON m.group_id = gm.group_id
             JOIN users u ON m.author_id = u.id
             JOIN `groups` g ON m.group_id = g.id
             {$where}
             ORDER BY m.created_at DESC, m.id DESC
             LIMIT :lim",
            $params
        );

        $hasMore = count($memories) > $limit;
        if ($hasMore) {
            array_pop($memories);
        }

        $memories = array_map(self::normaliseListItem(...), $memories);
        $media = MediaRepository::mediaForMemories(array_map(static fn (array $m): int => (int) $m['id'], $memories));
        foreach ($memories as $i => $m) {
            $memories[$i]['media'] = $media[(int) $m['id']] ?? [];
        }
        $last = $memories !== [] ? $memories[count($memories) - 1] : null;

        Response::paginated($memories, [
            'next_cursor' => $hasMore && $last !== null ? self::encodeCursor((string) $last['created_at'], (int) $last['id']) : null,
            'has_more' => $hasMore,
            'limit' => $limit,
        ]);
    }

    public static function show(Request $request): void
    {
        $userId = $request->userId();
        $memoryId = (int) $request->param('id');

        $memory = self::findMemoryForMember($memoryId, $userId);

        $memory['comments'] = array_map(static fn (array $c): array => [
            ...$c,
            'id' => (int) $c['id'],
            'parent_id' => $c['parent_id'] !== null ? (int) $c['parent_id'] : null,
            'author_id' => (int) $c['author_id'],
        ], Database::query(
            'SELECT c.id, c.parent_id, c.author_id, c.body, c.created_at,
                    u.display_name AS author_name, u.avatar_path AS author_avatar
             FROM comments c
             JOIN users u ON c.author_id = u.id
             WHERE c.memory_id = :mid AND c.status = :s
             ORDER BY c.created_at, c.id',
            ['mid' => $memoryId, 's' => 'active']
        ));

        $memory['reactions'] = array_map(static fn (array $r): array => [
            ...$r,
            'user_id' => (int) $r['user_id'],
        ], Database::query(
            'SELECT r.user_id, r.emoji, u.display_name
             FROM reactions r
             JOIN users u ON r.user_id = u.id
             WHERE r.memory_id = :mid',
            ['mid' => $memoryId]
        ));

        Response::ok($memory);
    }

    /**
     * POST /groups/{id}/memories — the group always comes from the route.
     * `media_ids` (≤ 10, unique) must be ready, unattached assets the caller
     * uploaded to this same group; they are attached in the same transaction.
     * `body` is optional when at least one photo is attached.
     */
    public static function create(Request $request): void
    {
        $userId = $request->userId();
        $groupId = (int) $request->param('id');

        MemberRepository::requireActiveMember($groupId, $userId);

        $body = $request->string('body');
        $memoryDate = $request->string('memory_date');
        $place = $request->string('place');
        $mediaIds = self::mediaIdsInput($request);

        $v = new Validator();
        if ($mediaIds === []) {
            $v->required('body', $body);
        }
        $v->string('body', $body, $mediaIds === [] ? 1 : 0, 2000);
        if ($memoryDate !== '') {
            $v->date('memory_date', $memoryDate);
        }
        $v->string('place', $place, 0, 255);
        $v->bail();

        $memoryId = Database::transaction(static function () use ($groupId, $userId, $body, $memoryDate, $place, $mediaIds): int {
            if ($mediaIds !== []) {
                $assets = MediaRepository::lockMany($mediaIds);
                $rejected = [];
                foreach ($mediaIds as $id) {
                    $a = $assets[$id] ?? null;
                    if ($a === null || $a['uploader_id'] !== $userId || $a['group_id'] !== $groupId
                        || $a['status'] !== 'ready' || $a['attached_at'] !== null || $a['deleted_at'] !== null
                    ) {
                        $rejected[] = $id;
                    }
                }
                if ($rejected !== []) {
                    // Same answer for missing, foreign, unready and used assets.
                    Response::error(
                        'validation_error',
                        'Some photos can\'t be attached. Upload them again to this group.',
                        422,
                        ['media_ids' => $rejected]
                    );
                }
            }

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
            $memoryId = Database::lastInsertId();
            MediaRepository::attachToMemory($memoryId, $mediaIds);
            NotificationOutbox::memoryCreated($memoryId);
            return $memoryId;
        });

        Response::created(self::findMemory($memoryId), 'Memory shared.');
    }

    /**
     * Validated `media_ids`: a list of at most 10 distinct UUIDs (lower-cased).
     * @return string[]
     */
    private static function mediaIdsInput(Request $request): array
    {
        if (!$request->has('media_ids') || $request->input('media_ids') === null) {
            return [];
        }
        $raw = $request->input('media_ids');
        if (!is_array($raw) || !array_is_list($raw)) {
            Response::validationError('media_ids must be a list of photo ids.');
        }
        if (count($raw) > self::MAX_MEDIA_PER_MEMORY) {
            Response::validationError('A Memory can have at most ' . self::MAX_MEDIA_PER_MEMORY . ' photos.');
        }
        $ids = [];
        foreach ($raw as $value) {
            $id = Uuid::normalise($value);
            if ($id === null) {
                Response::validationError('media_ids must be a list of photo ids.');
            }
            if (in_array($id, $ids, true)) {
                Response::validationError('Each photo can be attached only once.');
            }
            $ids[] = $id;
        }
        return $ids;
    }

    public static function update(Request $request): void
    {
        $userId = $request->userId();
        $memoryId = (int) $request->param('id');

        $memory = self::findMemoryForMember($memoryId, $userId);

        if ((int) $memory['author_id'] !== $userId) {
            Response::forbidden('You can only edit your own Memories.');
        }

        $sets = [];
        $params = ['id' => $memoryId];
        $v = new Validator();

        if ($request->has('body')) {
            $body = $request->string('body');
            $v->required('body', $body)->string('body', $body, 1, 2000);
            $sets[] = 'body = :body';
            $params['body'] = $body;
        }

        if ($request->has('memory_date')) {
            $memoryDate = $request->string('memory_date');
            if ($memoryDate !== '') {
                $v->date('memory_date', $memoryDate);
            }
            $sets[] = 'memory_date = :md';
            $params['md'] = $memoryDate !== '' ? $memoryDate : null;
        }

        if ($request->has('place')) {
            $place = $request->string('place');
            $v->string('place', $place, 0, 255);
            $sets[] = 'place = :place';
            $params['place'] = $place !== '' ? $place : null;
        }

        $v->bail();
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
        $userId = $request->userId();
        $memoryId = (int) $request->param('id');

        $memory = self::findMemoryForMember($memoryId, $userId);
        $groupId = (int) $memory['group_id'];

        // Author (still a member) can delete, or an admin of that exact group.
        if ((int) $memory['author_id'] !== $userId && !MemberRepository::isAdmin($groupId, $userId)) {
            Response::forbidden('Only the author or an admin can remove this Memory.');
        }

        // Its photos become `deleted` at once (never served again); their files
        // are purged by `composer media:cleanup` after MEDIA_PURGE_AFTER_DAYS.
        Database::transaction(static function () use ($memoryId): void {
            Database::execute(
                'UPDATE memories SET status = :s WHERE id = :id',
                ['s' => 'removed', 'id' => $memoryId]
            );
            MediaRepository::softDeleteForMemory($memoryId);
        });

        Response::ok(null, 'Memory removed.');
    }

    // --- Comments ---

    public static function addComment(Request $request): void
    {
        $userId = $request->userId();
        $memoryId = (int) $request->param('id');

        self::findMemoryForMember($memoryId, $userId);

        $body = $request->string('body');
        $parentId = $request->input('parent_id');

        $v = new Validator();
        $v->required('body', $body)->string('body', $body, 1, 2000);
        $v->bail();

        $pid = null;
        if ($parentId !== null && $parentId !== '') {
            $pid = is_int($parentId) || (is_string($parentId) && ctype_digit($parentId)) ? (int) $parentId : 0;
            $parent = Database::queryOne(
                'SELECT id FROM comments WHERE id = :id AND memory_id = :mid AND status = :s',
                ['id' => $pid, 'mid' => $memoryId, 's' => 'active']
            );
            if ($parent === null) {
                Response::validationError('parent_id must be a comment on the same Memory.');
            }
        }

        $commentId = Database::transaction(static function () use ($memoryId, $pid, $userId, $body): int {
            Database::execute(
                'INSERT INTO comments (memory_id, parent_id, author_id, body)
                 VALUES (:mid, :pid, :uid, :body)',
                ['mid' => $memoryId, 'pid' => $pid, 'uid' => $userId, 'body' => $body]
            );

            $id = Database::lastInsertId();
            NotificationOutbox::commentCreated($memoryId, $id);
            return $id;
        });

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

    /**
     * Toggle: same emoji again removes the reaction; a different emoji replaces
     * it. Concurrent requests cannot create duplicates (unique key + upsert).
     */
    public static function react(Request $request): void
    {
        $userId = $request->userId();
        $memoryId = (int) $request->param('id');
        $emoji = $request->string('emoji', self::REACTIONS[0]);

        (new Validator())->enum('emoji', $emoji, self::REACTIONS)->bail();

        self::findMemoryForMember($memoryId, $userId);

        $removed = Database::execute(
            'DELETE FROM reactions WHERE memory_id = :mid AND user_id = :uid AND emoji = :emoji',
            ['mid' => $memoryId, 'uid' => $userId, 'emoji' => $emoji]
        );
        if ($removed > 0) {
            Response::ok(['reacted' => false, 'emoji' => null], 'Reaction removed.');
        }

        Database::execute(
            'INSERT INTO reactions (memory_id, user_id, emoji) VALUES (:mid, :uid, :emoji)
             ON DUPLICATE KEY UPDATE emoji = VALUES(emoji)',
            ['mid' => $memoryId, 'uid' => $userId, 'emoji' => $emoji]
        );

        Response::ok(['reacted' => true, 'emoji' => $emoji], 'Reaction added.');
    }

    // --- Save/Bookmark ---

    public static function save(Request $request): void
    {
        $userId = $request->userId();
        $memoryId = (int) $request->param('id');

        self::findMemoryForMember($memoryId, $userId);

        $removed = Database::execute(
            'DELETE FROM saves WHERE memory_id = :mid AND user_id = :uid',
            ['mid' => $memoryId, 'uid' => $userId]
        );
        if ($removed > 0) {
            Response::ok(['saved' => false], 'Unsaved.');
        }

        Database::execute(
            'INSERT IGNORE INTO saves (memory_id, user_id) VALUES (:mid, :uid)',
            ['mid' => $memoryId, 'uid' => $userId]
        );

        Response::ok(['saved' => true], 'Saved.');
    }

    // --- Helpers ---

    private static function encodeCursor(string $createdAt, int $id): string
    {
        return rtrim(strtr(base64_encode($createdAt . '|' . $id), '+/', '-_'), '=');
    }

    /** @return array{0: string, 1: int} */
    private static function decodeCursor(string $cursor): array
    {
        $raw = base64_decode(strtr($cursor, '-_', '+/'), true);
        if ($raw === false
            || preg_match('/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\|(\d{1,19})$/', $raw, $m) !== 1
        ) {
            Response::validationError('Invalid cursor.', 'invalid_cursor');
        }
        return [$m[1], (int) $m[2]];
    }

    /**
     * @param array<string, mixed> $m
     * @return array<string, mixed>
     */
    private static function normaliseListItem(array $m): array
    {
        return [
            ...$m,
            'id' => (int) $m['id'],
            'group_id' => (int) $m['group_id'],
            'author_id' => (int) $m['author_id'],
            'reaction_count' => (int) $m['reaction_count'],
            'comment_count' => (int) $m['comment_count'],
            'user_reacted' => (bool) $m['user_reacted'],
            'user_saved' => (bool) $m['user_saved'],
        ];
    }

    /**
     * Same 404 for "missing" and "not a member of its exact group", so memory
     * ids from other groups cannot be probed.
     * @return array<string, mixed>
     */
    private static function findMemoryForMember(int $memoryId, int $userId): array
    {
        $memory = self::findMemory($memoryId);
        if (!MemberRepository::isActiveMember((int) $memory['group_id'], $userId)) {
            Response::notFound('Memory not found.');
        }
        return $memory;
    }

    /** @return array<string, mixed> */
    private static function findMemory(int $id): array
    {
        $memory = Database::queryOne(
            'SELECT m.id, m.group_id, m.author_id, m.body, m.memory_date, m.place, m.created_at, m.updated_at,
                    u.display_name AS author_name, u.avatar_path AS author_avatar,
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

        $memory['id'] = (int) $memory['id'];
        $memory['group_id'] = (int) $memory['group_id'];
        $memory['author_id'] = (int) $memory['author_id'];
        $memory['media'] = MediaRepository::mediaForMemories([$memory['id']])[$memory['id']] ?? [];

        return $memory;
    }
}
