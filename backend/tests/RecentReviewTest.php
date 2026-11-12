<?php

declare(strict_types=1);
namespace Circle\Tests;
use Circle\Core\Database;

final class RecentReviewTest extends ApiTestCase
{
    public function testSearchMustNotExposeAHiddenPoll(): void
    {
        $owner = $this->user('Fictional owner');
        $member = $this->user('Fictional member');
        $group = $this->createGroup($owner, 'Fictional Circle');
        $this->join($owner, $member, $group);
        $created = $this->request('POST', "/api/v1/groups/$group/polls", [
            'question' => 'Fictional hidden ballot', 'options' => ['Park', 'Cafe'],
            'client_id' => 'fictional-review-hidden-poll',
        ], $owner['token']);
        self::assertSame(200, $created->status());
        $id = $created->data()['id'];
        $poll = $this->request('GET', "/api/v1/polls/$id", [], $member['token'])->data();
        Database::execute("UPDATE memories SET status='hidden' WHERE id=:id", ['id' => $poll['memory_id']]);
        self::assertSame(404, $this->request('GET', "/api/v1/polls/$id", [], $member['token'])->status());
        $found = $this->request('GET', '/api/v1/search?q=hidden', [], $member['token']);
        self::assertSame(200, $found->status());
        self::assertSame([], $found->data()['polls'], 'Hidden poll identity/question must not bypass normal poll visibility through search.');
    }

    public function testAlbumMustRejectNonexistentMedia(): void
    {
        $owner = $this->user('Fictional owner');
        $group = $this->createGroup($owner, 'Fictional Circle');
        $created = $this->request('POST', "/api/v1/groups/$group/albums", ['title' => 'Fictional album'], $owner['token']);
        self::assertSame(201, $created->status());
        $id = $created->data()['id'];
        $added = $this->request('POST', "/api/v1/albums/$id/photos", [
            'media_id' => 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        ], $owner['token']);
        self::assertContains($added->status(), [404, 422], 'An unbacked media identifier must not become an album photo.');
    }
}
