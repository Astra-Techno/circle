<?php

declare(strict_types=1);

namespace Circle\Media;

/** Result of re-encoding one upload into its size variants (local temp files). */
final class ProcessedImage
{
    /**
     * @param array<string, array{path: string, width: int, height: int, bytes: int}> $variants keyed by size name
     */
    public function __construct(
        public readonly int $width,
        public readonly int $height,
        public readonly string $mimeType,
        public readonly string $extension,
        public readonly array $variants,
    ) {
    }
}
