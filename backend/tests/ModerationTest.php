<?php

declare(strict_types=1);
namespace Circle\Tests;
use Circle\Core\Database;

final class ModerationTest extends ApiTestCase
{
    public function testReportsArePersistentAnonymousIdempotentAndExactGroupAdminOnly(): void
    {
        $owner=$this->user('Owner'); $writer=$this->user('Writer'); $reporter=$this->user('Secret reporter'); $stranger=$this->user('Stranger');
        $gid=$this->createGroup($owner); $other=$this->createGroup($stranger);
        foreach ([$writer,$reporter] as $user) Database::execute("INSERT INTO group_members(group_id,user_id,role,status) VALUES(:g,:u,'member','active')",['g'=>$gid,'u'=>$user['id']]);
        $mid=$this->request('POST',"/api/v1/groups/$gid/memories",['body'=>'Fictional item'],$writer['token'])->data()['id'];
        $draft=['kind'=>'memory','target_id'=>$mid,'reason'=>'spam','note'=>'Secret reporter note'];
        foreach ([1,2] as $_) self::assertSame(200,$this->request('POST',"/api/v1/groups/$gid/reports",$draft,$reporter['token'])->status());
        self::assertSame(1,(int)Database::queryOne('SELECT COUNT(*) n FROM reports')['n']);
        self::assertSame(403,$this->request('GET',"/api/v1/groups/$gid/reports",[],$reporter['token'])->status());
        self::assertSame(403,$this->request('POST',"/api/v1/groups/$gid/reports",$draft,$stranger['token'])->status());
        self::assertSame(404,$this->request('POST',"/api/v1/groups/$other/reports",$draft,$stranger['token'])->status());
        self::assertSame(422,$this->request('POST',"/api/v1/groups/$gid/reports",$draft,$writer['token'])->status());
        $queue=$this->request('GET',"/api/v1/groups/$gid/reports",[],$owner['token']);
        self::assertSame('private, no-store',$queue->header('Cache-Control'));
        $body=json_encode($queue->json(),JSON_THROW_ON_ERROR); self::assertStringNotContainsString('reporter',$body); self::assertStringNotContainsString('Secret',$body); self::assertStringNotContainsString('note',$body);
        $item=$queue->data()['items'][0]; self::assertSame([['reason'=>'spam','count'=>1]],$item['reasons']);
        $action="/api/v1/groups/$gid/reports/{$item['id']}/actions";
        self::assertSame(403,$this->request('POST',$action,['action'=>'hide','version'=>$item['version']],$reporter['token'])->status());
        self::assertSame(200,$this->request('POST',$action,['action'=>'hide','version'=>$item['version']],$owner['token'])->status());
        self::assertSame(409,$this->request('POST',$action,['action'=>'unhide','version'=>$item['version']],$owner['token'])->status());
        foreach ([$owner,$writer,$reporter] as $user) self::assertSame(404,$this->request('GET',"/api/v1/memories/$mid",[],$user['token'])->status());
        foreach (['','?saved=true','?q=Fictional',"?group_id=$gid"] as $filter) self::assertSame([],$this->request('GET','/api/v1/memories'.$filter,[],$reporter['token'])->data());
        self::assertSame(404,$this->request('POST',"/api/v1/memories/$mid/comments",['body'=>'reply'],$writer['token'])->status());
        foreach (['dismiss','unhide','restore'] as $operation) {
            $item=$this->request('GET',"/api/v1/groups/$gid/reports",[],$owner['token'])->data()['items'][0];
            self::assertSame(200,$this->request('POST',$action,['action'=>$operation,'version'=>$item['version']],$owner['token'])->status());
            if ($operation==='unhide') break;
        }
        self::assertSame(200,$this->request('GET',"/api/v1/memories/$mid",[],$reporter['token'])->status());
        self::assertCount(3,$this->request('GET',"/api/v1/groups/$gid/reports",[],$owner['token'])->data()['audit']);
    }

    public function testMemberReportsValidationPaginationRateLimitAndRoleRevocation(): void
    {
        $owner=$this->user(); $reporter=$this->user('Reporter'); $gid=$this->createGroup($owner); $this->join($owner,$reporter,$gid);
        $draft=['kind'=>'member','target_id'=>$owner['id'],'reason'=>'harassment'];
        foreach ([['kind'=>'event'],['target_id'=>'1'],['reason'=>'invalid'],['note'=>['bad']],['note'=>str_repeat('x',501)]] as $invalid) self::assertSame(422,$this->request('POST',"/api/v1/groups/$gid/reports",[...$draft,...$invalid],$reporter['token'])->status());
        self::assertSame(200,$this->request('POST',"/api/v1/groups/$gid/reports",$draft,$reporter['token'])->status());
        for ($i=0;$i<9;$i++) {
            $mid=$this->createMemory($owner,$gid,'Fictional '.$i);
            self::assertSame(200,$this->request('POST',"/api/v1/groups/$gid/reports",['kind'=>'memory','target_id'=>$mid,'reason'=>'spam'],$reporter['token'])->status());
        }
        $extra=$this->createMemory($owner,$gid,'Extra');
        self::assertSame(429,$this->request('POST',"/api/v1/groups/$gid/reports",['kind'=>'memory','target_id'=>$extra,'reason'=>'spam'],$reporter['token'])->status());
        self::assertSame(200,$this->request('POST',"/api/v1/groups/$gid/reports",$draft,$reporter['token'])->status());
        $page=$this->request('GET',"/api/v1/groups/$gid/reports?limit=1",[],$owner['token'])->data(); self::assertTrue($page['has_more']);self::assertCount(1,$page['items']);
        $next=$this->request('GET',"/api/v1/groups/$gid/reports?limit=1&offset=1",[],$owner['token'])->data();self::assertNotSame($page['items'][0]['id'],$next['items'][0]['id']);
        $item=$page['items'][0];
        Database::execute("UPDATE group_members SET role='member' WHERE group_id=:g AND user_id=:u",['g'=>$gid,'u'=>$owner['id']]);
        self::assertSame(403,$this->request('GET',"/api/v1/groups/$gid/reports",[],$owner['token'])->status());
        self::assertSame(403,$this->request('POST',"/api/v1/groups/$gid/reports/{$item['id']}/actions",['action'=>'hide','version'=>$item['version']],$owner['token'])->status());
        $this->request('POST','/api/v1/auth/logout',[],$reporter['token']);
        self::assertSame(401,$this->request('POST',"/api/v1/groups/$gid/reports",$draft,$reporter['token'])->status());
    }

