<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\Log;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Media\ImageInspector;
use Circle\Media\ImageProcessingException;
use Circle\Media\MediaRejected;
use Circle\Media\MediaServices;
use Circle\Media\Uuid;

/** Account photos: authenticated bytes, distinct from exact-group Memory assets. */
final class ProfilePhotoController
{
    private const MAX_BYTES = 5 * 1024 * 1024;
    private const MAX_PIXELS = 4_194_304;
    private const SIZES = ['thumb' => 320, 'medium' => 1080, 'full' => 2048];

    private static function kind(Request $request): string
    {
        $kind = $request->param('kind');
        if (!in_array($kind, ['avatar', 'cover'], true)) {
            Response::notFound();
        }
        return $kind;
    }

    public static function put(Request $request): void
    {
        $kind = self::kind($request);
        $bytes = $request->readRawBody(self::MAX_BYTES);
        if ($bytes === null) {
            Response::error('media_too_large', 'Choose a photo smaller than 5 MB.', 413);
        }
        $mime = strtolower(trim(explode(';', $request->contentType)[0]));
        try {
            $dimensions = ImageInspector::inspect($bytes, $mime, ['image/jpeg', 'image/png', 'image/webp'], self::MAX_PIXELS);
            if (($dimensions['width'] ?? 0) > 2048 || ($dimensions['height'] ?? 0) > 2048) {
                throw new MediaRejected(422, 'media_invalid', 'Resize this photo to at most 2048 pixels per side.');
            }
        } catch (MediaRejected $e) {
            Response::error($e->errorCode, $e->getMessage(), $e->status);
        }
        $processor = MediaServices::processor();
        if ($processor === null || !$processor->supports($mime)) {
            Response::error('server_error', 'Photos cannot be processed on this server yet.', 503);
        }
        $storage = MediaServices::storage();
        $scratch = $storage->makeScratchDir();
        $prefix = 'media/profiles/' . $request->userId() . '/' . Uuid::v4();
        $version = basename($prefix);
        $committed = false;
        $oldPrefix = null;
        try {
            $source = $scratch . '/source';
            if (file_put_contents($source, $bytes) !== strlen($bytes)) {
                throw new \RuntimeException('Profile photo staging failed.');
            }
            unset($bytes);
            $image = $processor->process($source, $mime, self::SIZES, $scratch);
            if (!in_array($image->mimeType, ['image/webp', 'image/jpeg'], true)
                || !in_array($image->extension, ['webp', 'jpg', 'jpeg'], true)) {
                throw new \RuntimeException('Profile photo processor returned an invalid type.');
            }
            foreach (array_keys(self::SIZES) as $size) {
                if (!isset($image->variants[$size])) {
                    throw new \RuntimeException('Profile photo processor omitted a size.');
                }
                $storage->put($prefix . '/' . $size . '.' . $image->extension, $image->variants[$size]['path']);
            }
            $oldPrefix = Database::transaction(static function () use ($request, $kind, $prefix, $version, $image): ?string {
                // Serialise replacements/deletes, including when no photo exists yet.
                $user = Database::queryOne('SELECT id FROM users WHERE id = :id AND status = :s FOR UPDATE',
                    ['id' => $request->userId(), 's' => 'active']);
                if ($user === null) {
                    Response::notFound();
                }
                $old = Database::queryOne('SELECT storage_prefix FROM profile_photos WHERE user_id = :uid AND kind = :kind',
                    ['uid' => $request->userId(), 'kind' => $kind]);
                Database::execute('INSERT INTO profile_photos (user_id, kind, version, storage_prefix, mime_type, extension)
                    VALUES (:uid, :kind, :version, :prefix, :mime, :extension)
                    ON DUPLICATE KEY UPDATE version = VALUES(version), storage_prefix = VALUES(storage_prefix),
                        mime_type = VALUES(mime_type), extension = VALUES(extension)',
                    ['uid' => $request->userId(), 'kind' => $kind, 'version' => $version, 'prefix' => $prefix,
                        'mime' => $image->mimeType, 'extension' => $image->extension]);
                return $old !== null ? (string) $old['storage_prefix'] : null;
            });
            $committed = true;
        } catch (ImageProcessingException $e) {
            Log::exception('profile_photo', $e);
            Response::error('media_invalid', 'This photo could not be processed. Choose another photo.', 422);
        } finally {
            $storage->removeScratch($scratch);
            if (!$committed) {
                self::purge($prefix);
            }
        }
        if ($oldPrefix !== null) {
            self::purge($oldPrefix);
        }
        AuthController::me($request);
    }

    public static function delete(Request $request): void
    {
        $kind = self::kind($request);
        $prefix = Database::transaction(static function () use ($request, $kind): ?string {
            $active = Database::queryOne('SELECT id FROM users WHERE id = :id AND status = :s FOR UPDATE', ['id' => $request->userId(), 's' => 'active']);
            if ($active === null) {
                Response::notFound();
            }
            $old = Database::queryOne('SELECT storage_prefix FROM profile_photos WHERE user_id = :uid AND kind = :kind',
                ['uid' => $request->userId(), 'kind' => $kind]);
            Database::execute('DELETE FROM profile_photos WHERE user_id = :uid AND kind = :kind',
                ['uid' => $request->userId(), 'kind' => $kind]);
            return $old !== null ? (string) $old['storage_prefix'] : null;
        });
        if ($prefix !== null) {
            self::purge($prefix);
        }
        AuthController::me($request);
    }

    public static function show(Request $request): void
    {
        Response::header('Cache-Control', 'private, no-store');
        Response::header('X-Content-Type-Options', 'nosniff');
        $kind = self::kind($request);
        $rawTarget = $request->param('userId');
        $target = $rawTarget === '' ? $request->userId() : filter_var($rawTarget, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        if ($target === false) {
            Response::notFound();
        }
        $size = $request->query['size'] ?? 'medium';
        if (!is_string($size) || !isset(self::SIZES[$size])) {
            Response::validationError('Choose thumb, medium or full.');
        }
        $photo = Database::queryOne('SELECT p.storage_prefix, p.mime_type, p.extension FROM profile_photos p
            JOIN users u ON u.id = p.user_id AND u.status = :status WHERE p.user_id = :uid AND p.kind = :kind',
            ['status' => 'active', 'uid' => $target, 'kind' => $kind]);
        if ($photo === null) {
            Response::notFound();
        }
        if ($target !== $request->userId()) {
            $shared = Database::queryOne('SELECT a.group_id FROM group_members a JOIN group_members b ON b.group_id = a.group_id
                WHERE a.user_id = :viewer AND a.status = :as AND b.user_id = :target AND b.status = :bs LIMIT 1',
                ['viewer' => $request->userId(), 'as' => 'active', 'target' => $target, 'bs' => 'active']);
            if ($shared === null) {
                Response::notFound();
            }
        }
        $path = MediaServices::storage()->localPath((string) $photo['storage_prefix'] . '/' . $size . '.' . (string) $photo['extension']);
        if ($path === null) {
            Response::notFound();
        }
        Response::header('Cache-Control', 'private, no-store');
        Response::header('X-Content-Type-Options', 'nosniff');
        Response::header('Content-Security-Policy', "default-src 'none'; sandbox");
        Response::header('Cross-Origin-Resource-Policy', 'same-origin');
        Response::file($path, (string) $photo['mime_type']);
    }

    private static function purge(string $prefix): void
    {
        try {
            MediaServices::storage()->deletePrefix($prefix);
        } catch (\Throwable $e) {
            // A cleanup failure must not turn a committed replacement into a failed save.
            Log::exception('profile_photo_cleanup', $e);
        }
    }
}
