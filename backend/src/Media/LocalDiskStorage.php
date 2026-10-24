<?php

declare(strict_types=1);

namespace Circle\Media;

/**
 * Stores media in a directory OUTSIDE the web root (MEDIA_STORAGE_PATH,
 * default backend/storage/media). Directories are created 0700 and files 0600:
 * only the PHP user reads them; bytes are served via signed links only.
 * Keys are validated strictly, so path traversal is impossible.
 */
final class LocalDiskStorage implements MediaStorage
{
    private const KEY_PATTERN = '#^media(/[A-Za-z0-9][A-Za-z0-9._-]{0,99}){1,4}$#';

    private readonly string $root;

    public function __construct(string $root)
    {
        $root = rtrim($root, '/');
        if ($root === '') {
            throw new \InvalidArgumentException('Media storage root is empty.');
        }
        if (!is_dir($root) && !@mkdir($root, 0700, true) && !is_dir($root)) {
            throw new \RuntimeException('Media storage directory could not be created.');
        }
        $real = realpath($root);
        if ($real === false) {
            throw new \RuntimeException('Media storage directory is not accessible.');
        }
        $this->root = $real;
    }

    public static function defaultRoot(): string
    {
        return dirname(__DIR__, 2) . '/storage/media';
    }

    public function root(): string
    {
        return $this->root;
    }

    private function pathFor(string $key): string
    {
        if (preg_match(self::KEY_PATTERN, $key) !== 1 || str_contains($key, '..')) {
            throw new \InvalidArgumentException('Invalid media storage key.');
        }
        return $this->root . '/' . $key;
    }

    public function put(string $key, string $sourcePath): void
    {
        $target = $this->pathFor($key);
        $dir = dirname($target);
        if (!is_dir($dir) && !@mkdir($dir, 0700, true) && !is_dir($dir)) {
            throw new \RuntimeException('Media directory could not be created.');
        }
        $tmp = $dir . '/.tmp-' . bin2hex(random_bytes(8));
        if (!@copy($sourcePath, $tmp)) {
            throw new \RuntimeException('Media file could not be written.');
        }
        @chmod($tmp, 0600);
        if (!@rename($tmp, $target)) {
            @unlink($tmp);
            throw new \RuntimeException('Media file could not be stored.');
        }
    }

    public function exists(string $key): bool
    {
        return is_file($this->pathFor($key));
    }

    public function deletePrefix(string $prefix): void
    {
        $path = $this->pathFor($prefix);
        if (is_file($path)) {
            @unlink($path);
            return;
        }
        if (is_dir($path)) {
            self::removeTree($path);
        }
    }

    public function localPath(string $key): ?string
    {
        $path = $this->pathFor($key);
        return is_file($path) ? $path : null;
    }

    public function makeScratchDir(): string
    {
        $dir = $this->root . '/.scratch/' . bin2hex(random_bytes(16));
        if (!@mkdir($dir, 0700, true)) {
            throw new \RuntimeException('Scratch directory could not be created.');
        }
        return $dir;
    }

    public function removeScratch(string $dir): void
    {
        $real = realpath($dir);
        if ($real !== false && str_starts_with($real, $this->root . '/.scratch/')) {
            self::removeTree($real);
        }
    }

    private static function removeTree(string $dir): void
    {
        $items = scandir($dir);
        foreach ($items !== false ? $items : [] as $item) {
            if ($item === '.' || $item === '..') {
                continue;
            }
            $path = $dir . '/' . $item;
            if (is_dir($path) && !is_link($path)) {
                self::removeTree($path);
            } else {
                @unlink($path);
            }
        }
        @rmdir($dir);
    }
}