    public function testReplyDepthCannotBreakVisibleCommentQueries(): void
    {
        $owner=$this->user(); $gid=$this->createGroup($owner); $mid=$this->createMemory($owner,$gid,'Fictional deep thread');
        $parent=null;
        for ($depth=0;$depth<32;$depth++) {
            $reply=$this->request('POST',"/api/v1/memories/$mid/comments",['body'=>'Level '.$depth,'parent_id'=>$parent],$owner['token']);
            self::assertSame(201,$reply->status()); $parent=$reply->data()['id'];
        }
        self::assertSame(422,$this->request('POST',"/api/v1/memories/$mid/comments",['body'=>'Too deep','parent_id'=>$parent],$owner['token'])->status());
        self::assertCount(32,$this->request('GET',"/api/v1/memories/$mid",[],$owner['token'])->data()['comments']);
        self::assertSame(32,$this->request('GET','/api/v1/memories',[],$owner['token'])->data()[0]['comment_count']);
    }

    public function testHiddenParentSuppressesRepliesCountsAndNewRepliesWithoutUndoingIndependentHides(): void
    {
        $owner=$this->user(); $writer=$this->user('Writer'); $reporter=$this->user('Reporter'); $gid=$this->createGroup($owner);
        foreach ([$writer,$reporter] as $user) Database::execute("INSERT INTO group_members(group_id,user_id,role,status) VALUES(:g,:u,'member','active')",['g'=>$gid,'u'=>$user['id']]);
        $mid=$this->request('POST',"/api/v1/groups/$gid/memories",['body'=>'Fictional'],$owner['token'])->data()['id'];
        $root=$this->request('POST',"/api/v1/memories/$mid/comments",['body'=>'root'],$writer['token'])->data()['id'];
        $child=$this->request('POST',"/api/v1/memories/$mid/comments",['body'=>'child','parent_id'=>$root],$writer['token'])->data()['id'];
        foreach ([$child,$root] as $cid) {
            self::assertSame(200,$this->request('POST',"/api/v1/groups/$gid/reports",['kind'=>'comment','target_id'=>$cid,'reason'=>'privateInfo'],$reporter['token'])->status());
            $items=$this->request('GET',"/api/v1/groups/$gid/reports",[],$owner['token'])->data()['items'];
            $item=array_values(array_filter($items,static fn(array $i):bool=>$i['target_id']===$cid))[0];
            self::assertSame(200,$this->request('POST',"/api/v1/groups/$gid/reports/{$item['id']}/actions",['action'=>'hide','version'=>$item['version']],$owner['token'])->status());
        }
        self::assertSame([],$this->request('GET',"/api/v1/memories/$mid",[],$reporter['token'])->data()['comments']);
        self::assertSame(0,$this->request('GET','/api/v1/memories',[],$reporter['token'])->data()[0]['comment_count']);
        self::assertSame(422,$this->request('POST',"/api/v1/memories/$mid/comments",['body'=>'forbidden','parent_id'=>$child],$writer['token'])->status());
        $items=$this->request('GET',"/api/v1/groups/$gid/reports",[],$owner['token'])->data()['items'];
        $item=array_values(array_filter($items,static fn(array $i):bool=>$i['target_id']===$root))[0];
        self::assertSame(200,$this->request('POST',"/api/v1/groups/$gid/reports/{$item['id']}/actions",['action'=>'unhide','version'=>$item['version']],$owner['token'])->status());
        self::assertCount(1,$this->request('GET',"/api/v1/memories/$mid",[],$reporter['token'])->data()['comments']);
        self::assertSame(200,$this->request('DELETE',"/api/v1/memories/$mid",[],$owner['token'])->status());
        $removed=$this->request('GET',"/api/v1/groups/$gid/reports",[],$owner['token'])->data()['items'];
        foreach ($removed as $case) {
            self::assertFalse($case['available']);
            self::assertSame(200,$this->request('POST',"/api/v1/groups/$gid/reports/{$case['id']}/actions",['action'=>'dismiss','version'=>$case['version']],$owner['token'])->status());
        }
        self::assertSame([],$this->request('GET',"/api/v1/groups/$gid/reports",[],$owner['token'])->data()['items']);
        $parent=$this->createGroup($owner); $parentOnly=$this->user('Parent admin');
        Database::execute("INSERT INTO group_members(group_id,user_id,role,status) VALUES(:g,:u,'admin','active')",['g'=>$parent,'u'=>$parentOnly['id']]);
        self::assertSame(403,$this->request('GET',"/api/v1/groups/$gid/reports",[],$parentOnly['token'])->status());
    }
}
