<?php

declare(strict_types=1);

namespace Circle\Media;

/**
 * Checks the REAL content of an upload before any decoding: magic bytes, the
 * libmagic (finfo) verdict and header dimensions. File names and the client's
 * Content-Type are never trusted. Works without GD (getimagesize is core PHP).
 */
final class ImageInspector
{
    public const MAX_SIDE = 12000;
    public const DEFAULT_MAX_PIXELS = 40_000_000;

    /** finfo results accepted for each real type. */
    private const FINFO_ALIASES = [
        'image/jpeg' => ['image/jpeg', 'image/pjpeg'],
        'image/png' => ['image/png', 'image/x-png'],
        'image/webp' => ['image/webp', 'image/x-webp'],
        'image/heic' => ['image/heic', 'image/heif', 'image/heic-sequence', 'image/heif-sequence'],
    ];

    /** getimagesize() types for each real type. */
    private const IMAGETYPES = [
        'image/jpeg' => IMAGETYPE_JPEG,
        'image/png' => IMAGETYPE_PNG,
        'image/webp' => IMAGETYPE_WEBP,
    ];

    /** Real type from magic bytes, or null when it is none of the known image types. */
    public static function magicType(string $bytes): ?string
    {
        if (str_starts_with($bytes, "\xFF\xD8\xFF")) {
            return 'image/jpeg';
        }
        if (str_starts_with($bytes, "\x89PNG\r\n\x1A\n")) {
            return 'image/png';
        }
        if (strlen($bytes) >= 12 && substr($bytes, 0, 4) === 'RIFF' && substr($bytes, 8, 4) === 'WEBP') {
            return 'image/webp';
        }
        if (strlen($bytes) >= 12 && substr($bytes, 4, 4) === 'ftyp'
            && in_array(substr($bytes, 8, 4), ['heic', 'heix', 'heim', 'heis', 'hevc', 'hevx', 'mif1', 'msf1'], true)
        ) {
            return 'image/heic';
        }
        return null;
    }

    /**
     * @param string[] $allowed real types this server accepts right now
     * @return array{mime: string, width: int|null, height: int|null}
     * @throws MediaRejected
     */
    public static function inspect(string $bytes, string $declaredMime, array $allowed, int $maxPixels = self::DEFAULT_MAX_PIXELS): array
    {
        $real = self::magicType($bytes);
        if ($real === null || !in_array($real, $allowed, true)) {
            throw new MediaRejected(415, 'media_type_not_allowed', 'This file type is not supported. Use a JPEG, PNG or WebP photo.');
        }

        $finfo = new \finfo(FILEINFO_MIME_TYPE);
        $sniffed = $finfo->buffer($bytes);
        if (!is_string($sniffed) || !in_array($sniffed, self::FINFO_ALIASES[$real], true)) {
            throw new MediaRejected(422, 'media_invalid', 'This photo could not be read.');
        }

        if ($real !== $declaredMime) {
            throw new MediaRejected(422, 'media_invalid', 'The photo does not match the type given when the upload started.');
        }

        if (!isset(self::IMAGETYPES[$real])) {
            // HEIC: the processor checks dimensions while decoding.
            return ['mime' => $real, 'width' => null, 'height' => null];
        }

        $info = @getimagesizefromstring($bytes);
        if ($info === false || $info[2] !== self::IMAGETYPES[$real]) {
            throw new MediaRejected(422, 'media_invalid', 'This photo could not be read.');
        }

        [$width, $height] = [(int) $info[0], (int) $info[1]];
        self::checkDimensions($width, $height, $maxPixels);

        return ['mime' => $real, 'width' => $width, 'height' => $height];
    }

    /** @throws MediaRejected */
    public static function checkDimensions(int $width, int $height, int $maxPixels = self::DEFAULT_MAX_PIXELS): void
    {
        if ($width < 1 || $height < 1 || $width > self::MAX_SIDE || $height > self::MAX_SIDE
            || $width * $height > $maxPixels
        ) {
            throw new MediaRejected(422, 'media_invalid', 'This photo is too large in pixels. Use a smaller photo.');
        }
    }
}
