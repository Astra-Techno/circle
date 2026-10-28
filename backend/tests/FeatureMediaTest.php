<?php

declare(strict_types=1);
namespace Circle\Tests;
use Circle\Core\Database;
use Circle\Media\MediaCleanup;
use Circle\Media\MediaServices;
use Circle\Media\ImageProcessingException;
use Circle\Repositories\MemberRepository;
use Circle\Tests\Support\ImageFixtures;

final class FeatureMediaTest extends MediaTestCase
{
    private function chat(int $g):string{return '/api/v1/chats/'.Database::queryOne('SELECT id FROM conversations WHERE group_id=:g',['g'=>$g])['id'];}
    /** @param array{token:string} $user */
    private function upload(string $path,array $user):string
    {
        $id=$this->uuid();$r=$this->requestRaw('PUT',"$path/uploads/$id",ImageFixtures::png(),$user['token'],'image/png');self::assertSame(200,$r->status(),json_encode($r->json())?:'');return $id;
    }
    public function testChatPhotosOwnershipRetryFrozenHistoryUnsendAndUndo():void
    {
        $a=$this->user('Owner');$b=$this->user('Member');$c=$this->user('Outsider');$g=$this->createGroup($a);$this->join($a,$b,$g);$path=$this->chat($g);$photo=$this->upload($path,$a);
        self::assertSame(200,$this->requestRaw('PUT',"$path/uploads/$photo",ImageFixtures::png(),$a['token'],'image/png')->status());self::assertCount(3,$this->storedFiles());
        self::assertSame(404,$this->request('GET',"$path/media/$photo",[],$b['token'])->status());
        self::assertSame(422,$this->request('POST',"$path/messages",['client_id'=>'fictional-photo-0001','attachments'=>[$photo]],$b['token'])->status());
        $send=['client_id'=>'fictional-photo-0001','attachments'=>[$photo]];$r=$this->request('POST',"$path/messages",$send,$a['token']);self::assertSame(200,$r->status());$mid=$r->data()['id'];self::assertSame($mid,$this->request('POST',"$path/messages",$send,$a['token'])->data()['id']);
        self::assertSame([$photo],$this->request('GET',$path,[],$b['token'])->data()['items'][0]['attachments']);
        $read=$this->request('GET',"$path/media/$photo",[],$b['token']);self::assertSame(200,$read->status());self::assertSame('private, no-store',$read->header('Cache-Control'));self::assertStringContainsString('FAKE-WEBP',$read->rawBody()??'');
        self::assertSame(404,$this->request('GET',"$path/media/$photo",[],$c['token'])->status());
        Database::transaction(static fn()=>MemberRepository::removeMember($g,$b['id'],'left'));
        $this->request('PATCH',"$path/messages/$mid",['removed'=>true],$a['token']);
        self::assertSame(404,$this->request('GET',"$path/media/$photo",[],$a['token'])->status());self::assertSame(200,$this->request('GET',"$path/media/$photo",[],$b['token'])->status());
        $later=$this->upload($path,$a);$this->request('POST',"$path/messages",['client_id'=>'fictional-photo-0002','attachments'=>[$later]],$a['token']);self::assertSame(404,$this->request('GET',"$path/media/$later",[],$b['token'])->status());
        $this->request('PATCH',"$path/messages/$mid",['removed'=>false],$a['token']);self::assertSame(200,$this->request('GET',"$path/media/$photo",[],$a['token'])->status());
    }
    public function testCrossConversationReuseMalformedAndPendingDirectAreRejected():void
    {
        $a=$this->user();$b=$this->user('Member');$g=$this->createGroup($a);$h=$this->createGroup($a);$this->join($a,$b,$g);$path=$this->chat($g);$other=$this->chat($h);$id=$this->upload($path,$a);
        self::assertSame(422,$this->request('POST',"$other/messages",['client_id'=>'fictional-photo-0003','attachments'=>[$id]],$a['token'])->status());self::assertSame(404,$this->request('GET',"$other/media/$id",[],$a['token'])->status());
        foreach([[$id,$id],[1],['not-a-uuid'],[$id,$id,$id,$id,$id]] as $ids)self::assertSame(422,$this->request('POST',"$path/messages",['client_id'=>'fictional-photo-0004','attachments'=>$ids],$a['token'])->status());
        $direct='/api/v1/chats/'.$this->request('PUT',"/api/v1/chats/direct/{$b['id']}",[],$a['token'])->data()['id'];self::assertSame(403,$this->requestRaw('PUT',"$direct/uploads/".$this->uuid(),ImageFixtures::png(),$a['token'],'image/png')->status());
        $this->request('POST',"$direct/messages",['body'=>'Fictional introduction','client_id'=>'fictional-photo-0005'],$a['token']);$this->request('POST',"$direct/request",['action'=>'accept'],$b['token']);$photo=$this->upload($direct,$a);$this->request('POST',"$direct/messages",['attachments'=>[$photo],'client_id'=>'fictional-photo-0006'],$a['token']);self::assertSame(200,$this->request('GET',"$direct/media/$photo",[],$b['token'])->status());
        $this->request('PUT',"/api/v1/me/blocks/{$a['id']}",[],$b['token']);self::assertSame(403,$this->requestRaw('PUT',"$direct/uploads/".$this->uuid(),ImageFixtures::png(),$a['token'],'image/png')->status());
    }
    public function testEventCoverVersionPermissionsReplaceRemoveAndOrphanCleanup():void
    {
        $a=$this->user();$b=$this->user('Member');$outside=$this->user('Outside');$g=$this->createGroup($a);$this->join($a,$b,$g);
        $e=$this->request('POST',"/api/v1/groups/$g/events",['client_id'=>'fictional-cover-0001','title'=>'Fictional picnic','venue'=>'Fictional park','timezone'=>'UTC','start_at'=>gmdate('Y-m-d\TH:i:s\Z',time()+86400)],$a['token'])->data()['id'];$path="/api/v1/events/$e/cover";
        self::assertSame(403,$this->requestRaw('PUT',"$path?version=1",ImageFixtures::png(),$b['token'],'image/png')->status());
        $put=$this->requestRaw('PUT',"$path?version=1",ImageFixtures::png(),$a['token'],'image/png');self::assertSame(200,$put->status());self::assertSame(2,$put->data()['version']);self::assertNotNull($put->data()['cover_id']);
        self::assertSame(409,$this->requestRaw('PUT',"$path?version=1",ImageFixtures::png(),$a['token'],'image/png')->status());self::assertSame(200,$this->request('GET',$path,[],$b['token'])->status());self::assertSame(404,$this->request('GET',$path,[],$outside['token'])->status());
        self::assertSame(200,$this->requestRaw('PUT',"$path?version=2",ImageFixtures::png(),$a['token'],'image/png')->status());self::assertCount(6,$this->storedFiles());
        $draft=$this->upload($this->chat($g),$a);Database::execute('UPDATE feature_media SET created_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 25 HOUR)');MediaCleanup::run(MediaServices::storage());self::assertCount(3,$this->storedFiles());self::assertNull(Database::queryOne('SELECT id FROM feature_media WHERE id=:id',['id'=>$draft]));
        self::assertSame(200,$this->request('DELETE',"$path?version=3",[],$a['token'])->status());self::assertSame(404,$this->request('GET',$path,[],$a['token'])->status());MediaCleanup::run(MediaServices::storage());self::assertCount(0,$this->storedFiles());
    }
    public function testBadContentFailsClosedAndProcessingRaceLeavesNoFiles():void
    {
        $a=$this->user();$g=$this->createGroup($a);$path=$this->chat($g);
        foreach([['invalid','image/png',415],[ImageFixtures::png(),'image/jpeg',422],[str_repeat('x',5242881),'image/png',413]] as [$bytes,$mime,$code])self::assertSame($code,$this->requestRaw('PUT',"$path/uploads/".$this->uuid(),$bytes,$a['token'],$mime)->status());
        $this->processor->failWith=new ImageProcessingException('Fictional failure');self::assertSame(422,$this->requestRaw('PUT',"$path/uploads/".$this->uuid(),ImageFixtures::png(),$a['token'],'image/png')->status());self::assertCount(0,$this->storedFiles());
        $this->processor->failWith=null;
        MediaServices::setProcessor(new class($this->processor,$g,$a['id']) implements \Circle\Media\ImageProcessor {
            public function __construct(private \Circle\Media\ImageProcessor $processor,private int $group,private int $user){}
            public function supports(string $mimeType):bool{return true;}
            public function process(string $sourcePath,string $mimeType,array $targets,string $workDir):\Circle\Media\ProcessedImage {
                $result=$this->processor->process($sourcePath,$mimeType,$targets,$workDir);Database::execute("UPDATE group_members SET status='removed' WHERE group_id=:g AND user_id=:u",['g'=>$this->group,'u'=>$this->user]);return $result;
            }
        });
        self::assertSame(403,$this->requestRaw('PUT',"$path/uploads/".$this->uuid(),ImageFixtures::png(),$a['token'],'image/png')->status());self::assertCount(0,$this->storedFiles());
    }
}
