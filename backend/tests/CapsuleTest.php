<?php

declare(strict_types=1);

namespace Circle\Tests;

final class CapsuleTest extends ApiTestCase
{
    public function testCreateCapsule(): void
    {
        $owner = $this->user('Alice');
        $groupId = $this->createGroup($owner, 'Family');

        $r = $this->request('POST', "/api/v1/groups/{$groupId}/capsules", [
            'title' => 'Open on graduation day',
            'message' => 'Remember this moment!',
            'unlock_days' => 30,
        ], $owner['token']);

        self::assertSame(201, $r->status());
        $data = $r->data();
        self::assertSame($groupId, $data['group_id']);
        self::assertIsInt($data['id']);
    }

    public function testCreateCapsuleValidation(): void
    {
        $owner = $this->user('Alice');
        $groupId = $this->createGroup($owner, 'Family');

        // Missing title
        $r = $this->request('POST', "/api/v1/groups/{$groupId}/capsules", [
            'unlock_days' => 30,
        ], $owner['token']);
        self::assertSame(422, $r->status());

        // unlock_days too large
        $r = $this->request('POST', "/api/v1/groups/{$groupId}/capsules", [
            'title' => 'Test',
            'unlock_days' => 5000,
        ], $owner['token']);
        self::assertSame(422, $r->status());
    }

    public function testListCapsules(): void
    {
        $owner = $this->user('Alice');
        $groupId = $this->createGroup($owner, 'Family');

        $this->request('POST', "/api/v1/groups/{$groupId}/capsules", [
            'title' => 'Capsule 1', 'unlock_days' => 30,
        ], $owner['token']);
        $this->request('POST', "/api/v1/groups/{$groupId}/capsules", [
            'title' => 'Capsule 2', 'unlock_days' => 60,
        ], $owner['token']);

        $r = $this->request('GET', "/api/v1/groups/{$groupId}/capsules", [], $owner['token']);
        self::assertSame(200, $r->status());
        self::assertCount(2, $r->data()['items']);
    }

    public function testShowCapsule(): void
    {
        $owner = $this->user('Alice');
        $groupId = $this->createGroup($owner, 'Family');

        $create = $this->request('POST', "/api/v1/groups/{$groupId}/capsules", [
            'title' => 'My Capsule', 'message' => 'Hello', 'unlock_days' => 30,
        ], $owner['token']);
        $capsuleId = $create->data()['id'];

        $r = $this->request('GET', "/api/v1/capsules/{$capsuleId}", [], $owner['token']);
        self::assertSame(200, $r->status());
        $data = $r->data();
        self::assertSame('My Capsule', $data['title']);
        self::assertTrue($data['is_open']);
        self::assertFalse($data['is_sealed']);
        self::assertFalse($data['is_unlocked']);
    }

    public function testAddEntry(): void
    {
        $owner = $this->user('Alice');
        $member = $this->user('Bob');
        $groupId = $this->createGroup($owner, 'Family');
        $this->join($owner, $member, $groupId);

        $create = $this->request('POST', "/api/v1/groups/{$groupId}/capsules", [
            'title' => 'Time Capsule', 'unlock_days' => 30,
        ], $owner['token']);
        $capsuleId = $create->data()['id'];

        // Owner adds entry
        $r = $this->request('POST', "/api/v1/capsules/{$capsuleId}/entries", [
            'body' => 'My first contribution',
        ], $owner['token']);
        self::assertSame(201, $r->status());

        // Member adds entry
        $r = $this->request('POST', "/api/v1/capsules/{$capsuleId}/entries", [
            'body' => 'Bob was here too',
        ], $member['token']);
        self::assertSame(201, $r->status());
    }

    public function testEntriesHiddenBeforeUnlock(): void
    {
        $owner = $this->user('Alice');
        $groupId = $this->createGroup($owner, 'Family');

        $create = $this->request('POST', "/api/v1/groups/{$groupId}/capsules", [
            'title' => 'Future', 'unlock_days' => 30,
        ], $owner['token']);
        $capsuleId = $create->data()['id'];

        $this->request('POST', "/api/v1/capsules/{$capsuleId}/entries", [
            'body' => 'Secret message',
        ], $owner['token']);

        // Entries should be forbidden before unlock
        $r = $this->request('GET', "/api/v1/capsules/{$capsuleId}/entries", [], $owner['token']);
        self::assertSame(403, $r->status());
    }

