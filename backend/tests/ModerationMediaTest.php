<?php

declare(strict_types=1);
namespace Circle\Tests;
use Circle\Core\Database;
final class ModerationMediaTest extends MediaTestCase
{
    public function testHideRevokesPreviouslySignedBytesAndRestoreNeverResurrectsDeletedContent(): void
    {
        $owner=$this->user(); $member=$this->user('Member'); $gid=$this->createGroup($owner); $this->join($owner,$member,$gid);
        $media=$this->readyMedia($member,$gid);
        $mid=$this->memoryWithMedia($member,$gid,[$media],'Fictional media')->data()['id'];
        $url=$this->request('GET',"/api/v1/media/$media",[],$owner['token'])->data()['url'];
        self::assertSame(200,$this->request('GET','/api/v1'.$url)->status());
        $this->request('POST',"/api/v1/groups/$gid/reports",['kind'=>'memory','target_id'=>$mid,'reason'=>'spam'],$owner['token']);
        $item=$this->request('GET',"/api/v1/groups/$gid/reports",[],$owner['token'])->data()['items'][0];
        $path="/api/v1/groups/$gid/reports/{$item['id']}/actions";
        self::assertSame(200,$this->request('POST',$path,['action'=>'hide','version'=>$item['version']],$owner['token'])->status());
        self::assertSame(404,$this->request('GET','/api/v1'.$url)->status());
        self::assertSame(404,$this->request('GET',"/api/v1/media/$media",[],$owner['token'])->status());
        self::assertSame(200,$this->request('POST',$path,['action'=>'unhide','version'=>$item['version']+1],$owner['token'])->status());
        self::assertSame(200,$this->request('GET','/api/v1'.$url)->status());
        self::assertSame(200,$this->request('DELETE',"/api/v1/memories/$mid",[],$member['token'])->status());
        self::assertSame(409,$this->request('POST',$path,['action'=>'unhide','version'=>$item['version']+2],$owner['token'])->status());
        self::assertSame(404,$this->request('GET','/api/v1'.$url)->status());
        self::assertSame('removed',Database::queryOne('SELECT status FROM memories WHERE id=:id',['id'=>$mid])['status']);
    }
}
