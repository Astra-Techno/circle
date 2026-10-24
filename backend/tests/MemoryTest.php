<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Core\Database;

final class MemoryTest extends ApiTestCase
{
    public function testCreateUsesRouteGroupAndAuthenticatedUser(): void
    {
        $owner = $this->user('Meena');
        $gid = $this->createGroup($owner);
        $other = $this->createGroup($owner, 'Other');

        // A group_id in the body is ignored: the route decides.
        $r = $this->request('POST', "/api/v1/groups/{$gid}/memories", ['body' => 'Hello', 'group_id' => $other, 'memory_date' => '2024-05-01', 'place' => 'Chennai'], $owner['token']);
        self::assertSame(201, $r->status());
        self::assertSame($gid, $r->data()['group_id']);
        self::assertSame($owner['id'], $r->data()['author_id']);
        self::assertSame('Meena', $r->data()['author_name']);
    }

    public function testCreateValidation(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        self::assertSame(422, $this->request('POST', "/api/v1/groups/{$gid}/memories", ['body' => ''], $owner['token'])->status());
        self::assertSame(422, $this->request('POST', "/api/v1/groups/{$gid}/memories", ['body' => 'x', 'memory_date' => '2024-02-31'], $owner['token'])->status());
        self::assertSame(422, $this->request('POST', "/api/v1/groups/{$gid}/memories", ['body' => str_repeat('x', 2001)], $owner['token'])->status());
    }

    public function testNonMemberCannotCreateOrReadMemories(): void
    {
        $owner = $this->user();
        $outsider = $this->user();
        $gid = $this->createGroup($owner);
        $mid = $this->createMemory($owner, $gid);

        self::assertSame(403, $this->request('POST', "/api/v1/groups/{$gid}/memories", ['body' => 'x'], $outsider['token'])->status());
        self::assertSame(403, $this->request('GET', "/api/v1/memories?group_id={$gid}", [], $outsider['token'])->status());
        self::assertSame(404, $this->request('GET', "/api/v1/memories/{$mid}", [], $outsider['token'])->status());
        self::assertSame([], $this->request('GET', '/api/v1/memories', [], $outsider['token'])->data());
    }

    public function testParentAdminCannotReadChildMemories(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $root = $this->createGroup($owner, 'Root');
        $this->join($owner, $member, $root);
        $child = $this->createGroup($member, 'Private corner', $root, ['visibility' => 'hidden']);
        $mid = $this->createMemory($member, $child, 'Only for the child group');

        // Owner/admin of the parent is not a member of the child.
        self::assertSame(404, $this->request('GET', "/api/v1/memories/{$mid}", [], $owner['token'])->status());
        self::assertSame(403, $this->request('GET', "/api/v1/memories?group_id={$child}", [], $owner['token'])->status());
        $all = $this->request('GET', '/api/v1/memories', [], $owner['token']);
        self::assertNotContains($mid, array_column($all->data(), 'id'));
        self::assertSame(404, $this->request('POST', "/api/v1/memories/{$mid}/comments", ['body' => 'hi'], $owner['token'])->status());
        self::assertSame(404, $this->request('DELETE', "/api/v1/memories/{$mid}", [], $owner['token'])->status());
    }

    public function testListAndCursorPagination(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $ids = [];
        for ($i = 0; $i < 5; $i++) {
            $ids[] = $this->createMemory($owner, $gid, "Memory {$i}");
        }
        // All created in the same second: the id tiebreaker keeps pages stable.
        Database::execute('UPDATE memories SET created_at = :t', ['t' => '2026-01-01 10:00:00']);

        $seen = [];
        $cursor = null;
        $pages = 0;
        do {
            $path = "/api/v1/memories?group_id={$gid}&limit=2" . ($cursor !== null ? '&cursor=' . urlencode($cursor) : '');
            $r = $this->request('GET', $path, [], $owner['token']);
            self::assertSame(200, $r->status());
            $seen = array_merge($seen, array_column($r->data(), 'id'));
            $cursor = $r->json()['pagination']['next_cursor'];
            $pages++;
        } while ($cursor !== null && $pages < 10);

        self::assertSame(3, $pages);
        self::assertSame(array_reverse($ids), $seen);
    }

