<?php

declare(strict_types=1);

// Works both under backend/public and at a flattened hosting document root.
$root = is_file(__DIR__ . '/src/Core/Env.php') ? __DIR__ : dirname(__DIR__);
require_once $root . '/src/Core/Env.php';
require_once $root . '/src/Core/Log.php';
require_once $root . '/src/Core/Diagnostics.php';
\Circle\Core\Diagnostics::enable();
\Circle\Core\Env::load($root);

header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: no-referrer');
header("Content-Security-Policy: default-src 'none'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'");

$expected = \Circle\Core\Env::get('DIAGNOSTICS_TOKEN');
$deploymentKey = \Circle\Core\Env::get('DEPLOY_KEY');
$headerKey = $_SERVER['HTTP_X_DEPLOY_KEY'] ?? '';
if ($headerKey === '') $headerKey = $_POST['token'] ?? '';
$deploymentAccess = is_string($headerKey) && strlen($deploymentKey) >= 32 && hash_equals($deploymentKey, $headerKey);
if (strlen($expected) < 32 && strlen($deploymentKey) < 32 && !$deploymentAccess) {
    http_response_code(404);
    exit('Not found.');
}
$provided = $_POST['token'] ?? '';
if (!$deploymentAccess && (!is_string($provided) || strlen($expected) < 32 || !hash_equals($expected, $provided))) {
    http_response_code(403);
    echo '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>CIRCLE diagnostics access</title><h1>CIRCLE diagnostics</h1><form method="post"><label>Diagnostics token or deployment key <input type="password" name="token" autocomplete="off" required></label> <button>View diagnostics</button></form></html>';
    exit;
}

$rows = [
    'PHP version' => PHP_VERSION,
    'PHP handler (SAPI)' => PHP_SAPI,
    'Operating system' => PHP_OS_FAMILY,
    'Composer PHP minimum satisfied' => version_compare(PHP_VERSION, '8.3.0', '>=') ? 'Yes' : 'No: PHP 8.3+ required',
    'Loaded php.ini basename' => basename(php_ini_loaded_file() ?: '(none)'),
];
foreach (['error_reporting', 'display_errors', 'display_startup_errors', 'log_errors', 'memory_limit', 'max_execution_time', 'post_max_size', 'upload_max_filesize', 'max_file_uploads', 'date.timezone', 'opcache.enable'] as $setting) {
    $rows[$setting] = (string) ini_get($setting);
}
foreach (['pdo_mysql', 'mbstring', 'openssl', 'fileinfo', 'gd', 'exif', 'sodium', 'zip', 'Phar', 'zlib'] as $extension) {
    $rows['Extension: ' . $extension] = extension_loaded($extension) ? 'Loaded' : 'Missing';
}
$rows['Password algorithms'] = implode(', ', password_algos());
$rows['Argon2id available'] = defined('PASSWORD_ARGON2ID') && in_array('argon2id', password_algos(), true) ? 'Yes' : 'No';
// Read-only push report: no tokens, user IDs, credentials or provider sends.
require_once $root . '/vendor/autoload.php';
$rows['Push queue enabled'] = \Circle\Core\Env::get('PUSH_QUEUE_ENABLED', 'false') === 'true' ? 'Yes' : 'No';
$rows['Push delivery enabled'] = \Circle\Core\Env::get('PUSH_DELIVERY_ENABLED', 'false') === 'true' ? 'Yes' : 'No';
$rows['Private notification previews enabled'] = \Circle\Core\Env::get('PUSH_PREVIEWS_ENABLED', 'false') === 'true' ? 'Yes' : 'No';
$rows['Push API origin matches app'] = rtrim(\Circle\Core\Env::get('PUSH_API_BASE_URL'), '/') === 'https://circle.cloudkart24.com/api/v1' ? 'Yes' : 'No';
$rows['Firebase project matches app'] = \Circle\Core\Env::get('FCM_PROJECT_ID') === 'circle-c6919' ? 'Yes' : 'No';
$rows['FCM credentials and runtime ready'] = (new \Circle\Core\FcmSender())->isReady() ? 'Yes' : 'No';
$rows['Worker schedule'] = 'Cannot verify cron from web PHP';
try {
    $db = \Circle\Core\Database::connection();
    foreach ($db->query("SELECT platform, COUNT(*) AS total FROM device_tokens GROUP BY platform") as $row) {
        $platform = in_array($row['platform'], ['android', 'ios'], true) ? $row['platform'] : 'other';
        $rows['Registered devices: ' . $platform] = (string) (int) $row['total'];
    }
    foreach ($db->query("SELECT state, COUNT(*) AS total FROM notification_outbox WHERE created_at >= UTC_TIMESTAMP() - INTERVAL 1 DAY GROUP BY state") as $row) {
        if (in_array($row['state'], ['pending','sending','sent','cancelled','dead'], true)) {
            $rows['Push queue last 24 hours: ' . $row['state']] = (string) (int) $row['total'];
        }
    }
    $row = $db->query("SELECT COUNT(*) AS total FROM notification_outbox WHERE state='pending' AND available_at<=UTC_TIMESTAMP() AND expires_at>UTC_TIMESTAMP()")->fetch();
    $rows['Due pending notifications'] = (string) (int) $row['total'];
    foreach ($db->query("SELECT last_error, COUNT(*) AS total FROM notification_outbox WHERE created_at >= UTC_TIMESTAMP() - INTERVAL 1 DAY GROUP BY last_error") as $row) {
        if (in_array($row['last_error'], ['quiet_hours','provider_retry','provider_rejected','retry_exhausted','unregistered','expired'], true)) {
            $rows['Push reason: ' . $row['last_error']] = (string) (int) $row['total'];
        }
    }
    $rows['Database push checks'] = 'Completed';
} catch (\Throwable $error) {
    $rows['Database push checks'] = 'Failed: inspect private server logs; schema or connection may be unavailable';
}
$latestError = \Circle\Core\Log::latest();
$escape = static fn (string $value): string => htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
echo '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>CIRCLE PHP diagnostics</title><h1>CIRCLE PHP version and configuration</h1><p>Selected runtime settings only. Database credentials, environment values, request headers and filesystem paths are excluded.</p><table><caption>Current web runtime</caption><tr><th scope="col">Setting</th><th scope="col">Value</th></tr>';
foreach ($rows as $name => $value) {
    echo '<tr><th scope="row">' . $escape($name) . '</th><td>' . $escape($value) . '</td></tr>';
}
echo '</table><h2>Latest redacted API error</h2><pre>' . $escape($latestError === null ? 'No captured API error.' : (json_encode($latestError, JSON_PRETTY_PRINT | JSON_INVALID_UTF8_SUBSTITUTE) ?: 'Unavailable')) . '</pre>';
echo '<p>Fatal errors: check the hosting PHP error log for [CIRCLE] entries. Remove DIAGNOSTICS_TOKEN after troubleshooting to disable this page.</p></html>';
