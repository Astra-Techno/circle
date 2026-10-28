<?php

declare(strict_types=1);
namespace Circle\Tests;
use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Notifications\NotificationWorker;
use Circle\Notifications\PushTransport;
use Circle\Notifications\PushResult;
use Circle\Repositories\MemberRepository;
final class PollTransport implements PushTransport {
    /** @var list<array<string,string>> */ public array $calls=[];
    public function isReady():bool{return true;}
    public function send(string $token,array $data):PushResult{$this->calls[]=$data;return PushResult::sent();}
}
final class PollTest extends ApiTestCase
{
    /** @param array{token:string} $u
     * @param array<string,mixed> $fields */
    private function poll(array $u,int $group,array $fields=[]):int {
        $r=$this->request('POST',"/api/v1/groups/$group/polls",['question'=>'Fictional lunch?','options'=>['Park','Cafe'],'client_id'=>'fictional-poll-'.bin2hex(random_bytes(8)),...$fields],$u['token']);self::assertSame(200,$r->status(),json_encode($r->json())?:'');return $r->data()['id'];
    }
    public function testCreateRetryValidationAndExactGroupAuthorization():void
    {
        $a=$this->user('Owner');$b=$this->user('Parent member');$g=$this->createGroup($a);$child=$this->createGroup($a,'Private child',$g);$this->join($a,$b,$g);
        $body=['question'=>'Fictional plan?','options'=>['A','B'],'client_id'=>'fictional-poll-retry-01'];$first=$this->request('POST',"/api/v1/groups/$child/polls",$body,$a['token']);self::assertSame(200,$first->status());$id=$first->data()['id'];self::assertSame($id,$this->request('POST',"/api/v1/groups/$child/polls",$body,$a['token'])->data()['id']);self::assertSame(409,$this->request('POST',"/api/v1/groups/$child/polls",[...$body,'question'=>'Different'],$a['token'])->status());
        self::assertSame(404,$this->request('GET',"/api/v1/polls/$id",[],$b['token'])->status());self::assertSame([],$this->request('GET','/api/v1/polls',[],$b['token'])->data()['items']);self::assertSame(403,$this->request('POST',"/api/v1/groups/$child/polls",$body,$b['token'])->status());
        foreach([['options'=>['A']],['options'=>['A',' a ']],['anonymous'=>'false'],['closes_at'=>'2030-02-30T12:00:00Z'],['closes_at'=>'2040-01-01T12:00:00Z'],['question'=>'  '],['unknown'=>true]] as $change)self::assertSame(422,$this->request('POST',"/api/v1/groups/$g/polls",[...$body,...$change],$a['token'])->status());
    }
    public function testSingleMultipleVotesRetriesForeignOptionsAndVoteChangePolicy():void
    {
        $a=$this->user();$b=$this->user('Member');$g=$this->createGroup($a);$this->join($a,$b,$g);$id=$this->poll($a,$g,['allow_change_vote'=>false]);$path="/api/v1/polls/$id";$options=array_column($this->request('GET',$path,[],$b['token'])->data()['options'],'id');
        self::assertSame(422,$this->request('PUT',"$path/votes",['option_ids'=>$options],$b['token'])->status());foreach([1,2] as $_)self::assertSame(200,$this->request('PUT',"$path/votes",['option_ids'=>[$options[0]]],$b['token'])->status());self::assertSame(409,$this->request('PUT',"$path/votes",['option_ids'=>[]],$b['token'])->status());
        self::assertSame(1,$this->request('GET',$path,[],$a['token'])->data()['voter_count']);$other=$this->poll($a,$g,['poll_type'=>'multiple']);$foreign=array_column($this->request('GET',"/api/v1/polls/$other",[],$a['token'])->data()['options'],'id');self::assertSame(422,$this->request('PUT',"/api/v1/polls/$other/votes",['option_ids'=>[$options[0]]],$a['token'])->status());self::assertSame(200,$this->request('PUT',"/api/v1/polls/$other/votes",['option_ids'=>$foreign],$a['token'])->status());self::assertSame(200,$this->request('PUT',"/api/v1/polls/$other/votes",['option_ids'=>[]],$a['token'])->status());
        self::assertSame(422,$this->request('PUT',"$path/votes",['option_ids'=>[$options[0],$options[0]]],$a['token'])->status());
        Database::transaction(static fn()=>MemberRepository::removeMember($g,$b['id'],'left'));self::assertSame(404,$this->request('PUT',"$path/votes",['option_ids'=>[]],$b['token'])->status());
    }
    public function testHiddenResultsAnonymousVotersCloseAndMemberOptions():void
    {
        $a=$this->user();$b=$this->user('Member');$g=$this->createGroup($a);$this->join($a,$b,$g);$id=$this->poll($a,$g,['anonymous'=>true,'results_visibility'=>'after_closing','allow_add_options'=>true]);$path="/api/v1/polls/$id";$p=$this->request('GET',$path,[],$b['token'])->data();self::assertNull($p['voter_count']);self::assertArrayNotHasKey('votes',$p['options'][0]);self::assertFalse($p['results_available']);
        self::assertSame(200,$this->request('POST',"$path/options",['label'=>'Beach'],$b['token'])->status());self::assertSame(200,$this->request('POST',"$path/options",['label'=>' beach '],$b['token'])->status());self::assertCount(3,$this->request('GET',$path,[],$a['token'])->data()['options']);
        $this->request('PUT',"$path/votes",['option_ids'=>[$p['options'][0]['id']]],$b['token']);self::assertSame(403,$this->request('GET',"$path/voters",[],$a['token'])->status());self::assertSame(403,$this->request('POST',"$path/close",[],$b['token'])->status());foreach([1,2] as $_)self::assertSame(200,$this->request('POST',"$path/close",[],$a['token'])->status());self::assertTrue($this->request('GET',$path,[],$b['token'])->data()['results_available']);self::assertSame(403,$this->request('GET',"$path/voters",[],$a['token'])->status());self::assertSame(409,$this->request('POST',"$path/options",['label'=>'Later'],$a['token'])->status());
    }
    public function testAfterVotingResultsNamedVotersExpiryAndContextCannotCrossGroups():void
    {
        $a=$this->user();$b=$this->user('Member');$g=$this->createGroup($a);$h=$this->createGroup($a);$this->join($a,$b,$g);$id=$this->poll($a,$g,['results_visibility'=>'after_voting']);$path="/api/v1/polls/$id";$p=$this->request('GET',$path,[],$b['token'])->data();self::assertSame(403,$this->request('GET',"$path/voters",[],$b['token'])->status());$this->request('PUT',"$path/votes",['option_ids'=>[$p['options'][0]['id']]],$b['token']);$v=$this->request('GET',"$path/voters",[],$b['token'])->data()['items'][0];self::assertSame('Member',$v['display_name']);self::assertArrayNotHasKey('mobile',$v);$this->request('PUT',"$path/votes",['option_ids'=>[]],$b['token']);self::assertFalse($this->request('GET',$path,[],$b['token'])->data()['results_available']);
        Database::execute('UPDATE polls SET closes_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 SECOND) WHERE id=:id',['id'=>$id]);self::assertTrue($this->request('GET',$path,[],$a['token'])->data()['closed']);self::assertSame(409,$this->request('PUT',"$path/votes",['option_ids'=>[$p['options'][0]['id']]],$a['token'])->status());
        $body=['question'=>'Fictional contextual poll','options'=>['A','B'],'client_id'=>'fictional-context-0001','event_id'=>999999];self::assertSame(404,$this->request('POST',"/api/v1/groups/$h/polls",$body,$a['token'])->status());
    }
    public function testMemoryContextHidingAndEventContextsRemainExactGroup():void
    {
        $a=$this->user();$b=$this->user('Member');$g=$this->createGroup($a);$h=$this->createGroup($a);$this->join($a,$b,$g);
        $m=$this->request('POST',"/api/v1/groups/$g/memories",['body'=>'Fictional memory'],$a['token'])->data()['id'];
        $id=$this->poll($a,$g,['memory_id'=>$m]);
        self::assertSame(404,$this->request('POST',"/api/v1/groups/$h/polls",['question'=>'Private context','options'=>['A','B'],'memory_id'=>$m,'client_id'=>'fictional-cross-context-01'],$a['token'])->status());
        Database::execute("UPDATE memories SET status='hidden' WHERE id=:id",['id'=>$m]);
        self::assertSame(404,$this->request('GET',"/api/v1/polls/$id",[],$b['token'])->status());self::assertSame([],$this->request('GET',"/api/v1/polls?group_id=$g",[],$b['token'])->data()['items']);
        $e=$this->request('POST',"/api/v1/groups/$g/events",['title'=>'Fictional event','venue'=>'Park','timezone'=>'UTC','start_at'=>gmdate('Y-m-d\TH:i:s\Z',time()+86400),'client_id'=>'fictional-poll-event-01'],$a['token'])->data()['id'];
        $this->poll($a,$g,['event_id'=>$e]);
        self::assertSame(404,$this->request('POST',"/api/v1/groups/$h/polls",['question'=>'Wrong event','options'=>['A','B'],'event_id'=>$e,'client_id'=>'fictional-cross-event-01'],$a['token'])->status());
    }
    public function testOptInPollPushReferencesExpiryAndMembershipRechecks():void
    {
        Env::set('PUSH_QUEUE_ENABLED','true');Env::set('PUSH_DELIVERY_ENABLED','true');Env::set('PUSH_API_BASE_URL','https://fictional.example/api/v1');
        try {
            $a=$this->user();$b=$this->user('Member');$g=$this->createGroup($a);$this->join($a,$b,$g);$this->request('PATCH','/api/v1/me/notification-preferences',['enabled'=>true,'quiet_hours'=>false,'categories'=>['polls'=>true]],$b['token']);$this->request('POST','/api/v1/devices/register',['fcm_token'=>'fictional-poll-device','platform'=>'android'],$b['token']);$id=$this->poll($a,$g);$t=new PollTransport();$worker=new NotificationWorker($t);self::assertSame(1,$worker->run()['sent']);self::assertSame('poll.created',$t->calls[0]['type']);self::assertSame((string)$id,$t->calls[0]['poll_ref']);self::assertArrayNotHasKey('question',$t->calls[0]);
            $options=$this->request('GET',"/api/v1/polls/$id",[],$b['token'])->data()['options'];$this->request('PUT',"/api/v1/polls/$id/votes",['option_ids'=>[$options[0]['id']]],$b['token']);self::assertSame(0,$worker->run()['sent']);Database::execute('UPDATE polls SET closes_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 SECOND) WHERE id=:id',['id'=>$id]);self::assertSame(1,$worker->run()['sent']);self::assertSame('poll.closed',$t->calls[1]['type']);self::assertSame(0,$worker->run()['sent']);
            $this->poll($a,$g);Database::transaction(static fn()=>MemberRepository::removeMember($g,$b['id'],'left'));self::assertSame(1,$worker->run()['cancelled']);
        } finally {Env::set('PUSH_QUEUE_ENABLED','false');Env::set('PUSH_DELIVERY_ENABLED','false');Env::set('PUSH_API_BASE_URL','');}
    }
}
