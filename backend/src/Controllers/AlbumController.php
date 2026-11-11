<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Core\Validator;
use Circle\Repositories\MemberRepository;

final class AlbumController
{
    /** List albums in a group. */
    public static function index(Request $r): void
    {
        $groupId = (int) $r->param('id');
        $userId = $r->userId();
        MemberRepository::requireActiveMember($groupId, $userId);

        $limit = $r->queryInt('limit', 30, 1, 100);
        $offset = $r->queryInt('offset', 0, 0, 1000000);

        $rows = Database::query(
            'SELECT a.*, u.display_name AS creator_name,
                (SELECT COUNT(*) FROM album_photos WHERE album_id = a.id) AS photo_count
             FROM albums a
             JOIN users u ON u.id = a.created_by
             WHERE a.group_id = :g
             ORDER BY a.created_at DESC
             LIMIT :lim OFFSET :off',
            ['g' => $groupId, 'lim' => $limit + 1, 'off' => $offset]
        );
        $more = count($rows) > $limit;
        if ($more) array_pop($rows);

        $items = array_map(fn(array $row) => self::format($row), $rows);
        Response::ok(['items' => $items, 'has_more' => $more]);
    }

    /** Get album detail with photos. */
    public static function show(Request $r): void
    {
        $album = self::access($r);

        $limit = $r->queryInt('limit', 50, 1, 200);
        $offset = $r->queryInt('offset', 0, 0, 1000000);

        $photos = Database::query(
            'SELECT ap.id, ap.media_id, ap.added_by, u.display_name AS added_by_name,
                    ap.caption, ap.sort_order, ap.added_at
             FROM album_photos ap
             JOIN users u ON u.id = ap.added_by
             WHERE ap.album_id = :id
             ORDER BY ap.sort_order, ap.id
             LIMIT :lim OFFSET :off',
            ['id' => $album['id'], 'lim' => $limit + 1, 'off' => $offset]
        );
        $more = count($photos) > $limit;
        if ($more) array_pop($photos);

        $detail = self::format($album);
        $detail['photos'] = ['items' => $photos, 'has_more' => $more];

        Response::ok($detail);
    }

    /** Create an album in a group. */
    public static function create(Request $r): void
    {
        $groupId = (int) $r->param('id');
        $userId = $r->userId();
        MemberRepository::requireActiveMember($groupId, $userId);

        $title = trim($r->string('title'));
        $description = trim($r->string('description', ''));
        $eventId = $r->input('event_id');

        $v = new Validator();
        $v->required('title', $title)->string('title', $title, 1, 200);
        if ($description !== '') $v->string('description', $description, 0, 1000);
        $v->bail();

        $eid = null;
        if ($eventId !== null && $eventId !== '') {
            $eid = (int) $eventId;
            $event = Database::queryOne('SELECT id FROM events WHERE id = :id AND group_id = :g', ['id' => $eid, 'g' => $groupId]);
            if ($event === null) Response::validationError('Event not found in this group.');
            // Check uniqueness
            $existing = Database::queryOne('SELECT id FROM albums WHERE event_id = :eid', ['eid' => $eid]);
            if ($existing !== null) Response::error('album_exists', 'An album already exists for this event.', 409);
        }

        $id = Database::transaction(static function () use ($groupId, $userId, $title, $description, $eid): int {
            Database::execute(
                'INSERT INTO albums (group_id, created_by, title, description, event_id)
                 VALUES (:g, :u, :t, :d, :e)',
                ['g' => $groupId, 'u' => $userId, 't' => $title, 'd' => $description, 'e' => $eid]
            );
            return Database::lastInsertId();
        });

        Response::created(['id' => $id, 'group_id' => $groupId], 'Album created.');
    }

    /** Update album title/description. */
    public static function update(Request $r): void
    {
        $album = self::access($r);
        $userId = $r->userId();

        // Creator or admin can edit
        self::requireEditor($album, $userId);

        $fields = [];
        $params = ['id' => $album['id']];

        $title = $r->input('title');
        if ($title !== null) {
            $title = trim((string) $title);
            (new Validator())->required('title', $title)->string('title', $title, 1, 200)->bail();
            $fields[] = 'title = :t';
            $params['t'] = $title;
        }
        $desc = $r->input('description');
        if ($desc !== null) {
            $desc = trim((string) $desc);
            (new Validator())->string('description', $desc, 0, 1000)->bail();
            $fields[] = 'description = :d';
            $params['d'] = $desc;
        }
        $coverId = $r->input('cover_media_id');
        if ($coverId !== null) {
            $fields[] = 'cover_media_id = :cover';
            $params['cover'] = $coverId === '' ? null : (string) $coverId;
        }

        if (empty($fields)) Response::validationError('No fields to update.');

        Database::execute('UPDATE albums SET ' . implode(', ', $fields) . ' WHERE id = :id', $params);
        Response::ok(null, 'Album updated.');
    }

