<?php

declare(strict_types=1);

namespace Circle\Tests;

final class SearchTest extends ApiTestCase
{
    public function testSearchMemories(): void
    {
        $owner = $this->user('Alice');
        $groupId = $this->createGroup($owner, 'Family');
        $this->createMemory($owner, $groupId, 'Diwali celebration at home');
        $this->createMemory($owner, $groupId, 'Morning walk in the park');

        $r = $this->request('GET', '/api/v1/search?q=Diwali', [], $owner['token']);
        self::assertSame(200, $r->status());
        $data = $r->data();
        self::assertCount(1, $data['memories']);
        self::assertStringContainsString('Diwali', $data['memories'][0]['body']);
    }

    public function testSearchPeople(): void
    {
        $alice = $this->user('Alice Sharma');
        $bob = $this->user('Bob Kumar');
        $groupId = $this->createGroup($alice, 'Office');
        $this->join($alice, $bob, $groupId);

        $r = $this->request('GET', '/api/v1/search?q=Kumar', [], $alice['token']);
        self::assertSame(200, $r->status());
        self::assertCount(1, $r->data()['people']);
        self::assertSame('Bob Kumar', $r->data()['people'][0]['display_name']);
    }

    public function testSearchGroups(): void
    {
        $owner = $this->user('Alice');
        $this->createGroup($owner, 'Weekend Trekkers');
        $this->createGroup($owner, 'Office Gang');

        $r = $this->request('GET', '/api/v1/search?q=Trek', [], $owner['token']);
        self::assertSame(200, $r->status());
        self::assertCount(1, $r->data()['groups']);
    }

    public function testSearchRespectsGroupBoundary(): void
    {
        $alice = $this->user('Alice');
        $bob = $this->user('Bob');
        $aliceGroup = $this->createGroup($alice, 'Private');
        $this->createMemory($alice, $aliceGroup, 'Secret family recipe');

        // Bob has no access to Alice's group
        $bobGroup = $this->createGroup($bob, 'Other');
        $r = $this->request('GET', '/api/v1/search?q=recipe', [], $bob['token']);
        self::assertSame(200, $r->status());
        self::assertCount(0, $r->data()['memories']);
    }

    public function testSearchRequiresQuery(): void
    {
        $owner = $this->user('Alice');
        $r = $this->request('GET', '/api/v1/search?q=', [], $owner['token']);
        self::assertSame(422, $r->status());
    }

    public function testSearchReturnsAllCategories(): void
    {
        $owner = $this->user('Alice');
        $groupId = $this->createGroup($owner, 'Test Group');

        $r = $this->request('GET', '/api/v1/search?q=test', [], $owner['token']);
        self::assertSame(200, $r->status());
        $data = $r->data();
        self::assertArrayHasKey('memories', $data);
        self::assertArrayHasKey('people', $data);
        self::assertArrayHasKey('events', $data);
        self::assertArrayHasKey('polls', $data);
        self::assertArrayHasKey('groups', $data);
    }
}
