<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Core\Log;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Media\ImageInspector;
use Circle\Media\ImageProcessingException;
use Circle\Media\ImageProcessor;
use Circle\Media\MediaRejected;
use Circle\Media\MediaServices;
use Circle\Media\MediaSigner;
use Circle\Media\MediaStorage;
use Circle\Media\Uuid;
use Circle\Middleware\RateLimitMiddleware;
use Circle\Repositories\MediaRepository;
use Circle\Repositories\MemberRepository;

/**
 * Private media (ADR 0007): upload tickets, content upload with server-side
 * re-encoding, short-lived signed links and signed downloads.
 * Access is always active membership of the asset's EXACT group, re-checked on
 * every link request; unknown and inaccessible media look the same (404).
 */
final class MediaController
{
    public const TICKET_TTL_SECONDS = 900;
    public const DEFAULT_MAX_BYTES = 15_728_640;
    public const DEFAULT_UPLOADS_PER_HOUR = 60;
    public const DEFAULT_MAX_OPEN_UPLOADS = 50;
    /** Extra bytes read beyond the declared size before refusing (413). */
    private const BODY_TOLERANCE = 1024;

    /** size name => maximum long edge (px) */
    public const TARGETS = ['thumb' => 320, 'medium' => 1080, 'full' => 2048];

    private const BASE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

    public static function maxBytes(): int
    {
        return max(1, min(self::DEFAULT_MAX_BYTES, Env::int('MEDIA_MAX_BYTES', self::DEFAULT_MAX_BYTES)));
    }

    /**
     * Types accepted right now: JPEG/PNG/WebP when the processor decodes them,
     * HEIC only when the processor reports support (GD never does).
     * @return string[]
     */
    private static function allowedTypes(ImageProcessor $processor): array
    {
        $types = array_values(array_filter(self::BASE_TYPES, $processor->supports(...)));
        if ($processor->supports('image/heic')) {
            $types[] = 'image/heic';
        }
        return $types;
    }

    /** Fails closed: no processor means no uploads at all (never store originals). */
    private static function requireProcessor(): ImageProcessor
    {
        $processor = MediaServices::processor();
        if ($processor === null) {
            Log::exception('media', new \RuntimeException('No image processor available (install ext-gd).'));
            Response::unavailable('Photo uploads are temporarily unavailable. Please try again later.');
        }
        return $processor;
    }

    private static function mediaNotFound(): never
    {
        Response::notFound('Photo not found.');
    }

    // ── POST /groups/{id}/media/uploads ─────────────────────────

