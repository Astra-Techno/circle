<?php

declare(strict_types=1);

/**
 * CIRCLE — web-based migration runner for shared hosting (no SSH).
 *
 * Usage:
 *   https://circle.cloudkart24.com/_migrate.php?token=YOUR_MIGRATE_TOKEN
 *
 * Set MIGRATE_TOKEN in .env to a random string (at least 32 chars).
 * After migrations succeed, DELETE this file from the server for security.
 */

require_once __DIR__ . '/vendor/autoload.php';

use Circle\Core\Env;
use Circle\Core\Migrator;
use Circle\Core\Database;

date_default_timezone_set('UTC');
ini_set('display_errors', '0');
error_reporting(E_ALL);

header('Content-Type: text/plain; charset=utf-8');

Env::load(__DIR__);

// ── Token guard ──────────────────────────────────────────────
$expectedToken = Env::get('MIGRATE_TOKEN');
$givenToken = $_GET['token'] ?? '';

if ($expectedToken === '' || strlen($expectedToken) < 32) {
    http_response_code(500);
    echo "ERROR: Set MIGRATE_TOKEN in .env (at least 32 random characters).\n";
    exit;
}

if (!hash_equals($expectedToken, $givenToken)) {
    http_response_code(403);
    echo "ERROR: Invalid or missing token.\n";
    exit;
}

// ── Run migrations ───────────────────────────────────────────
try {
    $pdo = Database::connection();
    $applied = Migrator::run($pdo, __DIR__ . '/database/migrations');

    if ($applied === []) {
        echo "OK: All migrations were already applied. Nothing to do.\n";
    } else {
        echo "OK: Applied " . count($applied) . " migration(s):\n";
        foreach ($applied as $name) {
            echo "  - $name\n";
        }
    }

    // Show current state
    $stmt = $pdo->query('SELECT name, executed_at FROM migrations ORDER BY id');
    echo "\nAll migrations:\n";
    if ($stmt !== false) {
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
            echo "  [{$row['executed_at']}] {$row['name']}\n";
        }
    }

    echo "\nSUCCESS. Now DELETE _migrate.php from the server.\n";
} catch (Throwable $e) {
    http_response_code(500);
    echo "MIGRATION FAILED:\n";
    echo $e->getMessage() . "\n";
    echo "at " . basename($e->getFile()) . ":" . $e->getLine() . "\n";
}
