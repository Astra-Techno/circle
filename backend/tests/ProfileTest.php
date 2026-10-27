<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Core\Database;
use Circle\Media\ImageProcessingException;
use Circle\Media\MediaServices;
use Circle\Media\GdImageProcessor;
use Circle\Media\MediaStorage;
use Circle\Tests\Support\ImageFixtures;

final class ProfileTest extends MediaTestCase
{
    private function addMember(int $group, int $user): void
    {
        Database::execute("INSERT INTO group_members (group_id, user_id, role, status) VALUES (:g, :u, 'member', 'active')", ['g' => $group, 'u' => $user]);
    }

    public function testPersonalDetailsAreValidatedClearedAndNotExposedToMembers(): void
    {
        $owner = $this->user('Fictional Owner');
        $member = $this->user('Fictional Member');
        $group = $this->createGroup($owner);
        $this->addMember($group, $member['id']);
        $details = ['display_name' => 'Fictional Updated', 'about' => 'A shared fictional bio',
            'current_city' => 'சென்னை', 'hometown' => 'Fictional town', 'work' => 'Fictional studio', 'education' => 'Fictional school'];
        $updated = $this->request('PATCH', '/api/v1/me', $details, $owner['token']);
        self::assertSame(200, $updated->status());
        foreach ($details as $field => $value) {
            self::assertSame($value, $updated->data()[$field]);
        }
        self::assertNull($updated->data()['avatar_version']);
        self::assertNull($updated->data()['avatar_path']);
        $members = $this->request('GET', "/api/v1/groups/$group/members", [], $member['token']);
        self::assertSame(200, $members->status());
        self::assertStringNotContainsString('current_city', json_encode($members->json(), JSON_THROW_ON_ERROR));
        foreach (['current_city' => [], 'hometown' => 4, 'work' => str_repeat('a', 101),
            'education' => str_repeat('😀', 151), 'display_name' => '', 'about' => null] as $field => $value) {
            $bad = $this->request('PATCH', '/api/v1/me', [$field => $value], $owner['token']);
            self::assertSame(422, $bad->status(), $field);
        }
        self::assertSame('Fictional studio', $this->request('GET', '/api/v1/me', [], $owner['token'])->data()['work']);
        $cleared = $this->request('PATCH', '/api/v1/me', ['current_city' => '', 'hometown' => '', 'work' => '', 'education' => ''], $owner['token']);
        self::assertSame('', $cleared->data()['work']);
    }

    public function testPhotosReplaceRemoveAndRequireSharedActiveExactMembership(): void
    {
        $owner = $this->user('Fictional Owner');
        $member = $this->user('Fictional Member');
        $stranger = $this->user('Fictional Stranger');
        $root = $this->createGroup($stranger);
        $child = $this->createGroup($stranger, 'Fictional child', $root);
        $this->addMember($child, $owner['id']);
        $this->addMember($child, $member['id']);
        // Parent-only membership does not grant access to a global profile.
        Database::execute('UPDATE group_members SET status = :s WHERE group_id = :gid AND user_id = :uid',
            ['s' => 'left', 'gid' => $child, 'uid' => $stranger['id']]);
        foreach (['avatar', 'cover'] as $kind) {
            $upload = $this->requestRaw('PUT', "/api/v1/me/photos/$kind", ImageFixtures::png(), $owner['token'], 'image/png');
            self::assertSame(200, $upload->status(), json_encode($upload->json()) ?: '');
            self::assertMatchesRegularExpression('/^[0-9a-f-]{36}$/', $upload->data()[$kind . '_version']);
            self::assertNull($upload->data()['avatar_path']);
            self::assertStringNotContainsString('storage_prefix', json_encode($upload->json(), JSON_THROW_ON_ERROR));
            foreach (['thumb', 'medium', 'full'] as $size) {
                $read = $this->request('GET', "/api/v1/me/photos/$kind?size=$size", [], $owner['token']);
                self::assertSame(200, $read->status());
                self::assertSame('private, no-store', $read->header('Cache-Control'));
                self::assertSame('nosniff', $read->header('X-Content-Type-Options'));
                self::assertStringContainsString('FAKE-WEBP', $read->rawBody() ?? '');
            }
            $path = "/api/v1/profiles/{$owner['id']}/photos/$kind";
            self::assertSame(401, $this->request('GET', $path)->status());
            self::assertSame(200, $this->request('GET', $path, [], $member['token'])->status());
            self::assertSame(404, $this->request('GET', $path, [], $stranger['token'])->status());
        }
        self::assertCount(6, $this->storedFiles());
        $before = $this->request('GET', '/api/v1/me', [], $owner['token'])->data()['avatar_version'];
        $replaced = $this->requestRaw('PUT', '/api/v1/me/photos/avatar', ImageFixtures::png(), $owner['token'], 'image/png');
        self::assertNotSame($before, $replaced->data()['avatar_version']);
        self::assertCount(6, $this->storedFiles(), 'Old variants purged on replacement');
        Database::execute('UPDATE group_members SET status = :s WHERE group_id = :gid AND user_id = :uid',
            ['s' => 'removed', 'gid' => $child, 'uid' => $member['id']]);
        self::assertSame(404, $this->request('GET', "/api/v1/profiles/{$owner['id']}/photos/avatar", [], $member['token'])->status());
        foreach (['avatar', 'cover'] as $kind) {
            $deleted = $this->request('DELETE', "/api/v1/me/photos/$kind", [], $owner['token']);
            self::assertSame(200, $deleted->status());
            self::assertNull($deleted->data()[$kind . '_version']);
            self::assertSame(404, $this->request('GET', "/api/v1/me/photos/$kind", [], $owner['token'])->status());
            self::assertSame(200, $this->request('DELETE', "/api/v1/me/photos/$kind", [], $owner['token'])->status());
        }
        self::assertCount(0, $this->storedFiles());
    }

