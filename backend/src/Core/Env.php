<?php

declare(strict_types=1);

namespace Circle\Core;

final class Env
{
    /** @var array<string, string> */
    private static array $vars = [];
    private static bool $loaded = false;

    public static function load(string $path): void
    {
        if (self::$loaded) {
            return;
        }

        $file = $path . '/.env';
        if (!file_exists($file)) {
            return;
        }

        $lines = file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if ($lines === false) {
            return;
        }

        foreach ($lines as $line) {
            $line = trim($line);
            if ($line === '' || str_starts_with($line, '#')) {
                continue;
            }
            $pos = strpos($line, '=');
            if ($pos === false) {
                continue;
            }
            $key = trim(substr($line, 0, $pos));
            $value = trim(substr($line, $pos + 1));
            if ((str_starts_with($value, '"') && str_ends_with($value, '"'))
                || (str_starts_with($value, "'") && str_ends_with($value, "'"))) {
                $value = substr($value, 1, -1);
            }
            self::$vars[$key] = $value;
        }

        self::$loaded = true;
    }

    public static function get(string $key, string $default = ''): string
    {
        return self::$vars[$key] ?? $_ENV[$key] ?? getenv($key) ?: $default;
    }

    public static function int(string $key, int $default = 0): int
    {
        $val = self::get($key);
        return $val !== '' ? (int) $val : $default;
    }

    public static function bool(string $key, bool $default = false): bool
    {
        $val = self::get($key);
        if ($val === '') {
            return $default;
        }
        return in_array(strtolower($val), ['true', '1', 'yes', 'on'], true);
    }
}