    public function testSealCapsule(): void
    {
        $owner = $this->user('Alice');
        $member = $this->user('Bob');
        $groupId = $this->createGroup($owner, 'Family');
        $this->join($owner, $member, $groupId);

        $create = $this->request('POST', "/api/v1/groups/{$groupId}/capsules", [
            'title' => 'Seal Me', 'unlock_days' => 30,
        ], $owner['token']);
        $capsuleId = $create->data()['id'];

        // Non-creator cannot seal
        $r = $this->request('POST', "/api/v1/capsules/{$capsuleId}/seal", [], $member['token']);
        self::assertSame(403, $r->status());

        // Creator seals
        $r = $this->request('POST', "/api/v1/capsules/{$capsuleId}/seal", [], $owner['token']);
        self::assertSame(200, $r->status());

        // Cannot add entries after seal
        $r = $this->request('POST', "/api/v1/capsules/{$capsuleId}/entries", [
            'body' => 'Too late',
        ], $owner['token']);
        self::assertSame(422, $r->status());

        // Cannot seal again
        $r = $this->request('POST', "/api/v1/capsules/{$capsuleId}/seal", [], $owner['token']);
        self::assertSame(422, $r->status());
    }

    public function testDeleteCapsule(): void
    {
        $owner = $this->user('Alice');
        $member = $this->user('Bob');
        $groupId = $this->createGroup($owner, 'Family');
        $this->join($owner, $member, $groupId);

        $create = $this->request('POST', "/api/v1/groups/{$groupId}/capsules", [
            'title' => 'Delete Me', 'unlock_days' => 30,
        ], $owner['token']);
        $capsuleId = $create->data()['id'];

        // Non-creator cannot delete
        $r = $this->request('DELETE', "/api/v1/capsules/{$capsuleId}", [], $member['token']);
        self::assertSame(403, $r->status());

        // Creator deletes
        $r = $this->request('DELETE', "/api/v1/capsules/{$capsuleId}", [], $owner['token']);
        self::assertSame(200, $r->status());

        // Gone
        $r = $this->request('GET', "/api/v1/capsules/{$capsuleId}", [], $owner['token']);
        self::assertSame(404, $r->status());
    }

    public function testNonMemberCannotAccessCapsule(): void
    {
        $owner = $this->user('Alice');
        $outsider = $this->user('Eve');
        $groupId = $this->createGroup($owner, 'Family');

        $create = $this->request('POST', "/api/v1/groups/{$groupId}/capsules", [
            'title' => 'Private', 'unlock_days' => 30,
        ], $owner['token']);
        $capsuleId = $create->data()['id'];

        $r = $this->request('GET', "/api/v1/capsules/{$capsuleId}", [], $outsider['token']);
        self::assertSame(403, $r->status());

        $r = $this->request('GET', "/api/v1/groups/{$groupId}/capsules", [], $outsider['token']);
        self::assertSame(403, $r->status());
    }
    public function testAbsoluteUnlockDateCountsAndSealedMessagePrivacy(): void
    {
        $owner = $this->user('Fictional owner');
        $group = $this->createGroup($owner, 'Fictional Circle');
        $date = gmdate('Y-m-d\TH:i:s\Z', time()+3*86400);
        $created = $this->request('POST', "/api/v1/groups/$group/capsules", ['title'=>'Fictional future','message'=>'Private note','unlock_at'=>$date], $owner['token']);
        self::assertSame(201, $created->status());
        $id = $created->data()['id'];
        self::assertSame(201, $this->request('POST', "/api/v1/capsules/$id/entries", ['body'=>'Keep this text'], $owner['token'])->status());
        self::assertSame(1, $this->request('GET', "/api/v1/capsules/$id", [], $owner['token'])->data()['entry_count']);
        self::assertSame(200, $this->request('POST', "/api/v1/capsules/$id/seal", [], $owner['token'])->status());
        self::assertSame('', $this->request('GET', "/api/v1/capsules/$id", [], $owner['token'])->data()['message']);
        self::assertSame(403, $this->request('GET', "/api/v1/capsules/$id/entries", [], $owner['token'])->status());
        self::assertSame(422, $this->request('POST', "/api/v1/capsules/$id/entries", ['body'=>'Too late'], $owner['token'])->status());
        \Circle\Core\Database::execute('UPDATE capsules SET unlock_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 DAY) WHERE id=:id', ['id'=>$id]);
        $entries = $this->request('GET', "/api/v1/capsules/$id/entries", [], $owner['token'])->data();
        self::assertSame('Keep this text', $entries['items'][0]['body']);
        self::assertSame('Private note', $this->request('GET', "/api/v1/capsules/$id", [], $owner['token'])->data()['message']);
    }
}
