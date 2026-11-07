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
    public function testPollPublicationUsesMemoryPaginationAndPreservesVisibility():void
    {
        $owner=$this->user('Fictional owner');$viewer=$this->user('Fictional viewer');$other=$this->user('Fictional outsider');
        $g=$this->createGroup($owner);$this->join($owner,$viewer,$g);
        $body=['question'=>'Fictional card?','options'=>['Park','Cafe'],'results_visibility'=>'after_voting','anonymous'=>true,'client_id'=>'fictional-card-idempotent'];
        $first=$this->request('POST',"/api/v1/groups/$g/polls",$body,$owner['token']);$id=$first->data()['id'];
        $again=$this->request('POST',"/api/v1/groups/$g/polls",$body,$owner['token']);self::assertSame($id,$again->data()['id']);
        $page=$this->request('GET',"/api/v1/memories?group_id=$g",[],$viewer['token'])->data();self::assertCount(1,$page);
        $memory=$page[0];self::assertSame($owner['id'],$memory['author_id']);self::assertCount(1,$memory['polls']);
        $poll=$memory['polls'][0];self::assertSame($id,$poll['id']);self::assertSame($memory['id'],$poll['memory_id']);self::assertFalse($poll['results_available']);self::assertNull($poll['voter_count']);
        foreach($poll['options'] as $o)self::assertArrayNotHasKey('votes',$o);
        $mid=$memory['id'];self::assertSame($id,$this->request('GET',"/api/v1/memories/$mid",[],$viewer['token'])->data()['polls'][0]['id']);
        self::assertSame(404,$this->request('GET',"/api/v1/memories/$mid",[],$other['token'])->status());
        $this->request('POST',"/api/v1/memories/$mid/save",[],$viewer['token']);
        $saved=$this->request('GET','/api/v1/memories?saved=true',[],$viewer['token']);self::assertSame($id,$saved->data()[0]['polls'][0]['id']);
        $this->request('PUT',"/api/v1/polls/$id/votes",['option_ids'=>[$poll['options'][0]['id']]],$viewer['token']);
        $voted=$this->request('GET',"/api/v1/memories/$mid",[],$viewer['token'])->data()['polls'][0];self::assertTrue($voted['results_available']);self::assertSame(1,$voted['voter_count']);
        self::assertSame(403,$this->request('GET',"/api/v1/polls/$id/voters",[],$owner['token'])->status());
        Database::execute("UPDATE memories SET status='hidden' WHERE id=:id",['id'=>$mid]);
        self::assertSame(404,$this->request('GET',"/api/v1/polls/$id",[],$viewer['token'])->status());
        self::assertSame([],$this->request('GET',"/api/v1/memories?group_id=$g",[],$viewer['token'])->data());
    }
    public function testPublicationBackfillPreservesTimeAndDoesNotDuplicateOnRetry():void
    {
        $a=$this->user();$g=$this->createGroup($a);$id=$this->poll($a,$g);
        $p=Database::queryOne('SELECT memory_id FROM polls WHERE id=:p',['p'=>$id]);
        Database::execute('UPDATE polls SET memory_id=NULL,created_at=:t WHERE id=:p',['p'=>$id,'t'=>'2026-01-02 03:04:05']);
        Database::execute('DELETE FROM memories WHERE id=:m',['m'=>$p['memory_id']]);
        $sql=file_get_contents(__DIR__.'/../database/migrations/024_poll_memory_cards.sql');self::assertIsString($sql);
        $statements=\Circle\Core\Migrator::split($sql);
        foreach([1,2] as $_)foreach(array_slice($statements,1) as $statement)Database::connection()->exec($statement);
        $rows=Database::query('SELECT m.* FROM memories m JOIN polls p ON p.memory_id=m.id WHERE p.id=:p',['p'=>$id]);self::assertCount(1,$rows);self::assertSame('2026-01-02 03:04:05',$rows[0]['created_at']);self::assertSame($a['id'],(int)$rows[0]['author_id']);
    }

    public function testListQueryCountIsBoundedAndHiddenResultsStayPrivate():void
    {
        $owner=$this->user('Fictional owner');$viewer=$this->user('Fictional viewer');$g=$this->createGroup($owner);$this->join($owner,$viewer,$g);
        for($i=0;$i<10;$i++)$this->poll($owner,$g,['results_visibility'=>'after_voting']);
        $count=static fn():int=>(int)(Database::queryOne("SHOW SESSION STATUS LIKE 'Com_select'")['Value']??0);
        $before=$count();$one=$this->request('GET','/api/v1/polls?limit=1',[],$viewer['token']);$small=$count()-$before;
        $before=$count();$many=$this->request('GET','/api/v1/polls?limit=10',[],$viewer['token']);$large=$count()-$before;
        self::assertCount(1,$one->data()['items']);self::assertCount(10,$many->data()['items']);
        foreach($many->data()['items'] as $poll){
            self::assertFalse($poll['results_available']);self::assertNull($poll['voter_count']);self::assertFalse($poll['can_manage']);
            foreach($poll['options'] as $option){self::assertArrayNotHasKey('votes',$option);self::assertArrayNotHasKey('poll_id',$option);}
        }
        self::assertLessThanOrEqual($small+1,$large,'Poll pages must not query per poll.');
        $before=$count();$oneMemory=$this->request('GET','/api/v1/memories?limit=1',[],$viewer['token']);$smallMemory=$count()-$before;
        $before=$count();$manyMemory=$this->request('GET','/api/v1/memories?limit=10',[],$viewer['token']);$largeMemory=$count()-$before;
        self::assertCount(1,$oneMemory->data());self::assertCount(10,$manyMemory->data());
        self::assertLessThanOrEqual($smallMemory+1,$largeMemory,'Memory poll cards must batch all projection queries.');
        foreach($manyMemory->data() as $m)foreach($m['polls'] as $p){self::assertFalse($p['results_available']);self::assertNull($p['voter_count']);}

        if(getenv('CIRCLE_TEST_QUERY_METRICS')==='true')fwrite(STDERR,sprintf("Poll SELECTs:1 poll=%d;10 polls=%d\n",$small,$large));
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
