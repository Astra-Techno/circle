<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Core\Database;
use Circle\Media\MediaCleanup;
use Circle\Media\MediaServices;
use Circle\Tests\Support\ImageFixtures;

final class MediaCleanupTest extends MediaTestCase
{
    private function age(string $id, string $column, string $interval): void
    {
        Database::execute(
            "UPDATE media_assets SET {$column} = DATE_SUB(NOW(), INTERVAL {$interval}) WHERE id = :id",
            ['id' => $id]
        );
    }

    /** @return array<string, mixed> */
    private function row(string $id): array
    {
        return Database::queryOne('SELECT status, deleted_at, purged_at FROM media_assets WHERE id = :id', ['id' => $id]) ?? [];
    }

    public function testOrphansOlderThan24HoursAreRemoved(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);

        $oldReady = $this->readyMedia($owner, $gid);
        $oldPending = $this->ticketId($owner, $gid, ImageFixtures::png());
        $this->processor->failWith = new \Circle\Media\ImageProcessingException('bad');
        $oldFailed = $this->ticketId($owner, $gid, ImageFixtures::png());
        $this->putContent($owner, $oldFailed, ImageFixtures::png());
        $this->processor->failWith = null;
        $recent = $this->readyMedia($owner, $gid);
        $oldAttached = $this->readyMedia($owner, $gid);
        self::assertSame(201, $this->memoryWithMedia($owner, $gid, [$oldAttached])->status());

        foreach ([$oldReady, $oldPending, $oldFailed, $oldAttached] as $id) {
            $this->age($id, 'created_at', '25 HOUR');
        }
        $this->age($recent, 'created_at', '23 HOUR');

        $counts = MediaCleanup::run(MediaServices::storage(), 7);
        self::assertSame(['orphans_deleted' => 3, 'files_purged' => 0], $counts);

        foreach ([$oldReady, $oldPending, $oldFailed] as $id) {
            self::assertSame('deleted', $this->row($id)['status']);
            self::assertNotNull($this->row($id)['purged_at']);
            self::assertSame([], $this->filesFor($id));
        }
        self::assertSame('ready', $this->row($recent)['status']);
        self::assertCount(3, $this->filesFor($recent));
        self::assertSame('ready', $this->row($oldAttached)['status']);
        self::assertCount(3, $this->filesFor($oldAttached));

        // Idempotent.
        self::assertSame(['orphans_deleted' => 0, 'files_purged' => 0], MediaCleanup::run(MediaServices::storage(), 7));
    }

    public function testDeletedFilesPurgedAfterRetention(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $old = $this->readyMedia($owner, $gid);
        $fresh = $this->readyMedia($owner, $gid);
        $m1 = (int) $this->memoryWithMedia($owner, $gid, [$old])->data()['id'];
        $m2 = (int) $this->memoryWithMedia($owner, $gid, [$fresh])->data()['id'];
        $this->request('DELETE', "/api/v1/memories/{$m1}", [], $owner['token']);
        $this->request('DELETE', "/api/v1/memories/{$m2}", [], $owner['token']);
        $this->age($old, 'deleted_at', '8 DAY');
        $this->age($fresh, 'deleted_at', '6 DAY');

        self::assertSame(['orphans_deleted' => 0, 'files_purged' => 1], MediaCleanup::run(MediaServices::storage(), 7));
        self::assertSame([], $this->filesFor($old));
        self::assertNotNull($this->row($old)['purged_at']);
        self::assertCount(3, $this->filesFor($fresh));
        self::assertNull($this->row($fresh)['purged_at']);

        self::assertSame(['orphans_deleted' => 0, 'files_purged' => 0], MediaCleanup::run(MediaServices::storage(), 7));
        // A shorter retention purges the rest.
        self::assertSame(['orphans_deleted' => 0, 'files_purged' => 1], MediaCleanup::run(MediaServices::storage(), 5));
        self::assertSame([], $this->filesFor($fresh));
    }
}
