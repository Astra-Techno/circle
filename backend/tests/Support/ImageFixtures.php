<?php

declare(strict_types=1);

namespace Circle\Tests\Support;

/**
 * Hand-built image bytes (no GD needed): valid headers that finfo and
 * getimagesize() recognise.
 */
final class ImageFixtures
{
    /** Marker standing in for GPS/EXIF data that must never be stored. */
    public const GPS_MARKER = 'GPS-13.0827N-80.2707E-SECRET-HOME';

    private static function chunk(string $type, string $data): string
    {
        return pack('N', strlen($data)) . $type . $data . pack('N', crc32($type . $data));
    }

    /** A real, decodable 8-bit RGB PNG. */
    public static function png(int $width = 40, int $height = 30): string
    {
        $raw = str_repeat("\x00" . str_repeat("\xC0\x40\x20", $width), $height);
        $idat = gzcompress($raw);
        return "\x89PNG\r\n\x1A\n"
            . self::chunk('IHDR', pack('NNCCCCC', $width, $height, 8, 2, 0, 0, 0))
            . self::chunk('IDAT', $idat !== false ? $idat : '')
            . self::chunk('tEXt', "Comment\x00" . self::GPS_MARKER)
            . self::chunk('IEND', '');
    }

    /** PNG header claiming huge dimensions (decompression bomb) with a tiny body. */
    public static function pngBomb(int $width, int $height): string
    {
        $idat = gzcompress(str_repeat("\x00", 64));
        return "\x89PNG\r\n\x1A\n"
            . self::chunk('IHDR', pack('NNCCCCC', $width, $height, 8, 2, 0, 0, 0))
            . self::chunk('IDAT', $idat !== false ? $idat : '')
            . self::chunk('IEND', '');
    }

    /** EXIF APP1 segment: Orientation tag plus a GPS-like marker. */
    public static function exifSegment(int $orientation = 1): string
    {
        $tiff = 'II' . pack('v', 42) . pack('V', 8)
            . pack('v', 1)
            . pack('vvVvv', 0x0112, 3, 1, $orientation, 0)
            . pack('V', 0)
            . self::GPS_MARKER;
        $payload = "Exif\x00\x00" . $tiff;
        return "\xFF\xE1" . pack('n', strlen($payload) + 2) . $payload;
    }

    /** JPEG header (SOI, JFIF, EXIF with marker, SOF0, EOI): enough for finfo + getimagesize. */
    public static function jpegHeader(int $width = 64, int $height = 48): string
    {
        $jfif = "JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00";
        $sof = "\x08" . pack('nn', $height, $width) . "\x03\x01\x22\x00\x02\x11\x01\x03\x11\x01";
        return "\xFF\xD8"
            . "\xFF\xE0" . pack('n', strlen($jfif) + 2) . $jfif
            . self::exifSegment(6)
            . "\xFF\xC0" . pack('n', strlen($sof) + 2) . $sof
            . "\xFF\xD9";
    }

    /** Inserts an EXIF APP1 segment right after SOI of a real JPEG. */
    public static function withExif(string $jpeg, int $orientation): string
    {
        return substr($jpeg, 0, 2) . self::exifSegment($orientation) . substr($jpeg, 2);
    }

    /** Lossless WebP (VP8L) header. */
    public static function webpHeader(int $width = 50, int $height = 20): string
    {
        $bits = ($width - 1) | (($height - 1) << 14);
        $vp8l = "\x2F" . pack('V', $bits) . "\x00\x00\x00\x00\x00\x00";
        $chunk = 'VP8L' . pack('V', strlen($vp8l)) . $vp8l;
        return 'RIFF' . pack('V', 4 + strlen($chunk)) . 'WEBP' . $chunk;
    }

    public static function heicHeader(): string
    {
        return pack('N', 24) . 'ftypheic' . pack('N', 0) . 'mif1heic' . str_repeat("\x00", 32);
    }
}
