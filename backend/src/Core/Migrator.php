<?php

declare(strict_types=1);

namespace Circle\Core;

use PDO;

/**
 * Applies database/migrations/*.sql in order, one statement at a time so that a
 * failure in any statement is reported (PDO::exec on a multi-statement string
 * can silently stop after the first error).
 */
final class Migrator
{
    /** @return string[] names of the migrations applied */
    public static function run(PDO $pdo, string $dir): array
    {
        $pdo->exec('CREATE TABLE IF NOT EXISTS migrations (
            id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(255) NOT NULL UNIQUE,
            executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci');

        $files = glob(rtrim($dir, '/') . '/*.sql') ?: [];
        sort($files);

        $stmt = $pdo->query('SELECT name FROM migrations');
        $executed = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_COLUMN) : [];

        $applied = [];
        foreach ($files as $file) {
            $name = basename($file);
            if (in_array($name, $executed, true)) {
                continue;
            }
            $sql = file_get_contents($file);
            if ($sql === false || trim($sql) === '') {
                continue;
            }
            foreach (self::split($sql) as $statement) {
                $pdo->exec($statement);
            }
            $insert = $pdo->prepare('INSERT INTO migrations (name) VALUES (:name)');
            $insert->execute(['name' => $name]);
            $applied[] = $name;
        }

        return $applied;
    }

    /**
     * Splits on semicolons at end of line, ignoring `--` comment lines.
     * Migration files must not contain semicolons at line ends inside literals.
     * @return string[]
     */
    public static function split(string $sql): array
    {
        $lines = array_filter(
            preg_split('/\R/', $sql) ?: [],
            static fn (string $l): bool => !str_starts_with(ltrim($l), '--')
        );
        $parts = preg_split('/;\s*$/m', implode("\n", $lines)) ?: [];
        return array_values(array_filter(array_map('trim', $parts), static fn (string $s): bool => $s !== ''));
    }
}
