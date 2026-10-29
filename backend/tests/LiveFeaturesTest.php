<?php

declare(strict_types=1);
namespace Circle\Tests;
use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Repositories\MemberRepository;
use Circle\Notifications\NotificationWorker;
use Circle\Notifications\PushTransport;
use Circle\Notifications\PushResult;
final class LiveRecordingTransport implements PushTransport
{
    /** @var list<array<string,string>> */ public array $calls=[];
    public function isReady():bool{return true;}
    public function send(string $token,array $data):PushResult{$this->calls[]=$data;return PushResult::sent();}
}
final class LiveFeaturesTest extends ApiTestCase
{
    protected function setUp():void{parent::setUp();Env::set('PUSH_QUEUE_ENABLED','true');Env::set('PUSH_DELIVERY_ENABLED','true');Env::set('PUSH_API_BASE_URL','https://fictional.example/api/v1');}
    protected function tearDown():void{Env::set('PUSH_QUEUE_ENABLED','false');Env::set('PUSH_DELIVERY_ENABLED','false');Env::set('PUSH_API_BASE_URL','');parent::tearDown();}
    private function chatId(int $g):int{return (int)Database::queryOne('SELECT id FROM conversations WHERE group_id=:g',['g'=>$g])['id'];}
    public function testGroupChatRetryRepliesReceiptsEditAndFrozenVersions():void
    {
        $a=$this->user('Owner');$b=$this->user('Member');$c=$this->user('Outsider');$g=$this->createGroup($a);$this->join($a,$b,$g);$cid=$this->chatId($g);$path="/api/v1/chats/$cid";$send=['body'=>'Fictional original','client_id'=>'fictional-message-0001'];
        $first=$this->request('POST',$path.'/messages',$send,$a['token']);self::assertSame(200,$first->status());$id=$first->data()['id'];self::assertSame($id,$this->request('POST',$path.'/messages',$send,$a['token'])->data()['id']);self::assertSame(409,$this->request('POST',$path.'/messages',[...$send,'body'=>'Changed retry'],$a['token'])->status());
        self::assertSame(404,$this->request('GET',$path,[],$c['token'])->status());self::assertSame(1,$this->request('GET','/api/v1/chats',[],$b['token'])->data()['items'][0]['unread']);
        self::assertSame(200,$this->request('PATCH',$path.'/state',['read_id'=>$id,'muted'=>true,'pinned'=>true],$b['token'])->status());self::assertSame(0,$this->request('GET','/api/v1/chats',[],$b['token'])->data()['items'][0]['unread']);
        Database::transaction(static fn()=>MemberRepository::removeMember($g,$b['id'],'left'));
        self::assertSame(200,$this->request('PATCH',$path.'/messages/'.$id,['body'=>'Edited after departure'],$a['token'])->status());$this->request('POST',$path.'/messages',['body'=>'Later','client_id'=>'fictional-message-0002','reply_to_id'=>$id],$a['token']);
        $frozen=$this->request('GET',$path,[],$b['token'])->data();self::assertFalse($frozen['can_send']);self::assertCount(1,$frozen['items']);self::assertSame('Fictional original',$frozen['items'][0]['body']);self::assertFalse($frozen['items'][0]['edited']);self::assertSame(403,$this->request('POST',$path.'/messages',['body'=>'No','client_id'=>'fictional-message-0003'],$b['token'])->status());
        Database::transaction(static fn()=>MemberRepository::addMember($g,$b['id']));$current=$this->request('GET',$path,[],$b['token'])->data();self::assertSame('Group',$current['name']);self::assertCount(2,$current['items']);self::assertSame('Edited after departure',$current['items'][0]['body']);
        self::assertSame(200,$this->request('PATCH',$path.'/messages/'.$id,['removed'=>true],$a['token'])->status());self::assertSame('',$this->request('GET',$path,[],$b['token'])->data()['items'][0]['body']);self::assertSame(200,$this->request('PATCH',$path.'/messages/'.$id,['removed'=>false],$a['token'])->status());
        self::assertSame(200,$this->request('PUT',$path.'/messages/'.$id.'/reaction',['emoji'=>'❤️'],$b['token'])->status());self::assertCount(1,$this->request('GET',$path,[],$a['token'])->data()['items'][0]['reactions']);self::assertSame(200,$this->request('PUT',$path.'/messages/'.$id.'/reaction',['emoji'=>null],$b['token'])->status());self::assertCount(0,$this->request('GET',$path,[],$a['token'])->data()['items'][0]['reactions']);
    }
    public function testInboxShowsLastVisibleMessageAndOrdersByActivity():void
    {
        $a=$this->user('Owner');$b=$this->user('Member');
        $g1=$this->createGroup($a,'Older');$g2=$this->createGroup($a,'Newer');$this->join($a,$b,$g1);$this->join($a,$b,$g2);
        $first=$this->request('POST','/api/v1/chats/'.$this->chatId($g1).'/messages',['body'=>'Fictional first','client_id'=>'fictional-inbox-0001'],$a['token'])->data()['id'];
        $this->request('POST','/api/v1/chats/'.$this->chatId($g2).'/messages',['body'=>'Fictional second','client_id'=>'fictional-inbox-0002'],$a['token']);
        $items=$this->request('GET','/api/v1/chats',[],$b['token'])->data()['items'];
        self::assertSame(['Newer','Older'],array_column($items,'name'),'latest activity first');
        self::assertSame('Fictional second',$items[0]['last_message']['body']);self::assertSame('Owner',$items[0]['last_message']['author_name']);self::assertSame((int)$a['id'],$items[0]['last_message']['author_id']);
        self::assertMatchesRegularExpression('/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/',$items[0]['last_message']['created_at']);self::assertNull($items[0]['other_id']);
        // A member who left keeps a preview frozen at their cutoff.
        Database::transaction(static fn()=>MemberRepository::removeMember($g2,$b['id'],'left'));
        $this->request('POST','/api/v1/chats/'.$this->chatId($g2).'/messages',['body'=>'Fictional after leaving','client_id'=>'fictional-inbox-0003'],$a['token']);
        $frozen=array_column($this->request('GET','/api/v1/chats',[],$b['token'])->data()['items'],null,'name');
        self::assertSame('Fictional second',$frozen['Newer']['last_message']['body']);
        self::assertSame('Fictional after leaving',array_column($this->request('GET','/api/v1/chats',[],$a['token'])->data()['items'],null,'name')['Newer']['last_message']['body']);
        // An unsent message leaves no text in the preview.
        $this->request('PATCH','/api/v1/chats/'.$this->chatId($g1).'/messages/'.$first,['removed'=>true],$a['token']);
        $older=array_column($this->request('GET','/api/v1/chats',[],$b['token'])->data()['items'],null,'name')['Older']['last_message'];
        self::assertTrue($older['removed']);self::assertSame('',$older['body']);
    }