    public static function createUpload(Request $request): void
    {
        MediaSigner::secret();
        $processor = self::requireProcessor();

        $userId = $request->userId();
        $groupId = (int) $request->param('id');
        MemberRepository::requireActiveMember($groupId, $userId);

        $clientUploadId = Uuid::normalise($request->input('client_upload_id'));
        $mime = $request->input('mime_type');
        $size = $request->input('byte_size');
        $sha = $request->input('sha256');

        if ($clientUploadId === null) {
            Response::validationError('client_upload_id must be a UUID.');
        }
        if (!is_string($mime) || $mime === '') {
            Response::validationError('mime_type is required.');
        }
        if (!is_int($size) || $size < 1) {
            Response::validationError('byte_size must be a positive whole number.');
        }
        if (!is_string($sha) || preg_match('/^[a-fA-F0-9]{64}$/', $sha) !== 1) {
            Response::validationError('sha256 must be 64 hexadecimal characters.');
        }
        $sha = strtolower($sha);
        $mime = strtolower(trim($mime));

        // Idempotent replay: same person + client_upload_id → the same ticket.
        $existing = MediaRepository::findByClientUploadId($userId, $clientUploadId);
        if ($existing !== null) {
            if ($existing['group_id'] !== $groupId || $existing['declared_mime'] !== $mime
                || $existing['declared_size'] !== $size || $existing['declared_sha256'] !== $sha
            ) {
                Response::error('conflict', 'This client_upload_id was already used for a different upload.', 409);
            }
            Response::created(self::presentTicket($existing), 'Upload ticket ready.');
        }

        if (!in_array($mime, self::allowedTypes($processor), true)) {
            Response::error('media_type_not_allowed', 'This file type is not supported. Use a JPEG, PNG or WebP photo.', 415);
        }
        if ($size > self::maxBytes()) {
            Response::error('media_too_large', 'This photo is too large. The limit is 15 MB.', 413);
        }

        if (MediaRepository::countOpenUploads($userId) >= Env::int('MEDIA_MAX_OPEN_UPLOADS', self::DEFAULT_MAX_OPEN_UPLOADS)) {
            Response::error(
                'media_limit_reached',
                'You have too many photos waiting to be shared. Share or discard some first.',
                422
            );
        }

        RateLimitMiddleware::consumeForUser(
            $userId,
            'media_ticket',
            Env::int('MEDIA_UPLOADS_PER_HOUR', self::DEFAULT_UPLOADS_PER_HOUR),
            3600,
            'Too many photo uploads. Please try again later.'
        );

        $id = Uuid::v4();
        MediaRepository::createTicket($id, $groupId, $userId, $clientUploadId, $mime, $size, $sha, self::TICKET_TTL_SECONDS);

        $asset = MediaRepository::find($id);
        if ($asset === null) {
            throw new \LogicException('Upload ticket vanished after insert.');
        }
        Response::created(self::presentTicket($asset), 'Upload ticket ready.');
    }

    /**
     * @param array<string, mixed> $asset
     * @return array<string, mixed>
     */
    private static function presentTicket(array $asset): array
    {
        return [
            'upload_id' => $asset['id'],
            'upload_path' => '/media/uploads/' . $asset['id'] . '/content',
            'expires_at' => $asset['ticket_expires_at'],
            'max_bytes' => $asset['declared_size'],
        ];
    }

    // ── PUT /media/uploads/{uploadId}/content ───────────────────

    public static function uploadContent(Request $request): void
    {
        MediaSigner::secret();
        $processor = self::requireProcessor();

        $userId = $request->userId();
        $id = Uuid::normalise($request->param('uploadId'));
        $asset = $id !== null ? MediaRepository::find($id) : null;

        // Only the ticket's owner, still an active member of the exact group.
        if ($asset === null || $asset['uploader_id'] !== $userId
            || $asset['status'] === 'deleted'
            || !MemberRepository::isActiveMember($asset['group_id'], $userId)
        ) {
            self::mediaNotFound();
        }

        if ($asset['status'] === 'ready') {
            Response::ok(MediaRepository::present($asset), 'Photo ready.');
        }
        if ($asset['status'] === 'failed') {
            Response::error('media_invalid', 'This photo could not be processed. Start a new upload.', 422);
        }
        if ($asset['ticket_expired']) {
            Response::error('upload_expired', 'This upload has expired. Start a new upload.', 410);
        }

        $declaredSize = (int) $asset['declared_size'];
        $bytes = $request->readRawBody(min($declaredSize + self::BODY_TOLERANCE, self::maxBytes()));
        if ($bytes === null) {
            Response::error('media_too_large', 'This photo is larger than announced or over the 15 MB limit.', 413);
        }
        if ($bytes === '' || strlen($bytes) !== $declaredSize || !hash_equals((string) $asset['declared_sha256'], hash('sha256', $bytes))) {
            Response::error('media_invalid', 'The photo does not match the size or checksum given when the upload started.', 422);
        }

        try {
            $info = ImageInspector::inspect(
                $bytes,
                (string) $asset['declared_mime'],
                self::allowedTypes($processor),
                Env::int('MEDIA_MAX_PIXELS', ImageInspector::DEFAULT_MAX_PIXELS)
            );
        } catch (MediaRejected $e) {
            Response::error($e->errorCode, $e->getMessage(), $e->status);
        }

        $storage = MediaServices::storage();
        $result = self::processAndStore($storage, $processor, $asset, $bytes, $info['mime']);
        unset($bytes);

        if (!$result) {
            Response::error('media_invalid', 'This photo could not be processed. Try a different photo.', 422);
        }

        $fresh = MediaRepository::find((string) $asset['id']);
        if ($fresh === null) {
            self::mediaNotFound();
        }
        Response::ok(MediaRepository::present($fresh), 'Photo ready.');
    }

