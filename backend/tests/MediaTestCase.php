<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Media\MediaServices;
use Circle\Tests\Support\FakeImageProcessor;
use Circle\Tests\Support\ImageFixtures;

/**
 * Media tests run with FakeImageProcessor (no ext-gd here) and a throwaway
 * storage folder that is emptied before every test.
 */
abstract class MediaTestCase extends ApiTestCase
{
    protected FakeImageProcessor $processor;

    protected function setUp(): void
    {
        parent::setUp();
        $this->processor = new FakeImageProcessor();
        MediaServices::reset();
        MediaServices::setProcessor($this->processor);
        $this->emptyStorage();
    }

    protected function tearDown(): void
    {
        MediaServices::reset();
        parent::tearDown();
    }

    protected function storageRoot(): string
    {
        return Env::get('MEDIA_STORAGE_PATH');
    }

    private function emptyStorage(): void
    {
        foreach ($this->storedFiles(true) as $path) {
            @unlink($path);
        }
    }

    /** @return string[] absolute paths of every file in storage (optionally incl. scratch) */
    protected function storedFiles(bool $includeScratch = false): array
    {
        $root = $this->storageRoot();
        if (!is_dir($root)) {
            return [];
        }
        $out = [];
        $it = new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator($root, \FilesystemIterator::SKIP_DOTS));
        foreach ($it as $file) {
            /** @var \SplFileInfo $file */
            $path = $file->getPathname();
            if ($file->isFile() && ($includeScratch || !str_contains($path, '/.scratch/'))) {
                $out[] = $path;
            }
        }
        sort($out);
        return $out;
    }

    /** @return string[] */
    protected function filesFor(string $mediaId): array
    {
        $row = Database::queryOne('SELECT storage_key FROM media_assets WHERE id = :id', ['id' => $mediaId]);
        $key = $row['storage_key'] ?? null;
        if (!is_string($key)) {
            return [];
        }
        $dir = $this->storageRoot() . '/' . $key;
        return is_dir($dir) ? array_values(array_diff(scandir($dir) ?: [], ['.', '..'])) : [];
    }

    protected function uuid(): string
    {
        return \Circle\Media\Uuid::v4();
    }

    /**
     * @param array{token: string} $user
     * @param array<string, mixed> $override
     */
    protected function ticket(array $user, int $groupId, string $bytes, string $mime = 'image/png', array $override = []): TestResponse
    {
        return $this->request('POST', "/api/v1/groups/{$groupId}/media/uploads", [
            'client_upload_id' => $this->uuid(),
            'mime_type' => $mime,
            'byte_size' => strlen($bytes),
            'sha256' => hash('sha256', $bytes),
            ...$override,
        ], $user['token']);
    }

    /** @param array{token: string} $user */
    protected function ticketId(array $user, int $groupId, string $bytes, string $mime = 'image/png'): string
    {
        $r = $this->ticket($user, $groupId, $bytes, $mime);
        self::assertSame(201, $r->status(), json_encode($r->json()) ?: '');
        return (string) $r->data()['upload_id'];
    }

    /** @param array{token: string} $user */
    protected function putContent(array $user, string $uploadId, string $bytes, string $mime = 'image/png'): TestResponse
    {
        return $this->requestRaw('PUT', "/api/v1/media/uploads/{$uploadId}/content", $bytes, $user['token'], $mime);
    }

    /**
     * Uploads a photo end to end and returns its media id.
     * @param array{token: string} $user
     */
    protected function readyMedia(array $user, int $groupId, ?string $bytes = null): string
    {
        $bytes ??= ImageFixtures::png();
        $id = $this->ticketId($user, $groupId, $bytes);
        $r = $this->putContent($user, $id, $bytes);
        self::assertSame(200, $r->status(), json_encode($r->json()) ?: '');
        self::assertSame('ready', $r->data()['status']);
        return $id;
    }

    /**
     * @param array{token: string} $user
     * @param string[] $mediaIds
     */
    protected function memoryWithMedia(array $user, int $groupId, array $mediaIds, string $body = ''): TestResponse
    {
        return $this->request('POST', "/api/v1/groups/{$groupId}/memories", ['body' => $body, 'media_ids' => $mediaIds], $user['token']);
    }

    /** @param array{token: string} $user */
    protected function link(array $user, string $mediaId, string $size = 'medium'): TestResponse
    {
        return $this->request('GET', "/api/v1/media/{$mediaId}?size={$size}", [], $user['token']);
    }

    /** Downloads a signed relative url (no bearer token). */
    protected function download(string $url): TestResponse
    {
        return $this->request('GET', '/api/v1' . $url);
    }
}
