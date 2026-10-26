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
$deploymentAccess = is_string($headerKey) && strlen($deploymentKey) >= 32 && hash_equals($deploymentKey, $headerKey);
if (strlen($expected) < 32 && !$deploymentAccess) {
    http_response_code(404);
    exit('Not found.');
}
$provided = $_POST['token'] ?? '';
if (!$deploymentAccess && (!is_string($provided) || strlen($expected) < 32 || !hash_equals($expected, $provided))) {
    http_response_code(403);
    echo '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>CIRCLE diagnostics access</title><h1>CIRCLE diagnostics</h1><form method="post"><label>Diagnostics token <input type="password" name="token" autocomplete="off" required></label> <button>View PHP configuration</button></form></html>';
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
$latestError = \Circle\Core\Log::latest();
$escape = static fn (string $value): string => htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
echo '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>CIRCLE PHP diagnostics</title><h1>CIRCLE PHP version and configuration</h1><p>Selected runtime settings only. Database credentials, environment values, request headers and filesystem paths are excluded.</p><table><caption>Current web runtime</caption><tr><th scope="col">Setting</th><th scope="col">Value</th></tr>';
foreach ($rows as $name => $value) {
    echo '<tr><th scope="row">' . $escape($name) . '</th><td>' . $escape($value) . '</td></tr>';
}
echo '</table><h2>Latest redacted API error</h2><pre>' . $escape($latestError === null ? 'No captured API error.' : (json_encode($latestError, JSON_PRETTY_PRINT | JSON_INVALID_UTF8_SUBSTITUTE) ?: 'Unavailable')) . '</pre>';
echo '<p>Fatal errors: check the hosting PHP error log for [CIRCLE] entries. Remove DIAGNOSTICS_TOKEN after troubleshooting to disable this page.</p></html>';
