<?php

declare(strict_types=1);

/**
 * Simple migration runner. Execute from backend/:
 *   php src/Core/migrate.php
 */

require_once __DIR__ . '/../../vendor/autoload.php';

use Circle\Core\Database;
use Circle\Core\Env;

Env::load(__DIR__ . '/../../');

$pdo = Database::connection();

// Create migrations tracking table
$pdo->exec('CREATE TABLE IF NOT EXISTS migrations (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci');

$migrationDir = __DIR__ . '/../../database/migrations';
$files = glob($migrationDir . '/*.sql');
if ($files === false) {
    echo "No migration files found.\n";
    exit(0);
}

sort($files);

$executed = $pdo->query('SELECT name FROM migrations')->fetchAll(PDO::FETCH_COLUMN);

$count = 0;
foreach ($files as $file) {
    $name = basename($file);
    if (in_array($name, $executed, true)) {
        continue;
    }

    $sql = file_get_contents($file);
    if ($sql === false || trim($sql) === '') {
        echo "SKIP (empty): {$name}\n";
        continue;
    }

    echo "Running: {$name} ... ";

    try {
        $pdo->exec($sql);
        $stmt = $pdo->prepare('INSERT INTO migrations (name) VALUES (:name)');
        $stmt->execute(['name' => $name]);
        echo "OK\n";
        $count++;
    } catch (\PDOException $e) {
        echo "FAILED: " . $e->getMessage() . "\n";
        exit(1);
    }
}

echo $count > 0 ? "\n{$count} migration(s) applied.\n" : "Nothing to migrate.\n";
