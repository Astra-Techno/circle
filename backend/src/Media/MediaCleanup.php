<?php

declare(strict_types=1);

namespace Circle\Media;

use Circle\Core\Database;

/**
 * Housekeeping for media (run `composer media:cleanup`, e.g. hourly from cron):
 * 1. unattached uploads (pending/ready/failed) older than 24 h are deleted and
 *    their files removed at once (they were never shared);
 * 2. files of deleted assets are purged once MEDIA_PURGE_AFTER_DAYS have passed
 *    since deletion (the Undo/retention window).
 * Idempotent: purged rows are marked and skipped on the next run.
 */
final class MediaCleanup
{
    public const ORPHAN_HOURS = 24;
    public const DEFAULT_PURGE_AFTER_DAYS = 7;
    private const BATCH = 200;

    /** @return array{orphans_deleted: int, files_purged: int} */
    public static function run(MediaStorage $storage, int $purgeAfterDays = self::DEFAULT_PURGE_AFTER_DAYS): array
    {
        $purgeAfterDays = max(0, $purgeAfterDays);
        // Staged photos and replaced/removed event covers are private orphans.
        // Lock and recheck before deleting so a concurrent send cannot lose a photo.
        $featureRows = Database::query("SELECT f.id FROM feature_media f LEFT JOIN events e ON e.cover_id=f.id WHERE f.message_id IS NULL AND e.id IS NULL AND f.created_at<DATE_SUB(UTC_TIMESTAMP(),INTERVAL 24 HOUR) LIMIT 200");
        foreach ($featureRows as $row) {
            $prefix = Database::transaction(static function () use ($row): ?string {
                $f = Database::queryOne('SELECT * FROM feature_media WHERE id=:id FOR UPDATE', ['id'=>$row['id']]);
                if ($f === null || $f['message_id'] !== null || Database::queryOne('SELECT id FROM events WHERE cover_id=:id', ['id'=>$row['id']]) !== null) return null;
                Database::execute('DELETE FROM feature_media WHERE id=:id', ['id'=>$row['id']]);
                return $f['storage_prefix'];
            });
            if ($prefix !== null) $storage->deletePrefix($prefix);
        }
        $orphans = 0;
        $purged = 0;

        do {
            $rows = Database::query(
                'SELECT id, storage_key FROM media_assets
                 WHERE attached_at IS NULL AND status IN (:s_pending, :s_ready, :s_failed)
                   AND created_at < DATE_SUB(NOW(), INTERVAL :hours HOUR)
                 ORDER BY created_at
                 LIMIT :lim',
                ['s_pending' => 'pending', 's_ready' => 'ready', 's_failed' => 'failed', 'hours' => self::ORPHAN_HOURS, 'lim' => self::BATCH]
            );
            foreach ($rows as $row) {
                // Mark first (guarded against a concurrent attach), then remove files.
                $marked = Database::execute(
                    'UPDATE media_assets
                     SET status = :deleted, deleted_at = COALESCE(deleted_at, NOW()), purged_at = NOW()
                     WHERE id = :id AND attached_at IS NULL',
                    ['deleted' => 'deleted', 'id' => $row['id']]
                );
                if ($marked > 0) {
                    self::removeFiles($storage, $row['storage_key']);
                    $orphans++;
                }
            }
        } while (count($rows) === self::BATCH && $orphans > 0);

        do {
            $rows = Database::query(
                'SELECT id, storage_key FROM media_assets
                 WHERE status = :deleted AND purged_at IS NULL
                   AND deleted_at < DATE_SUB(NOW(), INTERVAL :days DAY)
                 ORDER BY deleted_at
                 LIMIT :lim',
                ['deleted' => 'deleted', 'days' => $purgeAfterDays, 'lim' => self::BATCH]
            );
            foreach ($rows as $row) {
                self::removeFiles($storage, $row['storage_key']);
                Database::execute(
                    'UPDATE media_assets SET purged_at = NOW() WHERE id = :id',
                    ['id' => $row['id']]
                );
                $purged++;
            }
        } while (count($rows) === self::BATCH);

        return ['orphans_deleted' => $orphans, 'files_purged' => $purged];
    }

    private static function removeFiles(MediaStorage $storage, mixed $key): void
    {
        if (is_string($key) && $key !== '') {
            $storage->deletePrefix($key);
        }
    }
}
