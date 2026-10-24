<?php

declare(strict_types=1);

namespace Circle\Media;

/**
 * Decodes an uploaded image and re-encodes it into size variants. Re-encoding
 * must drop ALL metadata (EXIF, GPS, XMP, ICC comments, trailing data) so that
 * only pixels survive; the original is never stored.
 */
interface ImageProcessor
{
    /** Whether this processor can decode the given (allowlisted) input type. */
    public function supports(string $mimeType): bool;

    /**
     * @param string $sourcePath local file holding the validated upload
     * @param string $mimeType sniffed input type (one of the allowlist)
     * @param array<string, int> $targets size name => maximum long edge in px
     * @param string $workDir empty private directory for the variant files
     * @throws ImageProcessingException when the content cannot be decoded/encoded
     */
    public function process(string $sourcePath, string $mimeType, array $targets, string $workDir): ProcessedImage;
}
