<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Media\ImageProcessingException;
use Circle\Media\MediaServices;
use Circle\Tests\Support\ImageFixtures;

final class MediaUploadTest extends MediaTestCase
{
    // ── Tickets ─────────────────────────────────────────────────

    public function testTicketForMemberOfExactGroup(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $png = ImageFixtures::png();

        $r = $this->ticket($owner, $gid, $png);
        self::assertSame(201, $r->status(), json_encode($r->json()) ?: '');
        $t = $r->data();
        self::assertMatchesRegularExpression('/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/', $t['upload_id']);
        self::assertSame('/media/uploads/' . $t['upload_id'] . '/content', $t['upload_path']);
        self::assertSame(strlen($png), $t['max_bytes']);
        self::assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/', $t['expires_at']);
        $ttl = strtotime($t['expires_at'] . ' UTC') - time();
        self::assertGreaterThan(800, $ttl);
        self::assertLessThanOrEqual(900, $ttl);
        self::assertSame(['expires_at', 'max_bytes', 'upload_id', 'upload_path'], self::sortedKeys($t));
    }

    public function testTicketDeniedToNonMembersAndParentAdmins(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $outsider = $this->user();
        $root = $this->createGroup($owner, 'Root');
        $this->join($owner, $member, $root);
        $child = $this->createGroup($member, 'Child', $root);
        $png = ImageFixtures::png();

        $r = $this->ticket($outsider, $root, $png);
        self::assertSame(403, $r->status());
        self::assertSame('not_member', $r->errorCode());
        // Parent owner/admin is not a member of the child group.
        self::assertSame('not_member', $this->ticket($owner, $child, $png)->errorCode());
        // Unknown group looks the same.
        self::assertSame('not_member', $this->ticket($owner, 999999, $png)->errorCode());
        self::assertSame(401, $this->request('POST', "/api/v1/groups/{$root}/media/uploads", [])->status());
        self::assertSame(0, $this->countAssets());
    }

    public function testTicketValidationAndLimits(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $png = ImageFixtures::png();

        self::assertSame('validation_error', $this->ticket($owner, $gid, $png, 'image/png', ['client_upload_id' => 'nope'])->errorCode());
        self::assertSame('validation_error', $this->ticket($owner, $gid, $png, 'image/png', ['mime_type' => ''])->errorCode());
        self::assertSame('validation_error', $this->ticket($owner, $gid, $png, 'image/png', ['byte_size' => 0])->errorCode());
        self::assertSame('validation_error', $this->ticket($owner, $gid, $png, 'image/png', ['byte_size' => '100'])->errorCode());
        self::assertSame('validation_error', $this->ticket($owner, $gid, $png, 'image/png', ['sha256' => 'abc'])->errorCode());

        $gif = $this->ticket($owner, $gid, $png, 'image/gif');
        self::assertSame(415, $gif->status());
        self::assertSame('media_type_not_allowed', $gif->errorCode());
        // GD cannot decode HEIC: refused unless the processor supports it.
        self::assertSame('media_type_not_allowed', $this->ticket($owner, $gid, ImageFixtures::heicHeader(), 'image/heic')->errorCode());
        $this->processor->heic = true;
        self::assertSame(201, $this->ticket($owner, $gid, ImageFixtures::heicHeader(), 'image/heic')->status());

        $big = $this->ticket($owner, $gid, $png, 'image/png', ['byte_size' => 15 * 1024 * 1024 + 1]);
        self::assertSame(413, $big->status());
        self::assertSame('media_too_large', $big->errorCode());
        self::assertSame(201, $this->ticket($owner, $gid, $png, 'image/png', ['byte_size' => 15 * 1024 * 1024])->status());
        // Upper-case UUID and hash are normalised.
        self::assertSame(201, $this->ticket($owner, $gid, $png, 'image/png', ['client_upload_id' => strtoupper($this->uuid()), 'sha256' => strtoupper(hash('sha256', $png))])->status());
    }

    public function testTicketIsIdempotentPerClientUploadId(): void
    {
        $owner = $this->user();
        $other = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $other, $gid);
        $png = ImageFixtures::png();
        $cid = $this->uuid();

