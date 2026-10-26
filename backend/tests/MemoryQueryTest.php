<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Core\Database;

/** Query filters must retain exact-group visibility and stable pagination. */
final class MemoryQueryTest extends ApiTestCase
{
    public function testSavedFilterBelongsToCurrentViewer(): void
    {
        $owner = $this->user('Fictional owner');
        $member = $this->user('Fictional member');
        $group = $this->createGroup($owner);
        $this->join($owner, $member, $group);
        $first = $this->createMemory($owner, $group, 'Saved only by owner');
        $second = $this->createMemory($member, $group, 'Saved only by member');
        $this->request('POST', "/api/v1/memories/{$first}/save", [], $owner['token']);
        $this->request('POST', "/api/v1/memories/{$second}/save", [], $member['token']);

        $own = $this->request('GET', '/api/v1/memories?saved=true', [], $owner['token']);
        self::assertSame(200, $own->status());
        self::assertSame([$first], array_column($own->data(), 'id'));
        self::assertTrue($own->data()[0]['user_saved']);
        $other = $this->request('GET', '/api/v1/memories?saved=true', [], $member['token']);
        self::assertSame([$second], array_column($other->data(), 'id'));
        $all = $this->request('GET', '/api/v1/memories?saved=false', [], $member['token']);
        self::assertSame([$second, $first], array_column($all->data(), 'id'));
    }

    public function testSavedAndSearchNeverRestoreAccessAfterLeaving(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $group = $this->createGroup($owner);
        $this->join($owner, $member, $group);
        $memory = $this->createMemory($owner, $group, 'Fictional old reunion');
        $this->request('POST', "/api/v1/memories/{$memory}/save", [], $member['token']);
        self::assertCount(1, $this->request('GET', '/api/v1/memories?saved=true&q=reunion', [], $member['token'])->data());
        self::assertSame(200, $this->request('POST', "/api/v1/groups/{$group}/leave", [], $member['token'])->status());

        self::assertSame([], $this->request('GET', '/api/v1/memories?saved=true&q=reunion', [], $member['token'])->data());
        self::assertSame(403, $this->request('GET', "/api/v1/memories?group_id={$group}&saved=true&q=reunion", [], $member['token'])->status());
    }

    public function testSearchDoesNotInheritParentMembership(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $root = $this->createGroup($owner, 'Root');
        $this->join($owner, $member, $root);
        $child = $this->createGroup($member, 'Private child', $root, ['visibility' => 'hidden']);
        $rootMemory = $this->createMemory($owner, $root, 'Fictional reunion root');
        $childMemory = $this->createMemory($member, $child, 'Fictional reunion child');

        $r = $this->request('GET', '/api/v1/memories?q=reunion', [], $owner['token']);
        self::assertSame(200, $r->status());
        self::assertSame([$rootMemory], array_column($r->data(), 'id'));
        self::assertNotContains($childMemory, array_column($r->data(), 'id'));
        self::assertSame(403, $this->request('GET', "/api/v1/memories?group_id={$child}&q=reunion", [], $owner['token'])->status());
    }

    public function testSearchIsLiteralAndIncludesPlace(): void
    {
        $user = $this->user();
        $group = $this->createGroup($user);
        $literal = $this->createMemory($user, $group, 'Fictional 100%_! keepsake');
        $plain = $this->createMemory($user, $group, 'Fictional 100 percent keepsake');
        $place = $this->request('POST', "/api/v1/groups/{$group}/memories", ['body' => 'A trip', 'place' => 'Fictional தமிழ் venue'], $user['token'])->data()['id'];
        foreach (['%', '_', '!', '100%_!'] as $query) {
            $r = $this->request('GET', '/api/v1/memories?q=' . rawurlencode($query), [], $user['token']);
            self::assertSame(200, $r->status());
            self::assertSame([$literal], array_column($r->data(), 'id'));
            self::assertNotContains($plain, array_column($r->data(), 'id'));
        }
        $r = $this->request('GET', '/api/v1/memories?q=' . rawurlencode(' தமிழ் '), [], $user['token']);
        self::assertSame([$place], array_column($r->data(), 'id'));
        self::assertSame([], $this->request('GET', '/api/v1/memories?q=' . rawurlencode("' OR 1=1 --"), [], $user['token'])->data());
        self::assertCount(3, $this->request('GET', '/api/v1/memories?q=%20%20', [], $user['token'])->data());
    }

    public function testSavedSearchGroupAndCursorCombineWithoutDuplicates(): void
    {
        $user = $this->user();
        $group = $this->createGroup($user, 'Target');
        $other = $this->createGroup($user, 'Other');
        $matching = [];
        for ($i = 0; $i < 5; $i++) {
            $id = $this->createMemory($user, $group, 'Fictional reunion ' . $i);
            $this->request('POST', "/api/v1/memories/{$id}/save", [], $user['token']);
            $matching[] = $id;
        }
        $this->createMemory($user, $group, 'Fictional reunion not saved');
        $wrongQuery = $this->createMemory($user, $group, 'Something else');
        $wrongGroup = $this->createMemory($user, $other, 'Fictional reunion elsewhere');
        foreach ([$wrongQuery, $wrongGroup] as $id) {
            $this->request('POST', "/api/v1/memories/{$id}/save", [], $user['token']);
        }
        Database::execute('UPDATE memories SET created_at = :time', ['time' => '2026-01-01 12:00:00']);
        $seen = [];
        $cursor = null;
        $pages = 0;
        do {
            $path = "/api/v1/memories?group_id={$group}&saved=true&q=reunion&limit=2" . ($cursor === null ? '' : '&cursor=' . rawurlencode($cursor));
            $r = $this->request('GET', $path, [], $user['token']);
            self::assertSame(200, $r->status());
            $seen = [...$seen, ...array_column($r->data(), 'id')];
            $cursor = $r->json()['pagination']['next_cursor'];
            $pages++;
        } while ($cursor !== null && $pages < 10);
        self::assertSame(3, $pages);
        self::assertSame(array_reverse($matching), $seen);
    }

    public function testInvalidFilterInputsReturnValidationErrors(): void
    {
        $user = $this->user();
        foreach (['yes', '1', 'TRUE', ''] as $value) {
            $r = $this->request('GET', '/api/v1/memories?saved=' . rawurlencode($value), [], $user['token']);
            self::assertSame(422, $r->status());
            self::assertSame('validation_error', $r->errorCode());
        }
        foreach (['saved[]=true', 'q[]=text', 'q=' . rawurlencode("bad\xfftext"), 'q=' . rawurlencode(str_repeat('🙂', 201))] as $query) {
            self::assertSame(422, $this->request('GET', '/api/v1/memories?' . $query, [], $user['token'])->status());
        }
        self::assertSame(200, $this->request('GET', '/api/v1/memories?q=' . rawurlencode(str_repeat('🙂', 200)), [], $user['token'])->status());
        self::assertSame(422, $this->request('GET', '/api/v1/memories?saved=true&q=reunion&cursor=not-a-cursor', [], $user['token'])->status());
    }
}