    public function testInvalidUploadsAndProcessorFailuresKeepPreviousPhoto(): void
    {
        $owner = $this->user('Fictional Owner');
        $first = $this->requestRaw('PUT', '/api/v1/me/photos/avatar', ImageFixtures::png(), $owner['token'], 'image/png');
        self::assertSame(200, $first->status());
        foreach ([['nonsense', 'image/png', 415], [ImageFixtures::png(), 'image/jpeg', 422],
            [str_repeat('x', 5 * 1024 * 1024 + 1), 'image/png', 413],
            [ImageFixtures::png(2049, 1), 'image/png', 422],
            [ImageFixtures::png(2048, 2049), 'image/png', 422]] as [$bytes, $mime, $status]) {
            self::assertSame($status, $this->requestRaw('PUT', '/api/v1/me/photos/avatar', $bytes, $owner['token'], $mime)->status());
        }
        $this->processor->failWith = new ImageProcessingException('Synthetic processor failure');
        self::assertSame(422, $this->requestRaw('PUT', '/api/v1/me/photos/avatar', ImageFixtures::png(), $owner['token'], 'image/png')->status());
        MediaServices::setProcessor(null);
        self::assertSame(503, $this->requestRaw('PUT', '/api/v1/me/photos/avatar', ImageFixtures::png(), $owner['token'], 'image/png')->status());
        self::assertSame($first->data()['avatar_version'], $this->request('GET', '/api/v1/me', [], $owner['token'])->data()['avatar_version']);
        self::assertCount(3, $this->storedFiles());
        self::assertSame(422, $this->request('GET', '/api/v1/me/photos/avatar?size=invalid', [], $owner['token'])->status());
        self::assertSame(422, $this->request('GET', '/api/v1/me/photos/avatar?size[]=thumb', [], $owner['token'])->status());
        self::assertSame(404, $this->request('GET', '/api/v1/me/photos/invalid', [], $owner['token'])->status());
        self::assertSame(404, $this->request('GET', '/api/v1/profiles/nope/photos/avatar', [], $owner['token'])->status());
        Database::execute('UPDATE users SET status = :s WHERE id = :id', ['s' => 'suspended', 'id' => $owner['id']]);
        self::assertSame(403, $this->request('GET', '/api/v1/me/photos/avatar', [], $owner['token'])->status());
    }
    public function testPartialStorageFailureDoesNotReplaceExistingPhoto(): void
    {
        $owner = $this->user('Fictional Owner');
        $first = $this->requestRaw('PUT', '/api/v1/me/photos/avatar', ImageFixtures::png(), $owner['token'], 'image/png');
        self::assertSame(200, $first->status());
        $storage = new class(MediaServices::storage()) implements MediaStorage {
            private int $writes = 0;
            public function __construct(private readonly MediaStorage $inner) {}
            public function put(string $key, string $sourcePath): void {
                if (++$this->writes === 2) { throw new \RuntimeException('Synthetic write failure'); }
                $this->inner->put($key, $sourcePath);
            }
            public function exists(string $key): bool { return $this->inner->exists($key); }
            public function deletePrefix(string $prefix): void { $this->inner->deletePrefix($prefix); }
            public function localPath(string $key): ?string { return $this->inner->localPath($key); }
            public function makeScratchDir(): string { return $this->inner->makeScratchDir(); }
            public function removeScratch(string $dir): void { $this->inner->removeScratch($dir); }
        };
        MediaServices::setStorage($storage);
        self::assertSame(500, $this->requestRaw('PUT', '/api/v1/me/photos/avatar', ImageFixtures::png(), $owner['token'], 'image/png')->status());
        self::assertSame($first->data()['avatar_version'], $this->request('GET', '/api/v1/me', [], $owner['token'])->data()['avatar_version']);
        self::assertSame(200, $this->request('GET', '/api/v1/me/photos/avatar', [], $owner['token'])->status());
        self::assertCount(3, $this->storedFiles(true), 'Staged objects and scratch removed; original variants retained');
    }

