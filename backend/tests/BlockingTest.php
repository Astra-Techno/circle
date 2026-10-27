<?php

declare(strict_types=1);
namespace Circle\Tests;
use Circle\Core\Database;
final class BlockingTest extends MediaTestCase
{
    public function testDirectContactBlockKeepsGroupContentMediaAndDirectoryVisible(): void
    {
        $owner=$this->user('Owner');$member=$this->user('Member');$third=$this->user('Third');$gid=$this->createGroup($owner);$this->join($owner,$member,$gid);$this->join($owner,$third,$gid);
        $media=$this->readyMedia($member,$gid);$mid=$this->memoryWithMedia($member,$gid,[$media],'Member Memory')->data()['id'];
        $own=$this->createMemory($owner,$gid,'Owner Memory');$neutral=$this->createMemory($third,$gid,'Neutral Memory');
        $comment=$this->request('POST',"/api/v1/memories/$neutral/comments",['body'=>'Member comment'],$member['token'])->data()['id'];
        $this->request('POST',"/api/v1/memories/$neutral/comments",['body'=>'reply','parent_id'=>$comment],$owner['token']);
        $url=$this->link($owner,$media)->data()['url'];self::assertSame(200,$this->download($url)->status());
        foreach([1,2] as $_)self::assertSame(200,$this->request('PUT',"/api/v1/me/blocks/{$member['id']}",[],$owner['token'])->status());
        self::assertSame(1,(int)Database::queryOne('SELECT COUNT(*) n FROM user_blocks')['n']);
        self::assertTrue($this->request('GET',"/api/v1/me/blocks/{$member['id']}",[],$owner['token'])->data()['blocked']);
        self::assertFalse($this->request('GET',"/api/v1/me/blocks/{$owner['id']}",[],$member['token'])->data()['blocked']);
        self::assertSame(200,$this->download($url)->status());self::assertSame(200,$this->link($owner,$media)->status());
        self::assertSame(200,$this->request('GET',"/api/v1/memories/$mid",[],$owner['token'])->status());
        self::assertSame(200,$this->request('GET',"/api/v1/memories/$own",[],$member['token'])->status());
        self::assertSame(200,$this->request('GET',"/api/v1/memories/$mid",[],$third['token'])->status());
        self::assertCount(2,$this->request('GET',"/api/v1/memories/$neutral",[],$owner['token'])->data()['comments']);
        Database::execute('INSERT INTO saves(memory_id,user_id) VALUES(:mid,:uid)',['mid'=>$mid,'uid'=>$owner['id']]);
        foreach (['?saved=true','?q=Member',"?group_id=$gid"] as $query) {
            $items=$this->request('GET','/api/v1/memories'.$query,[],$owner['token'])->data();
            self::assertContains($mid,array_column($items,'id'));
        }
        $directory=$this->request('GET',"/api/v1/groups/$gid/members",[],$owner['token'])->data();
        $row=array_values(array_filter($directory,static fn(array $r):bool=>$r['id']===$member['id']))[0];self::assertSame('Member',$row['display_name']);self::assertSame('member',$row['role']);
        self::assertSame(422,$this->request('PUT',"/api/v1/me/blocks/{$owner['id']}",[],$owner['token'])->status());
        $outsider=$this->user('Outsider');self::assertSame(404,$this->request('PUT',"/api/v1/me/blocks/{$outsider['id']}",[],$owner['token'])->status());
        foreach([1,2] as $_)self::assertSame(200,$this->request('DELETE',"/api/v1/me/blocks/{$member['id']}",[],$owner['token'])->status());
        self::assertSame(200,$this->link($owner,$media)->status());self::assertSame(200,$this->download($url)->status());
        self::assertCount(2,$this->request('GET',"/api/v1/memories/$neutral",[],$owner['token'])->data()['comments']);
    }
    public function testPersonalPhotosAndReceivedInviterWithoutSharedGroup(): void
    {
        $owner=$this->user('Inviter');$member=$this->user('Recipient');$gid=$this->createGroup($owner);
        $invite=$this->request('POST',"/api/v1/groups/$gid/contact-invitations",['mobile'=>$member['mobile']],$owner['token']);self::assertSame(200,$invite->status());
        self::assertSame(200,$this->request('PUT',"/api/v1/me/blocks/{$owner['id']}",[],$member['token'])->status());
        self::assertSame(404,$this->request('GET',"/api/v1/group-invitations/{$invite->data()['invitation_id']}",[],$member['token'])->status());
        $this->request('DELETE',"/api/v1/me/blocks/{$owner['id']}",[],$member['token']);$this->join($owner,$member,$gid);
        foreach(['avatar','cover'] as $kind) {
            self::assertSame(200,$this->requestRaw('PUT',"/api/v1/me/photos/$kind",\Circle\Tests\Support\ImageFixtures::png(),$owner['token'],'image/png')->status());
            self::assertSame(200,$this->request('GET',"/api/v1/profiles/{$owner['id']}/photos/$kind",[],$member['token'])->status());
        }
        $this->request('PUT',"/api/v1/me/blocks/{$owner['id']}",[],$member['token']);
        foreach(['avatar','cover'] as $kind) {
            self::assertSame(200,$this->request('GET',"/api/v1/profiles/{$owner['id']}/photos/$kind",[],$member['token'])->status());
            self::assertSame(200,$this->request('GET',"/api/v1/me/photos/$kind",[],$owner['token'])->status());
        }
        $this->request('POST','/api/v1/auth/logout',[],$member['token']);self::assertSame(401,$this->request('DELETE',"/api/v1/me/blocks/{$owner['id']}",[],$member['token'])->status());
    }

    public function testPrivateListSnapshotAndBlockingInvalidatesPendingInvitation(): void
    {
        $owner=$this->user('Owner');$member=$this->user('Original name');$gid=$this->createGroup($owner);$this->join($owner,$member,$gid);$other=$this->createGroup($owner);
        $invite=$this->request('POST',"/api/v1/groups/$other/contact-invitations",['mobile'=>$member['mobile']],$owner['token']);
        self::assertSame(200,$invite->status());$id=$invite->data()['invitation_id'];
        $this->request('PUT',"/api/v1/me/blocks/{$owner['id']}",[],$member['token']);
        self::assertSame(404,$this->request('GET',"/api/v1/group-invitations/$id",[],$member['token'])->status());
        self::assertSame(404,$this->request('POST',"/api/v1/group-invitations/$id/accept",[],$member['token'])->status());
        self::assertSame([],$this->request('GET','/api/v1/me/group-invitations',[],$member['token'])->data());
        self::assertSame('unavailable',$this->request('POST',"/api/v1/groups/$other/contact-invitations",['mobile'=>$member['mobile']],$owner['token'])->data()['outcome']);
        Database::execute("UPDATE users SET display_name='Changed after block' WHERE id=:id",['id'=>$owner['id']]);
        $list=$this->request('GET','/api/v1/me/blocks',[],$member['token']);self::assertSame('private, no-store',$list->header('Cache-Control'));self::assertSame('Owner',$list->data()['items'][0]['display_name']);
        $this->request('DELETE',"/api/v1/me/blocks/{$owner['id']}",[],$member['token']);
        self::assertSame('expired',$this->request('GET',"/api/v1/group-invitations/$id",[],$member['token'])->data()['invitation']['status']);
    }
}
