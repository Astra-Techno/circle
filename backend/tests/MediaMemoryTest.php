<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Core\Database;
use Circle\Tests\Support\ImageFixtures;

final class MediaMemoryTest extends MediaTestCase
{
    public function testAttachPhotosBodyOptionalAndIdsOnlyInResponses(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $member, $gid);
        $a = $this->readyMedia($member, $gid, ImageFixtures::png(400, 300));
        $b = $this->readyMedia($member, $gid, ImageFixtures::png(30, 60));

        $r = $this->memoryWithMedia($member, $gid, [$b, strtoupper($a)]);
        self::assertSame(201, $r->status(), json_encode($r->json()) ?: '');
        self::assertSame('', $r->data()['body']);
        self::assertSame([
            ['id' => $b, 'width' => 30, 'height' => 60],
            ['id' => $a, 'width' => 400, 'height' => 300],
        ], $r->data()['media']);
        $mid = (int) $r->data()['id'];

        $show = $this->request('GET', "/api/v1/memories/{$mid}", [], $owner['token']);
        self::assertSame([$b, $a], array_column($show->data()['media'], 'id'));
        $list = $this->request('GET', "/api/v1/memories?group_id={$gid}", [], $owner['token']);
        self::assertSame([$b, $a], array_column($list->data()[0]['media'], 'id'));
        foreach ([$r, $show, $list] as $resp) {
            $json = (string) json_encode($resp->json());
            self::assertStringNotContainsString('media\/', $json);
            self::assertStringNotContainsString('sig=', $json);
            self::assertStringNotContainsString('storage', $json);
        }

        // A text-only Memory still has an empty media list; edits keep the photos.
        $text = $this->createMemory($owner, $gid, 'Words only');
        self::assertSame([], $this->request('GET', "/api/v1/memories/{$text}", [], $owner['token'])->data()['media']);
        $edit = $this->request('PATCH', "/api/v1/memories/{$mid}", ['body' => 'Now with words'], $member['token']);
        self::assertCount(2, $edit->data()['media']);