    /** Delete album (creator or admin). */
    public static function delete(Request $r): void
    {
        $album = self::access($r);
        self::requireEditor($album, $r->userId());
        Database::execute('DELETE FROM albums WHERE id = :id', ['id' => $album['id']]);
        Response::ok(null, 'Album deleted.');
    }

    /** Add a photo to an album. */
    public static function addPhoto(Request $r): void
    {
        $album = self::access($r);
        $userId = $r->userId();

        $mediaId = $r->string('media_id');
        $caption = trim($r->string('caption', ''));

        $v = new Validator();
        $v->required('media_id', $mediaId);
        if ($caption !== '') $v->string('caption', $caption, 0, 200);
        $v->bail();

        // Get next sort_order
        $maxSort = Database::queryOne(
            'SELECT COALESCE(MAX(sort_order), 0) AS m FROM album_photos WHERE album_id = :id',
            ['id' => $album['id']]
        )['m'];

        Database::execute(
            'INSERT INTO album_photos (album_id, media_id, added_by, caption, sort_order)
             VALUES (:a, :m, :u, :c, :s)',
            ['a' => $album['id'], 'm' => $mediaId, 'u' => $userId, 'c' => $caption, 's' => (int) $maxSort + 1]
        );

        $id = Database::lastInsertId();
        Response::created(['id' => $id], 'Photo added.');
    }

    /** Update photo caption. */
    public static function updatePhoto(Request $r): void
    {
        $album = self::access($r);
        $photoId = (int) $r->param('photoId');

        $photo = Database::queryOne(
            'SELECT * FROM album_photos WHERE id = :id AND album_id = :a',
            ['id' => $photoId, 'a' => $album['id']]
        );
        if ($photo === null) Response::notFound('Photo not found.');

        $userId = $r->userId();
        if ((int) $photo['added_by'] !== $userId) {
            self::requireEditor($album, $userId);
        }

        $caption = trim($r->string('caption', ''));
        (new Validator())->string('caption', $caption, 0, 200)->bail();

        Database::execute('UPDATE album_photos SET caption = :c WHERE id = :id', ['c' => $caption, 'id' => $photoId]);
        Response::ok(null, 'Caption updated.');
    }

    /** Remove a photo from an album. */
    public static function removePhoto(Request $r): void
    {
        $album = self::access($r);
        $photoId = (int) $r->param('photoId');

        $photo = Database::queryOne(
            'SELECT * FROM album_photos WHERE id = :id AND album_id = :a',
            ['id' => $photoId, 'a' => $album['id']]
        );
        if ($photo === null) Response::notFound('Photo not found.');

        $userId = $r->userId();
        if ((int) $photo['added_by'] !== $userId) {
            self::requireEditor($album, $userId);
        }

        Database::execute('DELETE FROM album_photos WHERE id = :id', ['id' => $photoId]);
        Response::ok(null, 'Photo removed.');
    }

    // ── Helpers ─────────────────────────────────────────────────

    /** @return array<string, mixed> */
    private static function access(Request $r): array
    {
        $albumId = (int) $r->param('albumId');
        $album = Database::queryOne(
            'SELECT a.*, u.display_name AS creator_name,
                (SELECT COUNT(*) FROM album_photos WHERE album_id = a.id) AS photo_count
             FROM albums a JOIN users u ON u.id = a.created_by WHERE a.id = :id',
            ['id' => $albumId]
        );
        if ($album === null) Response::notFound('Album not found.');
        MemberRepository::requireActiveMember((int) $album['group_id'], $r->userId());
        return $album;
    }

    /** @param array<string, mixed> $album */
    private static function requireEditor(array $album, int $userId): void
    {
        if ((int) $album['created_by'] === $userId) return;
        $member = Database::queryOne(
            "SELECT role FROM group_members WHERE group_id = :g AND user_id = :u AND status = 'active'",
            ['g' => $album['group_id'], 'u' => $userId]
        );
        if ($member === null || $member['role'] !== 'admin') {
            Response::error('forbidden', 'Only the album creator or a group admin can do this.', 403);
        }
    }

    /**
     * @param array<string, mixed> $row
     * @return array<string, mixed>
     */
    private static function format(array $row): array
    {
        return [
            'id'             => (int) $row['id'],
            'group_id'       => (int) $row['group_id'],
            'created_by'     => (int) $row['created_by'],
            'creator_name'   => $row['creator_name'] ?? null,
            'event_id'       => $row['event_id'] !== null ? (int) $row['event_id'] : null,
            'title'          => $row['title'],
            'description'    => $row['description'],
            'cover_media_id' => $row['cover_media_id'],
            'photo_count'    => (int) ($row['photo_count'] ?? 0),
            'created_at'     => $row['created_at'],
            'updated_at'     => $row['updated_at'],
        ];
    }
}
