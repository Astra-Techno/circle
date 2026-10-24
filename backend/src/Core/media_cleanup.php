<?php

declare(strict_types=1);

/**
 * Media cleanup (ADR 0007). Execute from backend/, e.g. hourly from cron:
 *   composer media:cleanup        (or: php src/Core/media_cleanup.php)
 * Prints counts only; no ids, keys or paths.
 */

require_once __DIR__ . '/../../vendor/autoload.php';

use Circle\Core\Env;
use Circle\Core\Log;
use Circle\Media\MediaCleanup;
use Circle\Media\MediaServices;

date_default_timezone_set('UTC');
Env::load(__DIR__ . '/../..');

try {
    $counts = MediaCleanup::run(
        MediaServices::storage(),
        Env::int('MEDIA_PURGE_AFTER_DAYS', MediaCleanup::DEFAULT_PURGE_AFTER_DAYS)
    );
} catch (\Throwable $e) {
    Log::exception('media_cleanup', $e);
    echo "FAILED: see the error log.\n";
    exit(1);
}

$line = sprintf('[CIRCLE] media_cleanup: orphans_deleted=%d files_purged=%d', $counts['orphans_deleted'], $counts['files_purged']);
echo $line . "\n";
