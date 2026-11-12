<?php

declare(strict_types=1);

namespace Circle\Tests;

final class CommentDeletionTest extends ApiTestCase
{
    public function testAuthorCanDeleteOwnComment(): void
    {
        $owner = $this->user('Alice');
        $member = $this->user('Bob');
        $groupId = $this->createGroup($owner, 'Family');
        $this->join($owner, $member, $groupId);

        $memoryId = $this->createMemory($owner, $groupId, 'Test memory');

        $comment = $this->request('POST', "/api/v1/memories/{$memoryId}/comments", [
            'body' => 'My comment',
        ], $member['token']);
        self::assertSame(201, $comment->status());
        $commentId = $comment->data()['id'];

        // Author deletes own comment
        $r = $this->request('DELETE', "/api/v1/memories/{$memoryId}/comments/{$commentId}", [], $member['token']);
        self::assertSame(200, $r->status());
    }

    public function testAdminCanDeleteAnyComment(): void
    {
        $owner = $this->user('Alice');
        $member = $this->user('Bob');
        $groupId = $this->createGroup($owner, 'Family');
        $this->join($owner, $member, $groupId);

        $memoryId = $this->createMemory($owner, $groupId, 'Test');

        $comment = $this->request('POST', "/api/v1/memories/{$memoryId}/comments", [
            'body' => 'Bob comment',
        ], $member['token']);
        $commentId = $comment->data()['id'];

        // Admin (owner) deletes Bob's comment
        $r = $this->request('DELETE', "/api/v1/memories/{$memoryId}/comments/{$commentId}", [], $owner['token']);
        self::assertSame(200, $r->status());
    }

    public function testMemberCannotDeleteOthersComment(): void
    {
        $owner = $this->user('Alice');
        $bob = $this->user('Bob');
        $charlie = $this->user('Charlie');
        $groupId = $this->createGroup($owner, 'Family');
        $this->join($owner, $bob, $groupId);
        $this->join($owner, $charlie, $groupId);

        $memoryId = $this->createMemory($owner, $groupId, 'Test');

        $comment = $this->request('POST', "/api/v1/memories/{$memoryId}/comments", [
            'body' => 'Bob comment',
        ], $bob['token']);
        $commentId = $comment->data()['id'];

        // Charlie (member, not admin) cannot delete Bob's comment
        $r = $this->request('DELETE', "/api/v1/memories/{$memoryId}/comments/{$commentId}", [], $charlie['token']);
        self::assertSame(403, $r->status());
    }

    public function testDeletedCommentNotInDetail(): void
    {
        $owner = $this->user('Alice');
        $groupId = $this->createGroup($owner, 'Family');
        $memoryId = $this->createMemory($owner, $groupId, 'Test');

        $c1 = $this->request('POST', "/api/v1/memories/{$memoryId}/comments", ['body' => 'Keep'], $owner['token']);
        $c2 = $this->request('POST', "/api/v1/memories/{$memoryId}/comments", ['body' => 'Remove'], $owner['token']);
        $commentId = $c2->data()['id'];

        $this->request('DELETE', "/api/v1/memories/{$memoryId}/comments/{$commentId}", [], $owner['token']);

        // Memory detail should only show the remaining comment
        $detail = $this->request('GET', "/api/v1/memories/{$memoryId}", [], $owner['token']);
        self::assertSame(200, $detail->status());
        $comments = $detail->data()['comments'];
        self::assertCount(1, $comments);
        self::assertSame('Keep', $comments[0]['body']);
    }

    public function testDeleteNonexistentCommentReturns404(): void
    {
        $owner = $this->user('Alice');
        $groupId = $this->createGroup($owner, 'Family');
        $memoryId = $this->createMemory($owner, $groupId, 'Test');

        $r = $this->request('DELETE', "/api/v1/memories/{$memoryId}/comments/99999", [], $owner['token']);
        self::assertSame(404, $r->status());
    }
    public function testOnlyRemovingActorCanUndo(): void
    {
        $owner = $this->user('Fictional admin');
        $member = $this->user('Fictional member');
        $group = $this->createGroup($owner, 'Fictional Circle');
        $this->join($owner, $member, $group);
        $memory = $this->createMemory($owner, $group, 'Fictional memory');
        $comment = $this->request('POST', "/api/v1/memories/$memory/comments", ['body'=>'Fictional comment'], $member['token'])->data()['id'];
        $path = "/api/v1/memories/$memory/comments/$comment";
        self::assertSame(200, $this->request('DELETE', $path, [], $owner['token'])->status());
        self::assertSame(404, $this->request('POST', "$path/restore", [], $member['token'])->status());
        self::assertSame(200, $this->request('POST', "$path/restore", [], $owner['token'])->status());
        self::assertSame(404, $this->request('POST', "$path/restore", [], $owner['token'])->status());
        self::assertCount(1, $this->request('GET', "/api/v1/memories/$memory", [], $member['token'])->data()['comments']);
    }
}
