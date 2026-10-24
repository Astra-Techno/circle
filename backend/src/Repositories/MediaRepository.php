<?php

declare(strict_types=1);

namespace Circle\Repositories;

use Circle\Core\Database;

/**
 * SQL for media_assets / memory_media_assets. Storage keys stay in this layer
 * and the controller; they are never part of an API response.
 */
final class MediaRepository
{
    public const SIZES = ['thumb', 'medium', 'full'];

    private const COLUMNS = 'id, group_id, uploader_id, client_upload_id, kind, status, declared_mime, declared_size,
        declared_sha256, mime_type, byte_size, width, height, storage_key, variants, created_at,
        ticket_expires_at, ready_at, attached_at, deleted_at, purged_at, hidden_at,
        (ticket_expires_at IS NOT NULL AND ticket_expires_at <= NOW()) AS ticket_expired';

    /** @return array<string, mixed>|null */
    public static function find(string $id): ?array
    {
        $row = Database::queryOne('SELECT ' . self::COLUMNS . ' FROM media_assets WHERE id = :id', ['id' => $id]);
        return $row !== null ? self::normalise($row) : null;
    }

    /** @return array<string, mixed>|null */
    public static function findForUpdate(string $id): ?array
    {
        $row = Database::queryOne('SELECT ' . self::COLUMNS . ' FROM media_assets WHERE id = :id FOR UPDATE', ['id' => $id]);
        return $row !== null ? self::normalise($row) : null;
    }

    /** @return array<string, mixed>|null */
    public static function findByClientUploadId(int $uploaderId, string $clientUploadId): ?array
    {
        $row = Database::queryOne(
            'SELECT ' . self::COLUMNS . ' FROM media_assets WHERE uploader_id = :uid AND client_upload_id = :cid',
            ['uid' => $uploaderId, 'cid' => $clientUploadId]
        );
        return $row !== null ? self::normalise($row) : null;
    }

    /** Unattached uploads of a person that still hold a slot (pending or ready). */
    public static function countOpenUploads(int $uploaderId): int
    {
        $row = Database::queryOne(
            'SELECT COUNT(*) AS cnt FROM media_assets
             WHERE uploader_id = :uid AND attached_at IS NULL AND status IN (:s_pending, :s_ready)',
            ['uid' => $uploaderId, 's_pending' => 'pending', 's_ready' => 'ready']
        );
        return (int) ($row['cnt'] ?? 0);
    }

    public static function createTicket(
        string $id,
        int $groupId,
        int $uploaderId,
        string $clientUploadId,
        string $mime,
        int $size,
        string $sha256,
        int $ttlSeconds
    ): void {
        Database::execute(
            'INSERT INTO media_assets
                (id, group_id, uploader_id, client_upload_id, status, declared_mime, declared_size, declared_sha256, ticket_expires_at)
             VALUES (:id, :gid, :uid, :cid, :status, :mime, :size, :sha, DATE_ADD(NOW(), INTERVAL :ttl SECOND))',
            [
                'id' => $id,
                'gid' => $groupId,
                'uid' => $uploaderId,
                'cid' => $clientUploadId,
                'status' => 'pending',
                'mime' => $mime,
                'size' => $size,
                'sha' => $sha256,
                'ttl' => $ttlSeconds,
            ]
        );
    }

    /**
     * Marks a pending asset ready. Returns false when another request already
     * finished (or the asset changed state) in the meantime.
     *
     * @param array<string, array{width: int, height: int, bytes: int, ext: string}> $variants
     */
    public static function markReady(
        string $id,
        string $storageKey,
        string $mime,
        int $width,
        int $height,
        int $byteSize,
        array $variants
    ): bool {
        return Database::execute(
            'UPDATE media_assets
             SET status = :ready, storage_key = :skey, mime_type = :mime, width = :w, height = :h,
                 byte_size = :bytes, variants = :variants, ready_at = NOW()
             WHERE id = :id AND status = :pending',
            [
                'ready' => 'ready',
                'skey' => $storageKey,
                'mime' => $mime,
                'w' => $width,
                'h' => $height,
                'bytes' => $byteSize,
                'variants' => json_encode($variants, JSON_THROW_ON_ERROR),
                'id' => $id,
                'pending' => 'pending',
            ]
        ) > 0;
    }

    public static function markFailed(string $id): void
    {
        Database::execute(
            'UPDATE media_assets SET status = :failed WHERE id = :id AND status = :pending',
            ['failed' => 'failed', 'id' => $id, 'pending' => 'pending']
        );
    }

    /** Marks deleted; $purged = files were removed right away. */
    public static function markDeleted(string $id, bool $purged): void
    {
        Database::execute(
            'UPDATE media_assets
             SET status = :deleted, deleted_at = COALESCE(deleted_at, NOW()),
                 purged_at = IF(:purged = 1, NOW(), purged_at)
             WHERE id = :id',
            ['deleted' => 'deleted', 'purged' => $purged ? 1 : 0, 'id' => $id]
        );
    }