    public function testLimitClampedAndBadCursorRejected(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $this->createMemory($owner, $gid);

        $neg = $this->request('GET', '/api/v1/memories?limit=-3', [], $owner['token']);
        self::assertSame(200, $neg->status());
        self::assertSame(1, $neg->json()['pagination']['limit']);
        self::assertSame(50, $this->request('GET', '/api/v1/memories?limit=100000', [], $owner['token'])->json()['pagination']['limit']);

        $bad = $this->request('GET', '/api/v1/memories?cursor=not-a-cursor', [], $owner['token']);
        self::assertSame(422, $bad->status());
        self::assertSame('invalid_cursor', $bad->errorCode());
    }

    public function testUpdateAndDeleteAuthorization(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $member, $gid);
        $mid = $this->createMemory($member, $gid);

        self::assertSame(403, $this->request('PATCH', "/api/v1/memories/{$mid}", ['body' => 'edit'], $owner['token'])->status());
        $edit = $this->request('PATCH', "/api/v1/memories/{$mid}", ['body' => 'edited', 'place' => ''], $member['token']);
        self::assertSame(200, $edit->status());
        self::assertSame('edited', $edit->data()['body']);

        // Admin of the exact group can remove; the author can't after leaving.
        $mid2 = $this->createMemory($member, $gid);
        $this->request('POST', "/api/v1/groups/{$gid}/leave", [], $member['token']);
        self::assertSame(404, $this->request('DELETE', "/api/v1/memories/{$mid2}", [], $member['token'])->status());
        self::assertSame(200, $this->request('DELETE', "/api/v1/memories/{$mid}", [], $owner['token'])->status());
        self::assertSame(404, $this->request('GET', "/api/v1/memories/{$mid}", [], $owner['token'])->status());
    }

    public function testCommentsReactionsSaves(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $outsider = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $member, $gid);
        $mid = $this->createMemory($owner, $gid);

        $c = $this->request('POST', "/api/v1/memories/{$mid}/comments", ['body' => 'Lovely'], $member['token']);
        self::assertSame(201, $c->status());
        $reply = $this->request('POST', "/api/v1/memories/{$mid}/comments", ['body' => 'Thanks', 'parent_id' => $c->data()['id']], $owner['token']);
        self::assertSame(201, $reply->status());

        // Reactions: toggle, replace, allowlist.
        self::assertTrue($this->request('POST', "/api/v1/memories/{$mid}/reactions", ['emoji' => '❤️'], $member['token'])->data()['reacted']);
        self::assertSame('🎉', $this->request('POST', "/api/v1/memories/{$mid}/reactions", ['emoji' => '🎉'], $member['token'])->data()['emoji']);
        self::assertFalse($this->request('POST', "/api/v1/memories/{$mid}/reactions", ['emoji' => '🎉'], $member['token'])->data()['reacted']);
        self::assertSame(422, $this->request('POST', "/api/v1/memories/{$mid}/reactions", ['emoji' => '<script>'], $member['token'])->status());

        self::assertTrue($this->request('POST', "/api/v1/memories/{$mid}/save", [], $member['token'])->data()['saved']);
        self::assertFalse($this->request('POST', "/api/v1/memories/{$mid}/save", [], $member['token'])->data()['saved']);
        self::assertTrue($this->request('POST', "/api/v1/memories/{$mid}/save", [], $member['token'])->data()['saved']);

        $show = $this->request('GET', "/api/v1/memories/{$mid}", [], $member['token']);
        self::assertCount(2, $show->data()['comments']);
        self::assertSame([], $show->data()['reactions']);

        $list = $this->request('GET', '/api/v1/memories', [], $member['token']);
        self::assertTrue($list->data()[0]['user_saved']);
        self::assertSame(2, $list->data()[0]['comment_count']);

        // Outsiders can do none of it.
        self::assertSame(404, $this->request('POST', "/api/v1/memories/{$mid}/comments", ['body' => 'x'], $outsider['token'])->status());
        self::assertSame(404, $this->request('POST', "/api/v1/memories/{$mid}/reactions", ['emoji' => '❤️'], $outsider['token'])->status());
        self::assertSame(404, $this->request('POST', "/api/v1/memories/{$mid}/save", [], $outsider['token'])->status());
    }

    public function testCommentParentMustBelongToSameMemory(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $m1 = $this->createMemory($owner, $gid);
        $m2 = $this->createMemory($owner, $gid);
        $c1 = $this->request('POST', "/api/v1/memories/{$m1}/comments", ['body' => 'On one'], $owner['token'])->data()['id'];

        $r = $this->request('POST', "/api/v1/memories/{$m2}/comments", ['body' => 'Wrong thread', 'parent_id' => $c1], $owner['token']);
        self::assertSame(422, $r->status());
    }
}
