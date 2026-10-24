<?php

declare(strict_types=1);

namespace Circle\Media;

use Circle\Core\Env;

/**
 * Static wiring for media dependencies (the backend has no container).
 * Production: GdImageProcessor when ext-gd is loaded (else none: uploads fail
 * closed) and LocalDiskStorage at MEDIA_STORAGE_PATH. Tests override both.
 */
final class MediaServices
{
    private static ?ImageProcessor $processor = null;
    private static bool $processorOverridden = false;
    private static ?MediaStorage $storage = null;

    /** The image processor, or null when none is available on this server. */
    public static function processor(): ?ImageProcessor
    {
        if (self::$processorOverridden) {
            return self::$processor;
        }
        return GdImageProcessor::isAvailable() ? new GdImageProcessor() : null;
    }

    /** Test hook: force a processor (or none). */
    public static function setProcessor(?ImageProcessor $processor): void
    {
        self::$processor = $processor;
        self::$processorOverridden = true;
    }

    public static function storage(): MediaStorage
    {
        return self::$storage ?? new LocalDiskStorage(Env::get('MEDIA_STORAGE_PATH', LocalDiskStorage::defaultRoot()));
    }

    /** Test hook. */
    public static function setStorage(?MediaStorage $storage): void
    {
        self::$storage = $storage;
    }

    public static function reset(): void
    {
        self::$processor = null;
        self::$processorOverridden = false;
        self::$storage = null;
    }
}