        $a = $this->ticket($owner, $gid, $png, 'image/png', ['client_upload_id' => $cid]);
        $b = $this->ticket($owner, $gid, $png, 'image/png', ['client_upload_id' => $cid]);
        self::assertSame(201, $b->status());
        self::assertSame($a->data(), $b->data());
        self::assertSame(1, $this->countAssets());

        // Same id, different content → conflict; another person may reuse the id.
        $c = $this->ticket($owner, $gid, $png, 'image/png', ['client_upload_id' => $cid, 'sha256' => str_repeat('a', 64)]);
        self::assertSame(409, $c->status());
        self::assertSame('conflict', $c->errorCode());
        self::assertSame(201, $this->ticket($other, $gid, $png, 'image/png', ['client_upload_id' => $cid])->status());
        self::assertSame(2, $this->countAssets());
    }

    public function testPerUserTicketRateLimit(): void
    {
        $owner = $this->user();
        $other = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $other, $gid);
        $png = ImageFixtures::png();
        $cid = $this->uuid();

        $prev = Env::get('MEDIA_UPLOADS_PER_HOUR');
        Env::set('MEDIA_UPLOADS_PER_HOUR', '2');
        try {
            self::assertSame(201, $this->ticket($owner, $gid, $png, 'image/png', ['client_upload_id' => $cid])->status());
            self::assertSame(201, $this->ticket($owner, $gid, $png)->status());
            $r = $this->ticket($owner, $gid, $png);
            self::assertSame(429, $r->status());
            self::assertSame('rate_limited', $r->errorCode());
            self::assertSame('3600', $r->header('Retry-After'));
            // Replays are free; other people are unaffected.
            self::assertSame(201, $this->ticket($owner, $gid, $png, 'image/png', ['client_upload_id' => $cid])->status());
            self::assertSame(201, $this->ticket($other, $gid, $png)->status());
        } finally {
            Env::set('MEDIA_UPLOADS_PER_HOUR', $prev);
        }
    }

    public function testOpenUploadsCap(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $png = ImageFixtures::png();

        $prev = Env::get('MEDIA_MAX_OPEN_UPLOADS');
        Env::set('MEDIA_MAX_OPEN_UPLOADS', '2');
        try {
            $first = $this->ticketId($owner, $gid, $png);
            $this->ticketId($owner, $gid, $png);
            $r = $this->ticket($owner, $gid, $png);
            self::assertSame(422, $r->status());
            self::assertSame('media_limit_reached', $r->errorCode());

            self::assertSame(200, $this->request('DELETE', "/api/v1/media/{$first}", [], $owner['token'])->status());
            self::assertSame(201, $this->ticket($owner, $gid, $png)->status());
        } finally {
            Env::set('MEDIA_MAX_OPEN_UPLOADS', $prev);
        }
    }

    // ── Content ─────────────────────────────────────────────────

    public function testUploadProcessesAndNeverStoresTheOriginal(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $png = ImageFixtures::png(4000, 3000);
        $id = $this->ticketId($owner, $gid, $png);

        $r = $this->putContent($owner, $id, $png);
        self::assertSame(200, $r->status(), json_encode($r->json()) ?: '');
        $asset = $r->data();
        self::assertSame($id, $asset['id']);
        self::assertSame($gid, $asset['group_id']);
        self::assertSame($owner['id'], $asset['uploader_id']);
        self::assertSame('image', $asset['kind']);
        self::assertSame('image/webp', $asset['mime_type']);
        self::assertSame(4000, $asset['width']);
        self::assertSame(3000, $asset['height']);
        self::assertSame('ready', $asset['status']);
        self::assertSame(['thumb', 'medium', 'full'], $asset['sizes']);
        self::assertSame(
            ['byte_size', 'created_at', 'group_id', 'height', 'id', 'kind', 'mime_type', 'sizes', 'status', 'uploader_id', 'width'],
            self::sortedKeys($asset)
        );
        $json = (string) json_encode($r->json());
        self::assertStringNotContainsString('media\/', $json);
        self::assertStringNotContainsString('storage', $json);

        // Three re-encoded variants; the original (and its metadata) is gone.
        self::assertSame(['full.webp', 'medium.webp', 'thumb.webp'], $this->filesFor($id));
        $all = $this->storedFiles(true);
        self::assertCount(3, $all);
        foreach ($all as $path) {
            $content = (string) file_get_contents($path);
            self::assertStringNotContainsString(ImageFixtures::GPS_MARKER, $content);
            self::assertNotSame($png, $content);
            self::assertSame(0600, fileperms($path) & 0777);
        }
        $variants = json_decode((string) Database::queryOne('SELECT variants FROM media_assets WHERE id = :id', ['id' => $id])['variants'], true);
        self::assertSame([2048, 1536], [$variants['full']['width'], $variants['full']['height']]);
        self::assertSame([1080, 810], [$variants['medium']['width'], $variants['medium']['height']]);
        self::assertSame([320, 240], [$variants['thumb']['width'], $variants['thumb']['height']]);

        // Idempotent: sending again returns the ready asset without reprocessing.
        $again = $this->putContent($owner, $id, $png);
        self::assertSame(200, $again->status());
        self::assertSame($asset, $again->data());
        self::assertSame(1, $this->processor->calls);
    }

    public function testJpegAndWebpAccepted(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        foreach (['image/jpeg' => ImageFixtures::jpegHeader(), 'image/webp' => ImageFixtures::webpHeader()] as $mime => $bytes) {
            $id = $this->ticketId($owner, $gid, $bytes, $mime);
            $r = $this->putContent($owner, $id, $bytes, $mime);
            self::assertSame(200, $r->status(), $mime . ' ' . json_encode($r->json()));
        }
    }

    public function testOnlyTheTicketOwnerWhileStillAMember(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $member, $gid);
        $png = ImageFixtures::png();

        $id = $this->ticketId($member, $gid, $png);
        self::assertSame(404, $this->putContent($owner, $id, $png)->status());
        self::assertSame(404, $this->putContent($owner, $this->uuid(), $png)->status());
        self::assertSame(401, $this->requestRaw('PUT', "/api/v1/media/uploads/{$id}/content", $png)->status());

        // After leaving the group the ticket no longer works.
        $this->request('POST', "/api/v1/groups/{$gid}/leave", [], $member['token']);
        self::assertSame(404, $this->putContent($member, $id, $png)->status());
        self::assertSame(0, $this->processor->calls);
    }

    public function testExpiredTicket(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $png = ImageFixtures::png();
        $id = $this->ticketId($owner, $gid, $png);
        Database::execute('UPDATE media_assets SET ticket_expires_at = DATE_SUB(NOW(), INTERVAL 1 SECOND) WHERE id = :id', ['id' => $id]);

        $r = $this->putContent($owner, $id, $png);
        self::assertSame(410, $r->status());
        self::assertSame('upload_expired', $r->errorCode());
    }

    public function testChecksumSizeAndBodyLimit(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $png = ImageFixtures::png();
        $id = $this->ticketId($owner, $gid, $png);

        $other = ImageFixtures::png(41, 30);
        $wrongSha = $this->putContent($owner, $id, substr($other, 0, strlen($png)));
        self::assertSame(422, $wrongSha->status());
        self::assertSame('media_invalid', $wrongSha->errorCode());
        self::assertSame('media_invalid', $this->putContent($owner, $id, substr($png, 0, -1))->errorCode());
        self::assertSame('media_invalid', $this->putContent($owner, $id, '')->errorCode());

        $tooBig = $this->putContent($owner, $id, $png . str_repeat("\x00", 2048));
        self::assertSame(413, $tooBig->status());
        self::assertSame('media_too_large', $tooBig->errorCode());

        // Still pending and usable with the right bytes.
        self::assertSame(200, $this->putContent($owner, $id, $png)->status());
    }

    public function testDisguisedFilesAreRejectedByRealContent(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);

        $cases = [
            ['<?php system($_GET["c"]); ?>', 'image/jpeg', 415, 'media_type_not_allowed'],
            ["<!DOCTYPE html><html><script>alert(1)</script></html>", 'image/png', 415, 'media_type_not_allowed'],
            ["GIF89a\x01\x00\x01\x00\x00\x00\x00;", 'image/png', 415, 'media_type_not_allowed'],
            // A real PNG declared as JPEG.
            [ImageFixtures::png(), 'image/jpeg', 422, 'media_invalid'],
            // JPEG magic bytes followed by a script: not a decodable image.
            ["\xFF\xD8\xFF\xE0<?php echo 'x'; ?>" . str_repeat('A', 64), 'image/jpeg', 422, 'media_invalid'],
        ];
        foreach ($cases as [$bytes, $mime, $status, $code]) {
            $id = $this->ticketId($owner, $gid, $bytes, $mime);
            $r = $this->putContent($owner, $id, $bytes, $mime);
            self::assertSame($status, $r->status(), $mime . ' ' . json_encode($r->json()));
            self::assertSame($code, $r->errorCode());
        }
        self::assertSame(0, $this->processor->calls);
        self::assertSame([], $this->storedFiles(true));
    }

    public function testDecompressionBombDimensionsRejected(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);

        foreach ([[20000, 20000], [12001, 10], [10000, 10000]] as [$w, $h]) {
            $bomb = ImageFixtures::pngBomb($w, $h);
            $id = $this->ticketId($owner, $gid, $bomb);
            $r = $this->putContent($owner, $id, $bomb);
            self::assertSame(422, $r->status(), "{$w}x{$h}");
            self::assertSame('media_invalid', $r->errorCode());
        }
        self::assertSame(0, $this->processor->calls);
    }

    public function testNoProcessorFailsClosed(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $png = ImageFixtures::png();
        $id = $this->ticketId($owner, $gid, $png);

        MediaServices::setProcessor(null);
        $put = $this->putContent($owner, $id, $png);
        self::assertSame(503, $put->status());
        self::assertSame('server_error', $put->errorCode());
        self::assertStringNotContainsStringIgnoringCase('gd', (string) $put->json()['error']['message']);
        self::assertSame(503, $this->ticket($owner, $gid, $png)->status());

        self::assertSame([], $this->storedFiles(true));
        self::assertSame('pending', Database::queryOne('SELECT status FROM media_assets WHERE id = :id', ['id' => $id])['status']);
    }

    public function testProcessorFailureMarksFailedAndStoresNothing(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $png = ImageFixtures::png();

        $this->processor->failWith = new ImageProcessingException('corrupt');
        $id = $this->ticketId($owner, $gid, $png);
        $r = $this->putContent($owner, $id, $png);
        self::assertSame(422, $r->status());
        self::assertSame('media_invalid', $r->errorCode());
        self::assertSame('failed', Database::queryOne('SELECT status FROM media_assets WHERE id = :id', ['id' => $id])['status']);
        self::assertSame('media_invalid', $this->putContent($owner, $id, $png)->errorCode());

        $this->processor->failWith = new \RuntimeException('disk full at /secret/path');
        $id2 = $this->ticketId($owner, $gid, $png);
        $r2 = $this->putContent($owner, $id2, $png);
        self::assertSame(500, $r2->status());
        self::assertSame('server_error', $r2->errorCode());
        self::assertStringNotContainsString('secret', (string) json_encode($r2->json()));
        self::assertSame('failed', Database::queryOne('SELECT status FROM media_assets WHERE id = :id', ['id' => $id2])['status']);

        self::assertSame([], $this->storedFiles(true));
    }

    public function testCorsPreflightAllowsPut(): void
    {
        $r = $this->request('OPTIONS', '/api/v1/media/uploads/' . $this->uuid() . '/content', [], null, ['Origin' => 'https://allowed.example']);
        self::assertStringContainsString('PUT', (string) $r->header('Access-Control-Allow-Methods'));
    }

    private function countAssets(): int
    {
        return (int) (Database::queryOne('SELECT COUNT(*) AS c FROM media_assets')['c'] ?? 0);
    }

    /**
     * @param array<string, mixed> $data
     * @return string[]
     */
    private static function sortedKeys(array $data): array
    {
        $keys = array_keys($data);
        sort($keys);
        return $keys;
    }
}
