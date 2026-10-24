<?php

declare(strict_types=1);

namespace Circle\Media;

/**
 * ext-gd implementation. Decodes JPEG/PNG/WebP, applies the EXIF orientation
 * (when ext-exif is present), then re-encodes every size to WebP (or JPEG when
 * this GD build has no WebP encoder). GD writes only pixels, so EXIF/GPS and
 * any other metadata or trailing data are dropped. HEIC is not supported by
 * GD; it needs an Imagick build with libheif (not implemented yet).
 *
 * Memory: GD holds the decoded image at ~4-5 bytes per pixel plus each resized
 * copy, so PHP's memory_limit must cover MEDIA_MAX_PIXELS × 5 (≈ 200 MB for the
 * 40 MP default; the app sends ≤ 2048 px, ≈ 20 MB).
 */
final class GdImageProcessor implements ImageProcessor
{
    private const WEBP_QUALITY = 80;
    private const JPEG_QUALITY = 82;

    public static function isAvailable(): bool
    {
        return extension_loaded('gd') && function_exists('imagecreatefromstring');
    }

    public function supports(string $mimeType): bool
    {
        if (!self::isAvailable()) {
            return false;
        }
        $types = imagetypes();
        return match ($mimeType) {
            'image/jpeg' => ($types & IMG_JPG) !== 0,
            'image/png' => ($types & IMG_PNG) !== 0,
            'image/webp' => ($types & IMG_WEBP) !== 0,
            default => false,
        };
    }

    private static function canWriteWebp(): bool
    {
        return function_exists('imagewebp') && (imagetypes() & IMG_WEBP) !== 0;
    }

    public function process(string $sourcePath, string $mimeType, array $targets, string $workDir): ProcessedImage
    {
        if (!$this->supports($mimeType)) {
            throw new ImageProcessingException('Unsupported input type.');
        }

        $bytes = file_get_contents($sourcePath);
        if ($bytes === false) {
            throw new ImageProcessingException('Upload is not readable.');
        }

        $image = @imagecreatefromstring($bytes);
        unset($bytes);
        if ($image === false) {
            throw new ImageProcessingException('Image could not be decoded.');
        }

        try {
            if ($mimeType === 'image/jpeg') {
                $image = $this->applyExifOrientation($image, $sourcePath);
            }

            $width = imagesx($image);
            $height = imagesy($image);
            $webp = self::canWriteWebp();
            $ext = $webp ? 'webp' : 'jpg';

            $variants = [];
            foreach ($targets as $size => $maxEdge) {
                [$w, $h] = self::fit($width, $height, $maxEdge);
                $dst = imagecreatetruecolor($w, $h);
                if ($dst === false) {
                    throw new ImageProcessingException('Could not allocate the resized image.');
                }
                try {
                    if ($webp) {
                        imagealphablending($dst, false);
                        imagesavealpha($dst, true);
                        $transparent = imagecolorallocatealpha($dst, 0, 0, 0, 127);
                        if ($transparent !== false) {
                            imagefill($dst, 0, 0, $transparent);
                        }
                    } else {
                        // JPEG has no alpha: flatten onto white.
                        $white = imagecolorallocate($dst, 255, 255, 255);
                        if ($white !== false) {
                            imagefill($dst, 0, 0, $white);
                        }
                    }
                    if (!imagecopyresampled($dst, $image, 0, 0, 0, 0, $w, $h, $width, $height)) {
                        throw new ImageProcessingException('Resize failed.');
                    }

                    $path = rtrim($workDir, '/') . '/' . $size . '.' . $ext;
                    $ok = $webp
                        ? imagewebp($dst, $path, self::WEBP_QUALITY)
                        : imagejpeg($dst, $path, self::JPEG_QUALITY);
                    if (!$ok) {
                        throw new ImageProcessingException('Encoding failed.');
                    }
                } finally {
                    imagedestroy($dst);
                }

                clearstatcache(true, $path);
                $variants[$size] = ['path' => $path, 'width' => $w, 'height' => $h, 'bytes' => (int) filesize($path)];
            }

            return new ProcessedImage($width, $height, $webp ? 'image/webp' : 'image/jpeg', $ext, $variants);
        } finally {
            imagedestroy($image);
        }
    }

    /**
     * Largest size within $maxEdge on the long edge, preserving aspect ratio; never upscales.
     * @return array{0: int, 1: int}
     */
    public static function fit(int $width, int $height, int $maxEdge): array
    {
        $long = max($width, $height);
        if ($long <= $maxEdge) {
            return [$width, $height];
        }
        $scale = $maxEdge / $long;
        return [max(1, (int) round($width * $scale)), max(1, (int) round($height * $scale))];
    }

    private function applyExifOrientation(\GdImage $image, string $path): \GdImage
    {
        if (!function_exists('exif_read_data')) {
            return $image;
        }
        $exif = @exif_read_data($path);
        $orientation = is_array($exif) && isset($exif['Orientation']) && is_int($exif['Orientation'])
            ? $exif['Orientation'] : 1;

        $rotate = static function (\GdImage $img, int $angle): \GdImage {
            $rotated = imagerotate($img, $angle, 0);
            if ($rotated === false) {
                return $img;
            }
            imagedestroy($img);
            return $rotated;
        };

        switch ($orientation) {
            case 2:
                imageflip($image, IMG_FLIP_HORIZONTAL);
                return $image;
            case 3:
                return $rotate($image, 180);
            case 4:
                imageflip($image, IMG_FLIP_VERTICAL);
                return $image;
            case 5:
                $image = $rotate($image, 270);
                imageflip($image, IMG_FLIP_HORIZONTAL);
                return $image;
            case 6:
                return $rotate($image, 270);
            case 7:
                $image = $rotate($image, 90);
                imageflip($image, IMG_FLIP_HORIZONTAL);
                return $image;
            case 8:
                return $rotate($image, 90);
            default:
                return $image;
        }
    }
}