    public function testRealProfileImageReencodingStripsMetadataAndResizes(): void
    {
        if (!GdImageProcessor::isAvailable()) {
            self::markTestSkipped('ext-gd is required for actual profile image reencoding.');
        }
        MediaServices::setProcessor(new GdImageProcessor());
        $owner = $this->user('Fictional Owner');
        $input = ImageFixtures::png(1400, 700);
        self::assertSame(401, $this->requestRaw('PUT', '/api/v1/me/photos/cover', $input, null, 'image/png')->status());
        self::assertSame(200, $this->requestRaw('PUT', '/api/v1/me/photos/cover', $input, $owner['token'], 'image/png')->status());
        foreach (['thumb' => [320, 160], 'medium' => [1080, 540], 'full' => [1400, 700]] as $size => $expected) {
            $result = $this->request('GET', '/api/v1/me/photos/cover?size=' . $size, [], $owner['token']);
            self::assertSame(200, $result->status());
            $bytes = $result->rawBody() ?? '';
            self::assertStringNotContainsString(ImageFixtures::GPS_MARKER, $bytes);
            $dimensions = getimagesizefromstring($bytes);
            self::assertNotFalse($dimensions);
            self::assertSame($expected, [$dimensions[0], $dimensions[1]]);
        }
    }

    public function testMemberAvatarRevisionTracksReplacementAndRemovalWithoutPrivatePaths(): void
    {
        $owner = $this->user('Fictional Owner'); $viewer = $this->user('Fictional Viewer'); $stranger = $this->user('Fictional Stranger');
        $group = $this->createGroup($owner); $this->addMember($group, $viewer['id']);
        $read = fn (): mixed => array_values(array_filter($this->request('GET', "/api/v1/groups/$group/members", [], $viewer['token'])->data(), static fn (array $r): bool => $r['id'] === $owner['id']))[0];
        self::assertNull($read()['avatar_version']);
        $first = $this->requestRaw('PUT', '/api/v1/me/photos/avatar', ImageFixtures::png(), $owner['token'], 'image/png')->data()['avatar_version'];
        self::assertSame($first, $read()['avatar_version']); self::assertNull($read()['avatar_path']);
        $next = $this->requestRaw('PUT', '/api/v1/me/photos/avatar', ImageFixtures::png(), $owner['token'], 'image/png')->data()['avatar_version'];
        self::assertNotSame($first, $next); self::assertSame($next, $read()['avatar_version']);
        self::assertSame(403, $this->request('GET', "/api/v1/groups/$group/members", [], $stranger['token'])->status());
        $this->request('DELETE', '/api/v1/me/photos/avatar', [], $owner['token']); self::assertNull($read()['avatar_version']);
    }
    public function testPhotoReadBudgetIsSeparateBoundedAndRequiresAuthentication(): void
    {
        $owner = $this->user();
        $this->requestRaw('PUT', '/api/v1/me/photos/avatar', ImageFixtures::png(), $owner['token'], 'image/png');
        \Circle\Core\Env::set('RATE_LIMIT_PROFILE_PHOTOS_PER_MINUTE', '2');
        try {
            self::assertSame(401, $this->request('GET', '/api/v1/me/photos/avatar')->status());
            for ($i = 0; $i < 2; $i++) self::assertSame(200, $this->request('GET', '/api/v1/me/photos/avatar', [], $owner['token'])->status());
            self::assertSame(429, $this->request('GET', '/api/v1/me/photos/avatar', [], $owner['token'])->status());
            self::assertSame(200, $this->request('GET', '/api/v1/me', [], $owner['token'])->status());
        } finally { \Circle\Core\Env::set('RATE_LIMIT_PROFILE_PHOTOS_PER_MINUTE', '240'); }
    }

}