    /**
     * Locks the given assets for attaching.
     * @param string[] $ids
     * @return array<string, array<string, mixed>> keyed by id
     */
    public static function lockMany(array $ids): array
    {
        if ($ids === []) {
            return [];
        }
        $params = [];
        $placeholders = [];
        foreach (array_values($ids) as $i => $id) {
            $placeholders[] = ':m' . $i;
            $params['m' . $i] = $id;
        }
        $rows = Database::query(
            'SELECT ' . self::COLUMNS . ' FROM media_assets WHERE id IN (' . implode(', ', $placeholders) . ') FOR UPDATE',
            $params
        );
        $out = [];
        foreach ($rows as $row) {
            $row = self::normalise($row);
            $out[(string) $row['id']] = $row;
        }
        return $out;
    }

    /** @param string[] $ids in display order */
    public static function attachToMemory(int $memoryId, array $ids): void
    {
        foreach (array_values($ids) as $i => $id) {
            Database::execute(
                'INSERT INTO memory_media_assets (memory_id, media_id, sort_order) VALUES (:mid, :media, :ord)',
                ['mid' => $memoryId, 'media' => $id, 'ord' => $i]
            );
            Database::execute(
                'UPDATE media_assets SET attached_at = NOW() WHERE id = :id AND attached_at IS NULL',
                ['id' => $id]
            );
        }
    }

    /** Soft-deletes every asset of a Memory; files are purged later by media:cleanup. */
    public static function softDeleteForMemory(int $memoryId): int
    {
        return Database::execute(
            'UPDATE media_assets ma
             JOIN memory_media_assets mma ON mma.media_id = ma.id
             SET ma.status = :deleted, ma.deleted_at = NOW()
             WHERE mma.memory_id = :mid AND ma.status <> :already',
            ['deleted' => 'deleted', 'mid' => $memoryId, 'already' => 'deleted']
        );
    }

    /**
     * Visible media (ids and dimensions only) for the given Memories.
     * @param int[] $memoryIds
     * @return array<int, array<int, array{id: string, width: int, height: int}>> keyed by memory id
     */
    public static function mediaForMemories(array $memoryIds): array
    {
        if ($memoryIds === []) {
            return [];
        }
        $params = ['ready' => 'ready'];
        $placeholders = [];
        foreach (array_values($memoryIds) as $i => $mid) {
            $placeholders[] = ':mem' . $i;
            $params['mem' . $i] = $mid;
        }
        $rows = Database::query(
            'SELECT mma.memory_id, ma.id, ma.width, ma.height
             FROM memory_media_assets mma
             JOIN media_assets ma ON ma.id = mma.media_id
             WHERE mma.memory_id IN (' . implode(', ', $placeholders) . ')
               AND ma.status = :ready AND ma.hidden_at IS NULL
             ORDER BY mma.memory_id, mma.sort_order',
            $params
        );
        $out = [];
        foreach ($rows as $row) {
            $out[(int) $row['memory_id']][] = [
                'id' => (string) $row['id'],
                'width' => (int) $row['width'],
                'height' => (int) $row['height'],
            ];
        }
        return $out;
    }

    /**
     * @param array<string, mixed> $row
     * @return array<string, mixed>
     */
    private static function normalise(array $row): array
    {
        foreach (['group_id', 'uploader_id', 'declared_size'] as $k) {
            $row[$k] = (int) $row[$k];
        }
        foreach (['byte_size', 'width', 'height'] as $k) {
            $row[$k] = $row[$k] !== null ? (int) $row[$k] : null;
        }
        $row['ticket_expired'] = (bool) $row['ticket_expired'];
        $variants = is_string($row['variants']) ? json_decode($row['variants'], true) : null;
        $row['variants'] = is_array($variants) ? $variants : [];
        return $row;
    }

    /**
     * Public representation (never the storage key or a URL).
     * @param array<string, mixed> $asset
     * @return array<string, mixed>
     */
    public static function present(array $asset): array
    {
        /** @var array<string, mixed> $variants */
        $variants = $asset['variants'];
        return [
            'id' => $asset['id'],
            'group_id' => $asset['group_id'],
            'uploader_id' => $asset['uploader_id'],
            'kind' => $asset['kind'],
            'mime_type' => $asset['mime_type'] ?? $asset['declared_mime'],
            'width' => $asset['width'],
            'height' => $asset['height'],
            'byte_size' => $asset['byte_size'] ?? $asset['declared_size'],
            'status' => $asset['status'],
            'sizes' => array_values(array_intersect(self::SIZES, array_keys($variants))),
            'created_at' => $asset['created_at'],
        ];
    }
}
