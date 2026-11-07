<?php
declare(strict_types=1);
namespace Circle\Tests;
use Circle\Core\Database;
use Circle\Core\Migrator;
final class EventMemoryCardTest extends ApiTestCase
{
    public function testPublicationRetriesPrivateCountsUpdatesAndIndependentDeletion():void
    {
        $a=$this->user('Fictional organizer');$b=$this->user('Fictional guest');$outsider=$this->user();$g=$this->createGroup($a);$this->join($a,$b,$g);
        $body=['title'=>'Fictional weekend','venue'=>'Fictional park','start_at'=>'2030-11-01T07:00:00Z','timezone'=>'UTC','client_id'=>'fictional-event-card-123'];
        $r=$this->request('POST',"/api/v1/groups/$g/events",$body,$a['token']);self::assertSame(200,$r->status());$id=$r->data()['id'];
        self::assertSame($id,$this->request('POST',"/api/v1/groups/$g/events",$body,$a['token'])->data()['id']);
        $rows=$this->request('GET',"/api/v1/memories?group_id=$g",[],$b['token'])->data();self::assertCount(1,$rows);$m=$rows[0];self::assertSame($a['id'],$m['author_id']);self::assertSame($id,$m['events'][0]['id']);self::assertSame(0,$m['events'][0]['going_count']);
        $mid=$m['id'];self::assertSame(404,$this->request('GET',"/api/v1/memories/$mid",[],$outsider['token'])->status());
        self::assertSame(200,$this->request('PUT',"/api/v1/events/$id/rsvp",['status'=>'going','guest_count'=>2,'note'=>'Private fictional note'],$b['token'])->status());
        $event=$this->request('GET',"/api/v1/memories/$mid",[],$b['token'])->data()['events'][0];self::assertSame(3,$event['going_count']);self::assertArrayNotHasKey('note',$event);self::assertArrayNotHasKey('my_rsvp',$event);
        self::assertSame(200,$this->request('PATCH',"/api/v1/events/$id",['version'=>1,'title'=>'Fictional changed title','status'=>'cancelled'],$a['token'])->status());
        $changed=$this->request('GET',"/api/v1/memories/$mid",[],$b['token'])->data();self::assertSame('cancelled',$changed['events'][0]['status']);self::assertSame('Fictional changed title',$changed['body']);
        $this->request('POST',"/api/v1/memories/$mid/save",[],$b['token']);self::assertSame($id,$this->request('GET','/api/v1/memories?saved=true',[],$b['token'])->data()[0]['events'][0]['id']);
        self::assertSame(200,$this->request('DELETE',"/api/v1/memories/$mid",[],$a['token'])->status());self::assertSame(200,$this->request('GET',"/api/v1/events/$id",[],$b['token'])->status());self::assertSame(1,(int)Database::queryOne('SELECT COUNT(*) n FROM event_rsvps WHERE event_id=:id',['id'=>$id])['n']);
    }
    public function testBackfillAndPageQueriesAreBounded():void
    {
        $a=$this->user();$g=$this->createGroup($a);
        for($i=0;$i<10;$i++)$this->request('POST',"/api/v1/groups/$g/events",['title'=>'Fictional card '.$i,'venue'=>'Fictional park','start_at'=>'2030-11-01T07:00:00Z','timezone'=>'UTC','client_id'=>'fictional-card-batch-'.$i],$a['token']);
        $e=Database::queryOne('SELECT id,created_at FROM events ORDER BY id LIMIT 1');Database::execute('DELETE FROM memories WHERE source_event_id=:id',['id'=>$e['id']]);
        $sql=file_get_contents(__DIR__.'/../database/migrations/025_event_memory_cards.sql');self::assertIsString($sql);$statements=Migrator::split($sql);foreach([1,2] as $_)foreach(array_slice($statements,1) as $statement)Database::connection()->exec($statement);
        self::assertSame(10,(int)Database::queryOne('SELECT COUNT(*) n FROM memories WHERE source_event_id IS NOT NULL')['n']);self::assertSame($e['created_at'],Database::queryOne('SELECT created_at FROM memories WHERE source_event_id=:id',['id'=>$e['id']])['created_at']);
        $count=static fn():int=>(int)Database::queryOne("SHOW SESSION STATUS LIKE 'Com_select'")['Value'];
        foreach(['/api/v1/memories','/api/v1/events'] as $path){$before=$count();$one=$this->request('GET',$path.'?limit=1',[],$a['token']);$small=$count()-$before;$before=$count();$many=$this->request('GET',$path.'?limit=10',[],$a['token']);$large=$count()-$before;self::assertSame(200,$one->status());self::assertSame(200,$many->status());self::assertLessThanOrEqual($small+1,$large);}
    }
}
