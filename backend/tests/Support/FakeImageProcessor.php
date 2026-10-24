<?php

declare(strict_types=1);

namespace Circle\Tests\Support;

use Circle\Media\GdImageProcessor;
use Circle\Media\ImageProcessor;
use Circle\Media\ProcessedImage;

/**
 * Deterministic stand-in for GdImageProcessor (this machine has no ext-gd).
 * Reads dimensions from the header and writes small placeholder "variants"
 * that contain none of the original bytes, like a real re-encode.
 */
final class FakeImageProcessor implements ImageProcessor
{
    public bool $heic = false;
    public ?\Throwable $failWith = null;
    public int $calls = 0;

    public function supports(string $mimeType): bool
    {
        return in_array($mimeType, ['image/jpeg', 'image/png', 'image/webp'], true)
            || ($this->heic && $mimeType === 'image/heic');
    }

    public function process(string $sourcePath, string $mimeType, array $targets, string $workDir): ProcessedImage
    {
        $this->calls++;
        if ($this->failWith !== null) {
            throw $this->failWith;
        }
        $info = getimagesize($sourcePath);
        [$width, $height] = $info !== false ? [(int) $info[0], (int) $info[1]] : [4032, 3024];

        $variants = [];
        foreach ($targets as $size => $maxEdge) {
            [$w, $h] = GdImageProcessor::fit($width, $height, $maxEdge);
            $path = $workDir . '/' . $size . '.webp';
            $bytes = "FAKE-WEBP {$size} {$w}x{$h}";
            file_put_contents($path, $bytes);
            $variants[$size] = ['path' => $path, 'width' => $w, 'height' => $h, 'bytes' => strlen($bytes)];
        }
        return new ProcessedImage($width, $height, 'image/webp', 'webp', $variants);
    }
}