        // Attached photos are visible to every member and stay attached once.
        self::assertSame(200, $this->link($owner, $a)->status());
        self::assertNotNull(Database::queryOne('SELECT attached_at FROM media_assets WHERE id = :id', ['id' => $a])['attached_at']);
    }

    public function testBodyStillRequiredWithoutPhotos(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        self::assertSame(422, $this->memoryWithMedia($owner, $gid, [])->status());
        self::assertSame(422, $this->request('POST', "/api/v1/groups/{$gid}/memories", ['body' => ''], $owner['token'])->status());
        self::assertSame(422, $this->memoryWithMedia($owner, $gid, [$this->readyMedia($owner, $gid)], str_repeat('x', 2001))->status());
    }

    public function testAttachRules(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $gid = $this->createGroup($owner);
        $other = $this->createGroup($owner, 'Other group');
        $this->join($owner, $member, $gid);

        $otherGroupMedia = $this->readyMedia($owner, $other);
        $someoneElses = $this->readyMedia($member, $gid);
        $pending = $this->ticketId($owner, $gid, ImageFixtures::png());
        $used = $this->readyMedia($owner, $gid);
        self::assertSame(201, $this->memoryWithMedia($owner, $gid, [$used])->status());
        $discarded = $this->readyMedia($owner, $gid);
        self::assertSame(200, $this->request('DELETE', "/api/v1/media/{$discarded}", [], $owner['token'])->status());
        $good = $this->readyMedia($owner, $gid);

        $before = $this->countMemories();
        foreach ([
            'other group' => $otherGroupMedia,
            'someone else' => $someoneElses,
            'not ready' => $pending,
            'already attached' => $used,
            'discarded' => $discarded,
            'unknown' => $this->uuid(),
        ] as $name => $bad) {
            $r = $this->memoryWithMedia($owner, $gid, [$good, $bad], 'x');
            self::assertSame(422, $r->status(), $name);
            self::assertSame('validation_error', $r->errorCode(), $name);
            self::assertSame([$bad], $r->json()['error']['details']['media_ids'], $name);
        }
        self::assertSame($before, $this->countMemories());
        // Nothing was half-attached: the good photo is still free.
        self::assertNull(Database::queryOne('SELECT attached_at FROM media_assets WHERE id = :id', ['id' => $good])['attached_at']);

        $eleven = array_map(fn (): string => $this->uuid(), range(1, 11));
        self::assertSame(422, $this->memoryWithMedia($owner, $gid, $eleven, 'x')->status());
        self::assertSame(422, $this->memoryWithMedia($owner, $gid, [$good, $good], 'x')->status());
        self::assertSame(422, $this->memoryWithMedia($owner, $gid, ['not-a-uuid'], 'x')->status());
        self::assertSame(422, $this->request('POST', "/api/v1/groups/{$gid}/memories", ['body' => 'x', 'media_ids' => $good], $owner['token'])->status());

        self::assertSame(201, $this->memoryWithMedia($owner, $gid, [$good])->status());
    }

    public function testTenPhotosAllowed(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $ids = [];
        for ($i = 0; $i < 10; $i++) {
            $ids[] = $this->readyMedia($owner, $gid);
        }
        $r = $this->memoryWithMedia($owner, $gid, $ids);
        self::assertSame(201, $r->status());
        self::assertSame($ids, array_column($r->data()['media'], 'id'));
    }

    public function testDiscardUnattachedOnly(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $member, $gid);

        $free = $this->readyMedia($member, $gid);
        self::assertCount(3, $this->filesFor($free));
        self::assertSame(404, $this->request('DELETE', "/api/v1/media/{$free}", [], $owner['token'])->status());
        self::assertSame(200, $this->request('DELETE', "/api/v1/media/{$free}", [], $member['token'])->status());
        self::assertSame([], $this->filesFor($free));
        $row = Database::queryOne('SELECT status, deleted_at, purged_at FROM media_assets WHERE id = :id', ['id' => $free]);
        self::assertSame('deleted', $row['status']);
        self::assertNotNull($row['purged_at']);
        self::assertSame(404, $this->request('DELETE', "/api/v1/media/{$free}", [], $member['token'])->status());

        $attached = $this->readyMedia($member, $gid);
        self::assertSame(201, $this->memoryWithMedia($member, $gid, [$attached])->status());
        $r = $this->request('DELETE', "/api/v1/media/{$attached}", [], $member['token']);
        self::assertSame(409, $r->status());
        self::assertSame('conflict', $r->errorCode());
        self::assertCount(3, $this->filesFor($attached));

        self::assertSame(404, $this->request('DELETE', '/api/v1/media/' . $this->uuid(), [], $member['token'])->status());
    }

    public function testDeletingMemorySoftDeletesItsPhotos(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $member, $gid);
        $media = $this->readyMedia($member, $gid);
        $mid = (int) $this->memoryWithMedia($member, $gid, [$media])->data()['id'];

        // An admin of the exact group removes it.
        self::assertSame(200, $this->request('DELETE', "/api/v1/memories/{$mid}", [], $owner['token'])->status());
        $row = Database::queryOne('SELECT status, deleted_at, purged_at FROM media_assets WHERE id = :id', ['id' => $media]);
        self::assertSame('deleted', $row['status']);
        self::assertNotNull($row['deleted_at']);
        self::assertNull($row['purged_at']);
        // Files stay until the retention period ends; access stops at once.
        self::assertCount(3, $this->filesFor($media));
        self::assertSame(404, $this->link($member, $media)->status());
        // A deleted photo can't be reused in a new Memory.
        self::assertSame(422, $this->memoryWithMedia($member, $gid, [$media])->status());
    }

    private function countMemories(): int
    {
        return (int) (Database::queryOne('SELECT COUNT(*) AS c FROM memories')['c'] ?? 0);
    }
}