    /**
     * Writes the upload to a private scratch dir, re-encodes it into the size
     * variants, stores only the variants and marks the asset ready. The scratch
     * dir (holding the original) is always removed. Returns false when the
     * content could not be decoded (asset marked failed).
     *
     * @param array<string, mixed> $asset
     */
    private static function processAndStore(
        MediaStorage $storage,
        ImageProcessor $processor,
        array $asset,
        string $bytes,
        string $mime
    ): bool {
        $id = (string) $asset['id'];
        $scratch = $storage->makeScratchDir();
        $prefix = 'media/' . (int) $asset['group_id'] . '/' . Uuid::v4();
        $stored = false;

        try {
            $source = $scratch . '/upload.bin';
            if (file_put_contents($source, $bytes) !== strlen($bytes)) {
                throw new \RuntimeException('Scratch write failed.');
            }
            @chmod($source, 0600);
            $workDir = $scratch . '/out';
            if (!@mkdir($workDir, 0700)) {
                throw new \RuntimeException('Scratch dir failed.');
            }

            try {
                $processed = $processor->process($source, $mime, self::TARGETS, $workDir);
            } catch (ImageProcessingException $e) {
                Log::exception('media_processing', $e);
                MediaRepository::markFailed($id);
                return false;
            }

            ImageInspector::checkDimensions($processed->width, $processed->height, Env::int('MEDIA_MAX_PIXELS', ImageInspector::DEFAULT_MAX_PIXELS));

            $variants = [];
            foreach (array_keys(self::TARGETS) as $size) {
                $variant = $processed->variants[$size] ?? null;
                if ($variant === null) {
                    throw new \RuntimeException('Processor did not produce every size.');
                }
                $stored = true;
                $storage->put($prefix . '/' . $size . '.' . $processed->extension, $variant['path']);
                $variants[$size] = [
                    'width' => $variant['width'],
                    'height' => $variant['height'],
                    'bytes' => $variant['bytes'],
                    'ext' => $processed->extension,
                ];
            }

            $ready = MediaRepository::markReady(
                $id,
                $prefix,
                $processed->mimeType,
                $processed->width,
                $processed->height,
                $variants['full']['bytes'],
                $variants
            );
            if (!$ready) {
                // A concurrent request finished first; keep its files, drop ours.
                $storage->deletePrefix($prefix);
            }
            return true;
        } catch (MediaRejected $e) {
            // Decoded size out of bounds (checked before anything is stored).
            MediaRepository::markFailed($id);
            return false;
        } catch (\Throwable $e) {
            if ($stored) {
                $storage->deletePrefix($prefix);
            }
            MediaRepository::markFailed($id);
            throw $e;
        } finally {
            $storage->removeScratch($scratch);
        }
    }

    // ── GET /media/{mediaId}?size= ──────────────────────────────

    public static function link(Request $request): void
    {
        MediaSigner::secret();
        $userId = $request->userId();

        $size = $request->query('size', 'medium');
        if (!in_array($size, MediaRepository::SIZES, true)) {
            Response::validationError('size must be one of: thumb, medium, full.');
        }

        $asset = self::findViewable($request->param('mediaId'), $userId);
        $variant = $asset['variants'][$size] ?? null;
        if (!is_array($variant)) {
            self::mediaNotFound();
        }

        $expires = time() + MediaSigner::ttl();
        Response::ok([
            'url' => MediaSigner::path((string) $asset['id'], $size, $expires),
            'expires_at' => gmdate('Y-m-d H:i:s', $expires),
            'width' => (int) $variant['width'],
            'height' => (int) $variant['height'],
            'mime_type' => $asset['mime_type'],
        ]);
    }

