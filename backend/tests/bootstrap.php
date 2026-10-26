<?php

declare(strict_types=1);

/**
 * Test bootstrap: points the app at the dedicated `circle_test` database,
 * drops and recreates every table there, and switches Response into capture
 * mode so requests can be dispatched in-process.
 *
 * Connection settings can be overridden with CIRCLE_TEST_DB_HOST/PORT/USER/PASSWORD.
 * The database name is fixed: this bootstrap never touches any other database.
 */

require_once __DIR__ . '/../vendor/autoload.php';

use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Core\Migrator;
use Circle\Core\Response;

date_default_timezone_set('UTC');

// Keep expected error logs out of the test output (directory is gitignored).
@mkdir(__DIR__ . '/../.phpunit.cache', 0775, true);
ini_set('error_log', __DIR__ . '/../.phpunit.cache/test-error.log');

const CIRCLE_TEST_DATABASE = 'circle_test';

$host = getenv('CIRCLE_TEST_DB_HOST') ?: '127.0.0.1';
$port = getenv('CIRCLE_TEST_DB_PORT') ?: '3306';
$user = getenv('CIRCLE_TEST_DB_USER') ?: 'root';
$pass = getenv('CIRCLE_TEST_DB_PASSWORD') ?: '';

$settings = [
    'APP_ENV' => 'testing',
    'PUSH_QUEUE_ENABLED' => 'false',
    'PUSH_DELIVERY_ENABLED' => 'false',
    'PUSH_API_BASE_URL' => '',
    'DB_HOST' => $host,
    'DB_PORT' => $port,
    'DB_DATABASE' => CIRCLE_TEST_DATABASE,
    'DB_USERNAME' => $user,
    'DB_PASSWORD' => $pass,
    // Test-only random secret, generated per run.
    'JWT_SECRET' => bin2hex(random_bytes(32)),
    'JWT_EXPIRY' => '3600',
    'JWT_REFRESH_EXPIRY' => '604800',
    'CORS_ORIGIN' => 'https://allowed.example',
    'RATE_LIMIT_PER_MINUTE' => '100000',
    'RATE_LIMIT_AUTH_PER_MINUTE' => '100000',
    'LOGIN_MAX_FAILURES_PER_MOBILE' => '100000',
    // Media: separate test-only signing secret and a throwaway storage folder.
    'MEDIA_SIGNING_SECRET' => bin2hex(random_bytes(32)),
    'MEDIA_STORAGE_PATH' => __DIR__ . '/../.phpunit.cache/media-' . bin2hex(random_bytes(6)),
    'MEDIA_LINK_TTL' => '300',
    'MEDIA_MAX_BYTES' => '15728640',
    'MEDIA_UPLOADS_PER_HOUR' => '100000',
    'MEDIA_MAX_OPEN_UPLOADS' => '100000',
    'MEDIA_PURGE_AFTER_DAYS' => '7',
    'MEDIA_SENDFILE_MODE' => 'none',
];
foreach ($settings as $key => $value) {
    Env::set($key, $value);
}

// Remove the test media folder when the run ends.
register_shutdown_function(static function () use ($settings): void {
    $root = $settings['MEDIA_STORAGE_PATH'];
    if (!is_dir($root)) {
        return;
    }
    $it = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS),
        RecursiveIteratorIterator::CHILD_FIRST
    );
    foreach ($it as $file) {
        /** @var SplFileInfo $file */
        $file->isDir() && !$file->isLink() ? @rmdir($file->getPathname()) : @unlink($file->getPathname());
    }
    @rmdir($root);
});

$server = new PDO("mysql:host={$host};port={$port};charset=utf8mb4", $user, $pass, [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
]);
$server->exec('CREATE DATABASE IF NOT EXISTS `' . CIRCLE_TEST_DATABASE . '` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');

$pdo = Database::connection();
$current = $pdo->query('SELECT DATABASE()');
if ($current === false || $current->fetchColumn() !== CIRCLE_TEST_DATABASE) {
    fwrite(STDERR, "Refusing to run: connected database is not " . CIRCLE_TEST_DATABASE . "\n");
    exit(1);
}

// Fresh schema: drop every table in circle_test, then run all migrations.
$pdo->exec('SET FOREIGN_KEY_CHECKS = 0');
$tables = $pdo->query('SHOW FULL TABLES WHERE Table_type = \'BASE TABLE\'');
foreach ($tables !== false ? $tables->fetchAll(PDO::FETCH_COLUMN) : [] as $table) {
    $pdo->exec('DROP TABLE IF EXISTS `' . str_replace('`', '', (string) $table) . '`');
}
$pdo->exec('SET FOREIGN_KEY_CHECKS = 1');

Migrator::run($pdo, __DIR__ . '/../database/migrations');

Response::enableCapture();
