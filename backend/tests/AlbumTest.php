<?php

declare(strict_types=1);

namespace Circle\Tests;

final class AlbumTest extends MediaTestCase
{
    public function testCreateAlbum(): void
    {
        $owner = $this->user('Alice');
        $groupId = $this->createGroup($owner, 'Family');

        $r = $this->request('POST', "/api/v1/groups/{$groupId}/albums", [
            'title' => 'Summer 2026',
            'description' => 'Photos from our summer trip',
        ], $owner['token']);

        self::assertSame(201, $r->status());
        $data = $r->data();
        self::assertSame($groupId, $data['group_id']);
        self::assertIsInt($data['id']);
    }

    public function testListAlbums(): void
    {
        $owner = $this->user('Alice');
        $groupId = $this->createGroup($owner, 'Family');

        $this->request('POST', "/api/v1/groups/{$groupId}/albums", ['title' => 'Album 1'], $owner['token']);
        $this->request('POST', "/api/v1/groups/{$groupId}/albums", ['title' => 'Album 2'], $owner['token']);

        $r = $this->request('GET', "/api/v1/groups/{$groupId}/albums", [], $owner['token']);
        self::assertSame(200, $r->status());
        self::assertCount(2, $r->data()['items']);
    }

    public function testShowAlbum(): void
    {
        $owner = $this->user('Alice');
        $groupId = $this->createGroup($owner, 'Family');

        $create = $this->request('POST', "/api/v1/groups/{$groupId}/albums", [
            'title' => 'My Album',
        ], $owner['token']);
        $albumId = $create->data()['id'];

        $r = $this->request('GET', "/api/v1/albums/{$albumId}", [], $owner['token']);
        self::assertSame(200, $r->status());
        self::assertSame('My Album', $r->data()['title']);
        self::assertArrayHasKey('photos', $r->data());
    }

    public function testUpdateAlbum(): void
    {
        $owner = $this->user('Alice');
        $groupId = $this->createGroup($owner, 'Family');

        $create = $this->request('POST', "/api/v1/groups/{$groupId}/albums", ['title' => 'Old'], $owner['token']);
        $albumId = $create->data()['id'];

        $r = $this->request('PATCH', "/api/v1/albums/{$albumId}", ['title' => 'New Title'], $owner['token']);
        self::assertSame(200, $r->status());
    }

    public function testDeleteAlbum(): void
    {
        $owner = $this->user('Alice');
        $groupId = $this->createGroup($owner, 'Family');

        $create = $this->request('POST', "/api/v1/groups/{$groupId}/albums", ['title' => 'Delete'], $owner['token']);
        $albumId = $create->data()['id'];

        $r = $this->request('DELETE', "/api/v1/albums/{$albumId}", [], $owner['token']);
        self::assertSame(200, $r->status());

        $r = $this->request('GET', "/api/v1/albums/{$albumId}", [], $owner['token']);
        self::assertSame(404, $r->status());
    }

    public function testAddAndRemovePhoto(): void
    {
        $owner = $this->user('Alice');
        $groupId = $this->createGroup($owner, 'Family');

        $create = $this->request('POST', "/api/v1/groups/{$groupId}/albums", ['title' => 'Photos'], $owner['token']);
        $albumId = $create->data()['id'];

        $media = $this->readyMedia($owner, $groupId);
        $memory = $this->request('POST', "/api/v1/groups/{$groupId}/memories", ['body'=>'Fictional photo', 'media_ids'=>[$media]], $owner['token']);
        self::assertSame(201, $memory->status());
        $r = $this->request('POST', "/api/v1/albums/{$albumId}/photos", [
            'media_id' => $media,
            'caption' => 'Beach sunset',
        ], $owner['token']);
        self::assertSame(201, $r->status());
        $photoId = $r->data()['id'];

        // Update caption
        $r = $this->request('PATCH', "/api/v1/albums/{$albumId}/photos/{$photoId}", [
            'caption' => 'Updated caption',
        ], $owner['token']);
        self::assertSame(200, $r->status());

        // Remove photo
        $r = $this->request('DELETE', "/api/v1/albums/{$albumId}/photos/{$photoId}", [], $owner['token']);
        self::assertSame(200, $r->status());
    }

    public function testNonMemberCannotAccess(): void
    {
        $owner = $this->user('Alice');
        $outsider = $this->user('Eve');
        $groupId = $this->createGroup($owner, 'Family');

        $create = $this->request('POST', "/api/v1/groups/{$groupId}/albums", ['title' => 'Private'], $owner['token']);
        $albumId = $create->data()['id'];

        $r = $this->request('GET', "/api/v1/albums/{$albumId}", [], $outsider['token']);
        self::assertSame(403, $r->status());

        $r = $this->request('GET', "/api/v1/groups/{$groupId}/albums", [], $outsider['token']);
        self::assertSame(403, $r->status());
    }

    public function testAdminCanEditOthersAlbum(): void
    {
        $owner = $this->user('Alice');
        $member = $this->user('Bob');
        $groupId = $this->createGroup($owner, 'Family');
        $this->join($owner, $member, $groupId);

        // Bob creates album
        $create = $this->request('POST', "/api/v1/groups/{$groupId}/albums", ['title' => "Bob's Album"], $member['token']);
        $albumId = $create->data()['id'];

        // Owner (admin) can update
        $r = $this->request('PATCH', "/api/v1/albums/{$albumId}", ['title' => 'Renamed'], $owner['token']);
        self::assertSame(200, $r->status());

        // Owner can delete
        $r = $this->request('DELETE', "/api/v1/albums/{$albumId}", [], $owner['token']);
        self::assertSame(200, $r->status());
    }
    public function testMediaMustBeReadySharedAndInExactCircle(): void
    {
        $owner = $this->user('Fictional owner');
        $group = $this->createGroup($owner, 'Fictional Circle');
        $other = $this->createGroup($owner, 'Fictional other Circle');
        $album = $this->request('POST', "/api/v1/groups/$group/albums", ['title'=>'Fictional album'], $owner['token'])->data()['id'];
        $foreign = $this->readyMedia($owner, $other);
        $this->memoryWithMedia($owner, $other, [$foreign]);
        $media = $this->readyMedia($owner, $group);
        foreach ([$foreign, $media] as $invalid) {
            self::assertSame(422, $this->request('POST', "/api/v1/albums/$album/photos", ['media_id'=>$invalid], $owner['token'])->status());
        }
        $memory = $this->memoryWithMedia($owner, $group, [$media])->data()['id'];
        self::assertSame(422, $this->request('PATCH', "/api/v1/albums/$album", ['cover_media_id'=>$media], $owner['token'])->status());
        self::assertSame(201, $this->request('POST', "/api/v1/albums/$album/photos", ['media_id'=>$media], $owner['token'])->status());
        self::assertSame(200, $this->request('PATCH', "/api/v1/albums/$album", ['cover_media_id'=>$media], $owner['token'])->status());
        self::assertCount(1, $this->request('GET', "/api/v1/albums/$album", [], $owner['token'])->data()['photos']['items']);
        \Circle\Core\Database::execute("UPDATE memories SET status='hidden' WHERE id=:id", ['id'=>$memory]);
        $detail = $this->request('GET', "/api/v1/albums/$album", [], $owner['token'])->data();
        self::assertSame([], $detail['photos']['items']);
        self::assertNull($detail['cover_media_id']);
        self::assertSame(0, $detail['photo_count']);
    }
}
