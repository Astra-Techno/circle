<?php

declare(strict_types=1);

/**
 * Simple migration runner. Execute from backend/:
 *   php src/Core/migrate.php
 */

require_once __DIR__ . '/../../vendor/autoload.php';

use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Core\Log;
use Circle\Core\Migrator;

Env::load(__DIR__ . '/../..');

try {
    $applied = Migrator::run(Database::connection(), __DIR__ . '/../../database/migrations');
} catch (\PDOException $e) {
    echo 'FAILED: ' . Log::redact($e->getMessage()) . "\n";
    exit(1);
}

foreach ($applied as $name) {
    echo "Applied: {$name}\n";
}
echo $applied !== [] ? "\n" . count($applied) . " migration(s) applied.\n" : "Nothing to migrate.\n";