    public function testDirectRequestsBlocksAndPrivacy():void
    {
        $a=$this->user('A');$b=$this->user('B');$other=$this->user('Other');$g=$this->createGroup($a);$this->join($a,$b,$g);
        $open=$this->request('PUT',"/api/v1/chats/direct/{$b['id']}",[],$a['token']);self::assertSame(200,$open->status());$path='/api/v1/chats/'.$open->data()['id'];$send=['body'=>'Fictional request','client_id'=>'fictional-direct-0001'];
        self::assertSame(200,$this->request('POST',$path.'/messages',$send,$a['token'])->status());self::assertSame(403,$this->request('POST',$path.'/messages',[...$send,'client_id'=>'fictional-direct-0002'],$a['token'])->status());self::assertFalse($this->request('GET',$path,[],$b['token'])->data()['can_send']);
        self::assertSame(403,$this->request('POST',$path.'/request',['action'=>'accept'],$a['token'])->status());self::assertSame(200,$this->request('POST',$path.'/request',['action'=>'accept'],$b['token'])->status());self::assertSame(200,$this->request('POST',$path.'/messages',['body'=>'Accepted reply','client_id'=>'fictional-direct-0003'],$b['token'])->status());self::assertSame(404,$this->request('GET',$path,[],$other['token'])->status());
        $this->request('PUT',"/api/v1/me/blocks/{$a['id']}",[],$b['token']);self::assertSame(403,$this->request('POST',$path.'/messages',[...$send,'client_id'=>'fictional-direct-0004'],$a['token'])->status());self::assertCount(2,$this->request('GET',$path,[],$b['token'])->data()['items']);
        $this->request('DELETE',"/api/v1/me/blocks/{$a['id']}",[],$b['token']);$this->request('PATCH','/api/v1/me/chat-privacy',['who_can_message'=>'none'],$b['token']);self::assertSame(404,$this->request('PUT',"/api/v1/chats/direct/{$b['id']}",[],$a['token'])->status());
    }
    /** @return array<string,mixed> */
    private function draft():array{return ['client_id'=>'fictional-event-00001','title'=>'Fictional picnic','venue'=>'Fictional park','timezone'=>'Asia/Kolkata','start_at'=>gmdate('Y-m-d\TH:i:s\Z',time()+172800),'max_capacity'=>2];}
    public function testEventIdempotencyPermissionsRsvpCapacityNotesAndCancellation():void
    {
        $a=$this->user('Owner');$b=$this->user('Member');$c=$this->user('Outsider');$g=$this->createGroup($a);$this->join($a,$b,$g);$draft=$this->draft();$first=$this->request('POST',"/api/v1/groups/$g/events",$draft,$a['token']);self::assertSame(200,$first->status());$id=$first->data()['id'];$path="/api/v1/events/$id";self::assertSame($id,$this->request('POST',"/api/v1/groups/$g/events",$draft,$a['token'])->data()['id']);
        self::assertSame(404,$this->request('GET',$path,[],$c['token'])->status());self::assertSame(403,$this->request('PATCH',$path,['version'=>1,'title'=>'No'],$b['token'])->status());
        self::assertSame(200,$this->request('PUT',$path.'/rsvp',['status'=>'going','guest_count'=>1,'note'=>'Private RSVP note'],$b['token'])->status());self::assertSame(409,$this->request('PUT',$path.'/rsvp',['status'=>'going'],$a['token'])->status());$attendees=$this->request('GET',$path.'/attendees',[],$a['token'])->data()['items'];self::assertArrayNotHasKey('note',$attendees[0]);self::assertArrayNotHasKey('mobile',$attendees[0]);
        self::assertSame(200,$this->request('PATCH',$path,['version'=>1,'title'=>'Updated picnic'],$a['token'])->status());self::assertSame(409,$this->request('PATCH',$path,['version'=>1,'title'=>'Stale'],$a['token'])->status());self::assertSame(200,$this->request('PATCH',$path,['version'=>2,'status'=>'cancelled'],$a['token'])->status());self::assertSame(409,$this->request('PUT',$path.'/rsvp',['status'=>'maybe'],$b['token'])->status());
        $this->request('PATCH',"/api/v1/groups/$g",['event_creation'=>'admins'],$a['token']);self::assertSame(403,$this->request('POST',"/api/v1/groups/$g/events",[...$draft,'client_id'=>'fictional-event-00002'],$b['token'])->status());
    }
    public function testPushMuteBlockAndObsoleteEventReminderRechecks():void
    {
        $a=$this->user('Owner');$b=$this->user('Member');$g=$this->createGroup($a);$this->join($a,$b,$g);$c=$this->chatId($g);
        $this->request('PATCH','/api/v1/me/notification-preferences',['enabled'=>true,'quiet_hours'=>false,'categories'=>['chats'=>true,'events'=>true]],$b['token']);$this->request('POST','/api/v1/devices/register',['fcm_token'=>'fictional-live-device','platform'=>'android'],$b['token']);
        $first=$this->request('POST',"/api/v1/chats/$c/messages",['body'=>'Private never in push','client_id'=>'fictional-message-0005'],$a['token']);self::assertSame(200,$first->status());$t=new LiveRecordingTransport();$w=new NotificationWorker($t);self::assertSame(1,$w->run()['sent']);self::assertSame('chat.message',$t->calls[0]['type']);self::assertArrayNotHasKey('body',$t->calls[0]);
        $this->request('POST',"/api/v1/chats/$c/messages",['body'=>'Queue then mute','client_id'=>'fictional-message-0006'],$a['token']);$this->request('PATCH',"/api/v1/chats/$c/state",['muted'=>true],$b['token']);self::assertSame(1,$w->run()['cancelled']);
        $event=$this->request('POST',"/api/v1/groups/$g/events",$this->draft(),$a['token']);self::assertSame(200,$event->status());$id=$event->data()['id'];self::assertSame(1,$w->run()['sent']);self::assertSame('event.created',$t->calls[1]['type']);
        $this->request('PATCH',"/api/v1/events/$id",['version'=>1,'status'=>'cancelled'],$a['token']);self::assertSame(1,(int)Database::queryOne("SELECT COUNT(*) n FROM notification_outbox WHERE kind='event.reminder' AND state='cancelled'")['n']);self::assertSame(1,$w->run()['sent']);
    }
    public function testDirectReportsAreOwnedSilentIdempotentAndAvailableAfterBlock():void
    {
        $a=$this->user('Sender');$b=$this->user('Recipient');$outsider=$this->user('Outsider');$g=$this->createGroup($a);$this->join($a,$b,$g);$cid=$this->request('PUT',"/api/v1/chats/direct/{$b['id']}",[],$a['token'])->data()['id'];$path="/api/v1/chats/$cid";
        $mid=$this->request('POST',$path.'/messages',['body'=>'Fictional selected report text','client_id'=>'fictional-direct-0009'],$a['token'])->data()['id'];
        $this->request('PUT',"/api/v1/me/blocks/{$a['id']}",[],$b['token']);$report=['message_id'=>$mid,'reason'=>'harassment','note'=>'Fictional note'];
        foreach([1,2] as $_)self::assertSame(200,$this->request('POST',$path.'/reports',$report,$b['token'])->status());self::assertSame(1,(int)Database::queryOne('SELECT COUNT(*) n FROM direct_chat_reports')['n']);self::assertSame('Fictional selected report text',Database::queryOne('SELECT excerpt FROM direct_chat_reports')['excerpt']);self::assertSame(404,$this->request('POST',$path.'/reports',$report,$outsider['token'])->status());self::assertSame(422,$this->request('POST',$path.'/reports',$report,$a['token'])->status());
        self::assertSame([],$this->request('GET',"/api/v1/groups/$g/reports",[],$a['token'])->data()['items']);
    }
    public function testCrossGroupRepliesPaginationAndReadMarkersDoNotGrantAccess():void
    {
        $a=$this->user('Owner');$b=$this->user('Member');$g=$this->createGroup($a);$h=$this->createGroup($a);$this->join($a,$b,$g);$c=$this->chatId($g);$other=$this->chatId($h);
        $foreign=$this->request('POST',"/api/v1/chats/$other/messages",['body'=>'Private other group','client_id'=>'fictional-message-0010'],$a['token'])->data()['id'];
        self::assertSame(422,$this->request('POST',"/api/v1/chats/$c/messages",['body'=>'No cross reply','client_id'=>'fictional-message-0011','reply_to_id'=>$foreign],$a['token'])->status());self::assertSame(422,$this->request('PATCH',"/api/v1/chats/$c/state",['read_id'=>$foreign],$b['token'])->status());
        $ids=[];for($n=0;$n<3;$n++)$ids[]=$this->request('POST',"/api/v1/chats/$c/messages",['body'=>'Fictional page '.$n,'client_id'=>'fictional-page-key-00'.$n],$a['token'])->data()['id'];
        $page=$this->request('GET',"/api/v1/chats/$c?limit=2",[],$b['token'])->data();self::assertTrue($page['has_more']);self::assertSame([$ids[1],$ids[2]],array_column($page['items'],'id'));$older=$this->request('GET',"/api/v1/chats/$c?limit=2&before={$ids[1]}",[],$b['token'])->data();self::assertFalse($older['has_more']);self::assertSame([$ids[0]],array_column($older['items'],'id'));
    }
    public function testEventTimeValidationUtcRemindersAndDepartedMembership():void
    {
        $a=$this->user('Owner');$b=$this->user('Member');$g=$this->createGroup($a);$this->join($a,$b,$g);
        foreach([['timezone'=>'Fake/Zone'],['online_link'=>'http://insecure.example','venue'=>''],['start_at'=>'2040-01-01T00:00:00Z'],['start_at'=>'2030-02-30T00:00:00Z'],['venue'=>'']] as $change)self::assertSame(422,$this->request('POST',"/api/v1/groups/$g/events",[...$this->draft(),...$change],$a['token'])->status());
        $draft=[...$this->draft(),'start_at'=>'2030-11-01T12:00:00+05:30'];$id=$this->request('POST',"/api/v1/groups/$g/events",$draft,$a['token'])->data()['id'];self::assertSame('2030-11-01T06:30:00Z',$this->request('GET',"/api/v1/events/$id",[],$b['token'])->data()['start_at']);
        Database::transaction(static fn()=>MemberRepository::removeMember($g,$b['id'],'removed'));self::assertSame(404,$this->request('GET',"/api/v1/events/$id",[],$b['token'])->status());self::assertSame([],$this->request('GET','/api/v1/events',[],$b['token'])->data()['items']);self::assertSame(404,$this->request('PUT',"/api/v1/events/$id/rsvp",['status'=>'going'],$b['token'])->status());
    }

    public function testDueRemindersIncludeDevicesRegisteredAfterEventCreation():void
    {
        $a=$this->user('Owner');$b=$this->user('Late device');$g=$this->createGroup($a);$this->join($a,$b,$g);
        $id=$this->request('POST',"/api/v1/groups/$g/events",[...$this->draft(),'start_at'=>gmdate('Y-m-d\TH:i:s\Z',time()+1800)],$a['token'])->data()['id'];self::assertSame(0,(int)Database::queryOne('SELECT COUNT(*) n FROM notification_outbox')['n']);
        $this->request('PATCH','/api/v1/me/notification-preferences',['enabled'=>true,'quiet_hours'=>false,'categories'=>['events'=>true]],$b['token']);$this->request('POST','/api/v1/devices/register',['fcm_token'=>'fictional-late-event-device','platform'=>'android'],$b['token']);$t=new LiveRecordingTransport();$w=new NotificationWorker($t);self::assertSame(1,$w->run()['sent']);self::assertSame('event.reminder',$t->calls[0]['type']);self::assertSame((string)$id,$t->calls[0]['event_ref']);self::assertSame(0,$w->run()['processed']);
    }

}
