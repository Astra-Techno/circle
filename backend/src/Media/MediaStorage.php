<?php

declare(strict_types=1);

namespace Circle\Media;

/**
 * Private object storage for re-encoded media variants. Keys look like
 * `media/{group_id}/{random uuid}/{size}.{ext}` and never leave the server.
 * Implementations: LocalDiskStorage (development / v1). An S3-compatible
 * implementation (S3, R2, MinIO) is planned; it would serve bytes via its own
 * short-lived signed URLs instead of localPath().
 */
interface MediaStorage
{
    /** Moves the local file $sourcePath into storage under $key (replacing any existing object). */
    public function put(string $key, string $sourcePath): void;

    public function exists(string $key): bool;

    /** Deletes every object under the key prefix (a "directory"). Idempotent. */
    public function deletePrefix(string $prefix): void;

    /** Absolute local path for streaming/X-Sendfile, or null when the object is missing. */
    public function localPath(string $key): ?string;

    /** A fresh private scratch directory for processing (caller removes it with removeScratch()). */
    public function makeScratchDir(): string;

    public function removeScratch(string $dir): void;
}
