<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Media\MediaSigner;
use Circle\Tests\Support\ImageFixtures;

final class MediaLinkTest extends MediaTestCase
{
    /**
     * Owner + member in one group; the member shared a Memory with one photo.
     * @return array{owner: array{id: int, token: string, refresh: string, mobile: string}, member: array{id: int, token: string, refresh: string, mobile: string}, gid: int, media: string, memory: int}
     */
    private function sharedPhoto(): array
    {
        $owner = $this->user('Owner');
        $member = $this->user('Member');
        $gid = $this->createGroup($owner);
        $this->join($owner, $member, $gid);
        $media = $this->readyMedia($member, $gid, ImageFixtures::png(3000, 2000));
        $r = $this->memoryWithMedia($member, $gid, [$media], 'Beach day');
        self::assertSame(201, $r->status(), json_encode($r->json()) ?: '');
        return ['owner' => $owner, 'member' => $member, 'gid' => $gid, 'media' => $media, 'memory' => (int) $r->data()['id']];
    }

    public function testMemberGetsSignedLinkAndDownloadsBytes(): void
    {
        $s = $this->sharedPhoto();

        $r = $this->link($s['owner'], $s['media'], 'medium');
        self::assertSame(200, $r->status(), json_encode($r->json()) ?: '');
        $link = $r->data();
        self::assertMatchesRegularExpression(
            '#^/media/files/' . $s['media'] . '/medium\?expires=\d+&sig=[0-9a-f]{64}$#',
            $link['url']
        );
        self::assertSame(1080, $link['width']);
        self::assertSame(720, $link['height']);
        self::assertSame('image/webp', $link['mime_type']);
        $ttl = strtotime($link['expires_at'] . ' UTC') - time();
        self::assertGreaterThan(290, $ttl);
        self::assertLessThanOrEqual(300, $ttl);

        // Default size is medium; thumb works too.
        self::assertStringContainsString('/medium?', $this->request('GET', "/api/v1/media/{$s['media']}", [], $s['owner']['token'])->data()['url']);
        self::assertSame(320, $this->link($s['owner'], $s['media'], 'thumb')->data()['width']);

        // The signed link needs no bearer token.
        $file = $this->download($link['url']);
        self::assertSame(200, $file->status());
        self::assertSame('FAKE-WEBP medium 1080x720', $file->rawBody());
        self::assertSame('image/webp', $file->header('Content-Type'));
        self::assertSame((string) strlen('FAKE-WEBP medium 1080x720'), $file->header('Content-Length'));
        self::assertSame('nosniff', $file->header('X-Content-Type-Options'));
        self::assertSame('inline', $file->header('Content-Disposition'));
        self::assertMatchesRegularExpression('/^private, max-age=(29\d|300)$/', (string) $file->header('Cache-Control'));
    }

    public function testUppercaseIdAndInvalidSize(): void
    {
        $s = $this->sharedPhoto();
        self::assertSame(200, $this->link($s['owner'], strtoupper($s['media']))->status());
        $bad = $this->link($s['owner'], $s['media'], 'huge');
        self::assertSame(422, $bad->status());
        self::assertSame('validation_error', $bad->errorCode());
    }

    public function testOutsidersRemovedAndLeftMembersGetUniform404(): void
    {
        $s = $this->sharedPhoto();
        $outsider = $this->user();
        $leaver = $this->user();
        $this->join($s['owner'], $leaver, $s['gid']);
        self::assertSame(200, $this->link($leaver, $s['media'])->status());

        $unknown = $this->link($outsider, $this->uuid());
        self::assertSame(404, $unknown->status());
        $denied = $this->link($outsider, $s['media']);
        self::assertSame(404, $denied->status());
        self::assertSame($unknown->json(), $denied->json());

        $this->request('POST', "/api/v1/groups/{$s['gid']}/leave", [], $leaver['token']);
        self::assertSame(404, $this->link($leaver, $s['media'])->status());

        // Removal by an admin: access ends on the next link request.
        $rm = $this->request('DELETE', "/api/v1/groups/{$s['gid']}/members/{$s['member']['id']}", [], $s['owner']['token']);
        self::assertSame(200, $rm->status(), json_encode($rm->json()) ?: '');
        self::assertSame(404, $this->link($s['member'], $s['media'])->status());
        self::assertSame(404, $this->request('GET', '/api/v1/media/not-a-uuid', [], $s['owner']['token'])->status());
        self::assertSame(401, $this->request('GET', "/api/v1/media/{$s['media']}")->status());
    }

    public function testParentGroupAdminCannotSeeSubgroupMedia(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $root = $this->createGroup($owner, 'Batch 2009');
        $this->join($owner, $member, $root);
        $child = $this->createGroup($member, 'Hostel wing', $root, ['visibility' => 'hidden']);
        $media = $this->readyMedia($member, $child);
        self::assertSame(201, $this->memoryWithMedia($member, $child, [$media])->status());

        self::assertSame(200, $this->link($member, $media)->status());
        self::assertSame(404, $this->link($owner, $media)->status());
    }

    public function testUnattachedUploadVisibleOnlyToUploader(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $member, $gid);
        $media = $this->readyMedia($member, $gid);

        self::assertSame(200, $this->link($member, $media)->status());
        self::assertSame(404, $this->link($owner, $media)->status());

