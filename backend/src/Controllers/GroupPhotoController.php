<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Repositories\MemberRepository;
use Circle\Core\Log;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Media\ImageInspector;
use Circle\Media\ImageProcessingException;
use Circle\Media\MediaRejected;
use Circle\Media\MediaServices;
use Circle\Media\Uuid;

/** Private group branding; exact members read, current admins may edit. */
final class GroupPhotoController
{
    private const MAX_BYTES = 5 * 1024 * 1024;
    private const MAX_PIXELS = 4_194_304;
    private const SIZES = ['thumb' => 320, 'medium' => 1080, 'full' => 2048];

    /** @param array<int, array<string, mixed>> $groups
     * @return array<int, array<string, mixed>> */
    public static function attachVersions(array $groups): array
    {
        if ($groups === []) return [];
        $params = []; $slots = [];
        foreach ($groups as $i => $group) { $params['g' . $i] = (int) $group['id']; $slots[] = ':g' . $i; }
        $photos = Database::query('SELECT group_id, kind, version FROM group_photos WHERE group_id IN (' . implode(',', $slots) . ')', $params);
        $versions = [];
        foreach ($photos as $photo) $versions[(int) $photo['group_id']][$photo['kind']] = $photo['version'];
        foreach ($groups as &$group) {
            $group['avatar_version'] = $versions[(int) $group['id']]['avatar'] ?? null;
            $group['cover_version'] = $versions[(int) $group['id']]['cover'] ?? null;
            $group['cover_path'] = null;
        }
        return $groups;
    }

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
        MemberRepository::requireAdmin((int) $request->param('id'), $request->userId());
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
        $prefix = 'media/group-photos/' . $request->param('id') . '/' . Uuid::v4();
        $version = basename($prefix);
        $committed = false;
        $oldPrefix = null;
        try {
            $source = $scratch . '/source';
            if (file_put_contents($source, $bytes) !== strlen($bytes)) {
                throw new \RuntimeException('Group photo staging failed.');
            }
            unset($bytes);
            $image = $processor->process($source, $mime, self::SIZES, $scratch);
            if (!in_array($image->mimeType, ['image/webp', 'image/jpeg'], true)
                || !in_array($image->extension, ['webp', 'jpg', 'jpeg'], true)) {
                throw new \RuntimeException('Group photo processor returned an invalid type.');
            }
            foreach (array_keys(self::SIZES) as $size) {
                if (!isset($image->variants[$size])) {
                    throw new \RuntimeException('Group photo processor omitted a size.');
                }
                $storage->put($prefix . '/' . $size . '.' . $image->extension, $image->variants[$size]['path']);
            }
            $oldPrefix = Database::transaction(static function () use ($request, $kind, $prefix, $version, $image): ?string {
                self::lockAdmin($request);
                $old = Database::queryOne('SELECT storage_prefix FROM group_photos WHERE group_id = :uid AND kind = :kind',
                    ['uid' => (int) $request->param('id'), 'kind' => $kind]);
                Database::execute('INSERT INTO group_photos (group_id, kind, version, storage_prefix, mime_type, extension)
                    VALUES (:uid, :kind, :version, :prefix, :mime, :extension)
                    ON DUPLICATE KEY UPDATE version = VALUES(version), storage_prefix = VALUES(storage_prefix),
                        mime_type = VALUES(mime_type), extension = VALUES(extension)',
                    ['uid' => (int) $request->param('id'), 'kind' => $kind, 'version' => $version, 'prefix' => $prefix,
                        'mime' => $image->mimeType, 'extension' => $image->extension]);
                return $old !== null ? (string) $old['storage_prefix'] : null;
            });
            $committed = true;
        } catch (ImageProcessingException $e) {
            Log::exception('group_photo', $e);
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
        GroupController::show($request);
    }

    public static function delete(Request $request): void
    {
        $kind = self::kind($request);
        $prefix = Database::transaction(static function () use ($request, $kind): ?string {
            self::lockAdmin($request);
            $old = Database::queryOne('SELECT storage_prefix FROM group_photos WHERE group_id = :uid AND kind = :kind',
                ['uid' => (int) $request->param('id'), 'kind' => $kind]);
            Database::execute('DELETE FROM group_photos WHERE group_id = :uid AND kind = :kind',
                ['uid' => (int) $request->param('id'), 'kind' => $kind]);
            return $old !== null ? (string) $old['storage_prefix'] : null;
        });
        if ($prefix !== null) {
            self::purge($prefix);
        }
        GroupController::show($request);
    }

    public static function show(Request $request): void
    {
        Response::header('Cache-Control', 'private, no-store');
        Response::header('X-Content-Type-Options', 'nosniff');
        $kind = self::kind($request);
        $target = (int) $request->param('id');
        if (!MemberRepository::isActiveMember($target, $request->userId())) Response::notFound();
        $size = $request->query['size'] ?? 'medium';
        if (!is_string($size) || !isset(self::SIZES[$size])) {
            Response::validationError('Choose thumb, medium or full.');
        }
        $photo = Database::queryOne('SELECT storage_prefix, mime_type, extension FROM group_photos WHERE group_id = :gid AND kind = :kind', ['gid' => $target, 'kind' => $kind]);
        if ($photo === null) Response::notFound();
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

    private static function lockAdmin(Request $request): void
    {
        $gid = (int) $request->param('id');
        $group = Database::queryOne('SELECT id FROM `groups` WHERE id = :id FOR UPDATE', ['id' => $gid]);
        if ($group === null) Response::forbidden('You are not a member of this group.', 'not_member');
        $user = Database::queryOne("SELECT status FROM users WHERE id = :id FOR UPDATE", ['id' => $request->userId()]);
        if ($user === null || $user['status'] !== 'active') Response::forbidden('This account is not active.', 'account_inactive');
        $session = Database::queryOne('SELECT id FROM refresh_tokens WHERE user_id = :uid AND session_id = :sid AND revoked_at IS NULL AND expires_at > NOW() FOR UPDATE', ['uid' => $request->userId(), 'sid' => $request->attr('session_id')]);
        if ($session === null) Response::unauthorized('This session ended.', 'invalid_token');
        $member = Database::queryOne('SELECT role, status FROM group_members WHERE group_id = :gid AND user_id = :uid FOR UPDATE', ['gid' => $gid, 'uid' => $request->userId()]);
        if ($member === null || $member['status'] !== 'active') Response::forbidden('You are not a member of this group.', 'not_member');
        if ($member['role'] !== 'admin') Response::forbidden('Admin access required.');
    }

    private static function purge(string $prefix): void
    {
        try {
            MediaServices::storage()->deletePrefix($prefix);
        } catch (\Throwable $e) {
            // A cleanup failure must not turn a committed replacement into a failed save.
            Log::exception('group_photo_cleanup', $e);
        }
    }
}
