<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Controllers\ActivityController;
use Circle\Core\Database;

final class ActivityTest extends ApiTestCase
{
    public function testEmptyActivityInbox(): void
    {
        $owner = $this->user('Alice');

        $r = $this->request('GET', '/api/v1/me/activity', [], $owner['token']);
        self::assertSame(200, $r->status());
        $data = $r->data();
        self::assertSame([], $data['items']);
        self::assertSame(0, $data['unread_count']);
        self::assertFalse($data['has_more']);
    }

    public function testRecordAndListActivity(): void
    {
        $owner = $this->user('Alice');
        $groupId = $this->createGroup($owner, 'Family');

        // Record some activity directly
        ActivityController::record(
            $owner['id'], 'memory.created',
            actorId: $owner['id'], groupId: $groupId,
            summary: 'Alice posted a new memory'
        );
        ActivityController::record(
            $owner['id'], 'comment.created',
            actorId: $owner['id'], groupId: $groupId,
            summary: 'Alice commented on a memory'
        );

        $r = $this->request('GET', '/api/v1/me/activity', [], $owner['token']);
        self::assertSame(200, $r->status());
        $data = $r->data();
        self::assertCount(2, $data['items']);
        self::assertSame(2, $data['unread_count']);
        // Newest first
        self::assertSame('comment.created', $data['items'][0]['kind']);
        self::assertFalse($data['items'][0]['is_read']);
    }

    public function testMarkAllRead(): void
    {
        $owner = $this->user('Alice');

        ActivityController::record($owner['id'], 'memory.created', summary: 'Test 1');
        ActivityController::record($owner['id'], 'comment.created', summary: 'Test 2');

        // Mark all read
        $r = $this->request('POST', '/api/v1/me/activity/read', [], $owner['token']);
        self::assertSame(200, $r->status());

        // Verify
        $r = $this->request('GET', '/api/v1/me/activity', [], $owner['token']);
        self::assertSame(0, $r->data()['unread_count']);
        self::assertTrue($r->data()['items'][0]['is_read']);
    }

    public function testMarkSpecificRead(): void
    {
        $owner = $this->user('Alice');

        ActivityController::record($owner['id'], 'memory.created', summary: 'Test 1');
        ActivityController::record($owner['id'], 'comment.created', summary: 'Test 2');

        $list = $this->request('GET', '/api/v1/me/activity', [], $owner['token']);
        $firstId = $list->data()['items'][0]['id'];

        // Mark only one
        $r = $this->request('POST', '/api/v1/me/activity/read', ['ids' => [$firstId]], $owner['token']);
        self::assertSame(200, $r->status());

        $list = $this->request('GET', '/api/v1/me/activity', [], $owner['token']);
        self::assertSame(1, $list->data()['unread_count']);
    }

    public function testUnreadFilter(): void
    {
        $owner = $this->user('Alice');

        ActivityController::record($owner['id'], 'memory.created', summary: 'Test 1');
        ActivityController::record($owner['id'], 'comment.created', summary: 'Test 2');

        // Mark first as read
        $list = $this->request('GET', '/api/v1/me/activity', [], $owner['token']);
        $this->request('POST', '/api/v1/me/activity/read', ['ids' => [$list->data()['items'][0]['id']]], $owner['token']);

        // Filter unread only
        $r = $this->request('GET', '/api/v1/me/activity?unread=true', [], $owner['token']);
        self::assertSame(200, $r->status());
        self::assertCount(1, $r->data()['items']);
    }

    public function testActivityIsolatedPerUser(): void
    {
        $alice = $this->user('Alice');
        $bob = $this->user('Bob');

        ActivityController::record($alice['id'], 'memory.created', summary: 'For Alice');
        ActivityController::record($bob['id'], 'memory.created', summary: 'For Bob');

        $r = $this->request('GET', '/api/v1/me/activity', [], $alice['token']);
        self::assertCount(1, $r->data()['items']);
        self::assertSame('For Alice', $r->data()['items'][0]['summary']);

        $r = $this->request('GET', '/api/v1/me/activity', [], $bob['token']);
        self::assertCount(1, $r->data()['items']);
        self::assertSame('For Bob', $r->data()['items'][0]['summary']);
    }
}