        $pendingId = $this->ticketId($member, $gid, ImageFixtures::png());
        self::assertSame(404, $this->link($member, $pendingId)->status());
    }

    public function testHiddenAndDeletedMediaAre404EvenWithAnIssuedLink(): void
    {
        $s = $this->sharedPhoto();
        $url = $this->link($s['owner'], $s['media'])->data()['url'];

        Database::execute('UPDATE media_assets SET hidden_at = NOW() WHERE id = :id', ['id' => $s['media']]);
        self::assertSame(404, $this->link($s['member'], $s['media'])->status());
        self::assertSame(404, $this->link($s['owner'], $s['media'])->status());
        self::assertSame(404, $this->download($url)->status());
        // Hidden media also disappears from the Memory.
        self::assertSame([], $this->request('GET', "/api/v1/memories/{$s['memory']}", [], $s['owner']['token'])->data()['media']);

        Database::execute('UPDATE media_assets SET hidden_at = NULL WHERE id = :id', ['id' => $s['media']]);
        self::assertSame(200, $this->download($url)->status());

        self::assertSame(200, $this->request('DELETE', "/api/v1/memories/{$s['memory']}", [], $s['member']['token'])->status());
        self::assertSame(404, $this->link($s['owner'], $s['media'])->status());
        self::assertSame(404, $this->download($url)->status());
    }

    public function testTamperedExpiredAndMismatchedSignaturesRejected(): void
    {
        $s = $this->sharedPhoto();
        $url = $this->link($s['owner'], $s['media'], 'thumb')->data()['url'];
        parse_str((string) parse_url($url, PHP_URL_QUERY), $q);
        $expires = (string) $q['expires'];
        $sig = (string) $q['sig'];
        $base = "/media/files/{$s['media']}";

        $cases = [
            'tampered sig' => "{$base}/thumb?expires={$expires}&sig=" . substr($sig, 0, -1) . ($sig[63] === '0' ? '1' : '0'),
            'longer expiry' => "{$base}/thumb?expires=" . ((int) $expires + 3600) . "&sig={$sig}",
            'other size' => "{$base}/full?expires={$expires}&sig={$sig}",
            'missing sig' => "{$base}/thumb?expires={$expires}",
            'missing expiry' => "{$base}/thumb?sig={$sig}",
            'upper-case sig' => "{$base}/thumb?expires={$expires}&sig=" . strtoupper($sig),
            'expired' => MediaSigner::path($s['media'], 'thumb', time() - 1),
        ];
        foreach ($cases as $name => $bad) {
            $r = $this->download($bad);
            self::assertSame(403, $r->status(), $name);
            self::assertSame('media_link_invalid', $r->errorCode(), $name);
        }

        // Another id with this id's signature.
        $other = $this->readyMedia($s['member'], $s['gid']);
        self::assertSame(403, $this->download("/media/files/{$other}/thumb?expires={$expires}&sig={$sig}")->status());
        // Unknown size is not a route.
        self::assertSame(404, $this->download("{$base}/original?expires={$expires}&sig={$sig}")->status());

        self::assertSame(200, $this->download($url)->status());
    }

    public function testSigningSecretGuard(): void
    {
        $s = $this->sharedPhoto();
        $url = $this->link($s['owner'], $s['media'])->data()['url'];
        $good = Env::get('MEDIA_SIGNING_SECRET');
        try {
            foreach (['', 'too-short', 'change-this-to-a-random-64-char-string-for-media', Env::get('JWT_SECRET')] as $bad) {
                Env::set('MEDIA_SIGNING_SECRET', $bad);
                foreach ([
                    $this->link($s['owner'], $s['media']),
                    $this->download($url),
                    $this->ticket($s['owner'], $s['gid'], ImageFixtures::png()),
                ] as $r) {
                    self::assertSame(500, $r->status());
                    self::assertSame('server_error', $r->errorCode());
                    self::assertStringNotContainsString('SECRET', (string) json_encode($r->json()));
                }
                // The rest of the API keeps working.
                self::assertSame(200, $this->request('GET', '/api/v1/health')->status());
            }
            // A link signed with a different secret never verifies.
            Env::set('MEDIA_SIGNING_SECRET', bin2hex(random_bytes(32)));
            self::assertSame(403, $this->download($url)->status());
        } finally {
            Env::set('MEDIA_SIGNING_SECRET', $good);
        }
        self::assertSame(200, $this->download($url)->status());
    }

    public function testOffloadModeSendsHeaderInsteadOfBytes(): void
    {
        $s = $this->sharedPhoto();
        $url = $this->link($s['owner'], $s['media'], 'full')->data()['url'];
        $prev = Env::get('MEDIA_SENDFILE_MODE');
        try {
            Env::set('MEDIA_SENDFILE_MODE', 'x-accel-redirect');
            $r = $this->download($url);
            self::assertSame(200, $r->status());
            self::assertSame('', $r->rawBody());
            self::assertMatchesRegularExpression('#^/protected-media/media/' . $s['gid'] . '/[0-9a-f-]{36}/full\.webp$#', (string) $r->header('X-Accel-Redirect'));

            Env::set('MEDIA_SENDFILE_MODE', 'x-sendfile');
            $r = $this->download($url);
            self::assertStringStartsWith(realpath($this->storageRoot()) . '/media/', (string) $r->header('X-Sendfile'));
        } finally {
            Env::set('MEDIA_SENDFILE_MODE', $prev);
        }
    }

    public function testDownloadIsRateLimitedPerIp(): void
    {
        $s = $this->sharedPhoto();
        $url = $this->link($s['owner'], $s['media'])->data()['url'];
        $prev = Env::get('RATE_LIMIT_PER_MINUTE');
        Env::set('RATE_LIMIT_PER_MINUTE', '1');
        try {
            Database::execute('DELETE FROM rate_limits');
            self::assertSame(200, $this->download($url)->status());
            self::assertSame(429, $this->download($url)->status());
        } finally {
            Env::set('RATE_LIMIT_PER_MINUTE', $prev);
        }
    }
}