    /**
     * Ready, not deleted, not hidden by moderation, in a group where the viewer
     * is an active member; unattached uploads are visible to their uploader only.
     * Everything else is the same 404.
     *
     * @return array<string, mixed>
     */
    private static function findViewable(string $rawId, int $userId): array
    {
        $id = Uuid::normalise($rawId);
        $asset = $id !== null ? MediaRepository::find($id) : null;
        if ($asset === null
            || $asset['status'] !== 'ready'
            || $asset['deleted_at'] !== null
            || $asset['hidden_at'] !== null
            || ($asset['attached_at'] === null && $asset['uploader_id'] !== $userId)
            || !MemberRepository::isActiveMember($asset['group_id'], $userId)
        ) {
            self::mediaNotFound();
        }
        return $asset;
    }

    // ── DELETE /media/{mediaId} ─────────────────────────────────

    public static function discard(Request $request): void
    {
        $userId = $request->userId();
        $id = Uuid::normalise($request->param('mediaId'));

        $asset = $id === null ? null : Database::transaction(static function () use ($id, $userId): array {
            $asset = MediaRepository::findForUpdate($id);
            if ($asset === null || $asset['uploader_id'] !== $userId || $asset['status'] === 'deleted') {
                self::mediaNotFound();
            }
            if ($asset['attached_at'] !== null) {
                Response::error('conflict', 'This photo is part of a Memory. Delete the Memory instead.', 409);
            }
            MediaRepository::markDeleted($id, false);
            return $asset;
        });
        if ($asset === null) {
            self::mediaNotFound();
        }

        if (is_string($asset['storage_key']) && $asset['storage_key'] !== '') {
            MediaServices::storage()->deletePrefix($asset['storage_key']);
        }
        MediaRepository::markDeleted((string) $asset['id'], true);

        Response::ok(null, 'Photo discarded.');
    }

    // ── GET /media/files/{mediaId}/{size}?expires&sig (no bearer) ─

    public static function file(Request $request): void
    {
        MediaSigner::secret();

        $id = Uuid::normalise($request->param('mediaId'));
        $size = $request->param('size');
        $expires = $request->query('expires');
        $sig = $request->query('sig');
        $now = time();

        if ($id === null || !MediaSigner::verify($id, $size, $expires, $sig, $now)) {
            Response::error('media_link_invalid', 'This photo link is invalid or has expired.', 403);
        }

        $asset = MediaRepository::find($id);
        $variant = $asset['variants'][$size] ?? null;
        if ($asset === null || $asset['status'] !== 'ready' || $asset['deleted_at'] !== null
            || $asset['hidden_at'] !== null || !is_array($variant) || !is_string($asset['storage_key'])
        ) {
            self::mediaNotFound();
        }

        $key = $asset['storage_key'] . '/' . $size . '.' . (string) ($variant['ext'] ?? 'webp');
        $storage = MediaServices::storage();
        $path = $storage->localPath($key);
        if ($path === null) {
            self::mediaNotFound();
        }

        $remaining = max(0, (int) $expires - $now);
        Response::header('Cache-Control', 'private, max-age=' . $remaining);
        Response::header('X-Content-Type-Options', 'nosniff');
        Response::header('Content-Disposition', 'inline');
        Response::header('Content-Security-Policy', "default-src 'none'; sandbox");
        Response::header('Cross-Origin-Resource-Policy', 'cross-origin');

        $offload = match (strtolower(Env::get('MEDIA_SENDFILE_MODE', 'none'))) {
            'x-sendfile' => ['X-Sendfile', $path],
            'x-accel-redirect' => ['X-Accel-Redirect', rtrim(Env::get('MEDIA_ACCEL_PREFIX', '/protected-media'), '/') . '/' . $key],
            default => null,
        };

        Response::file($path, (string) $asset['mime_type'], $offload);
    }
}
