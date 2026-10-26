<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../../vendor/autoload.php';

use Circle\Core\Env;
use Circle\Core\FcmSender;
use Circle\Notifications\NotificationWorker;

date_default_timezone_set('UTC');
Env::load(__DIR__ . '/../..');
$options = getopt('', ['limit:']);
$limit = isset($options['limit']) && is_string($options['limit']) && ctype_digit($options['limit']) ? (int) $options['limit'] : 50;
try {
    $counts = (new NotificationWorker(new FcmSender()))->run($limit);
    echo json_encode($counts, JSON_THROW_ON_ERROR) . "\n";
    exit($counts['unconfigured'] === 1 ? 2 : 0);
} catch (\Throwable) {
    // No provider payloads, token ids, filesystem paths or exception text.
    error_log('[CIRCLE] notifications_worker failed');
    echo "FAILED: notification worker; inspect private operational monitoring.\n";
    exit(1);
}
