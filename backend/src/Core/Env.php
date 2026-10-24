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

        $file = rtrim($path, '/') . '/.env';
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
            if (strlen($value) >= 2 && (
                (str_starts_with($value, '"') && str_ends_with($value, '"'))
                || (str_starts_with($value, "'") && str_ends_with($value, "'"))
            )) {
                $value = substr($value, 1, -1);
            }
            self::$vars[$key] = $value;
        }

        self::$loaded = true;
    }

    /** Override a value at runtime (used by the test bootstrap). */
    public static function set(string $key, string $value): void
    {
        self::$vars[$key] = $value;
    }

    /**
     * Returns the configured value, or $default when unset or empty.
     * Note: "0" is a valid value and is returned as-is.
     */
    public static function get(string $key, string $default = ''): string
    {
        if (array_key_exists($key, self::$vars)) {
            $value = self::$vars[$key];
        } elseif (isset($_ENV[$key]) && is_string($_ENV[$key])) {
            $value = $_ENV[$key];
        } else {
            $env = getenv($key);
            $value = $env === false ? '' : $env;
        }

        return $value === '' ? $default : $value;
    }

    public static function int(string $key, int $default = 0): int
    {
        $val = self::get($key);
        return is_numeric($val) ? (int) $val : $default;
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
