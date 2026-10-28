<?php

declare(strict_types=1);
namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Media\ImageInspector;
use Circle\Media\ImageProcessingException;
use Circle\Media\MediaRejected;
use Circle\Media\MediaServices;
use Circle\Media\Uuid;
use Circle\Middleware\RateLimitMiddleware;

/** Private, re-encoded photos; no reusable public links or original metadata. */
final class FeatureMediaController
{
    private const SIZES = ['thumb'=>320,'medium'=>1080,'full'=>2048];
    /** @return list<string> */
    public static function attachments(int $message):array
    {
        return array_column(Database::query('SELECT id FROM feature_media WHERE message_id=:m ORDER BY id',['m'=>$message]),'id');
    }
    /** Called inside the sending transaction; an upload belongs to one message only.
     * @param list<string> $ids */
    public static function attach(array $ids,int $conversation,int $user,int $message):void
    {
        foreach($ids as $id){$p=Database::queryOne('SELECT * FROM feature_media WHERE id=:id FOR UPDATE',['id'=>$id]);
            if($p===null||$p['scope_kind']!=='chat'||(int)$p['scope_id']!==$conversation||(int)$p['uploader_id']!==$user||$p['message_id']!==null)Response::validationError('A photo is no longer available. Choose it again.');
            Database::execute('UPDATE feature_media SET message_id=:m WHERE id=:id',['m'=>$message,'id'=>$id]);}
    }
    public static function uploadChat(Request $r):void
    {
        $c=ChatController::access($r);if(!$c['can_send'])Response::forbidden('This conversation is read-only.');
        if($c['kind']==='direct'&&$c['request_state']!=='accepted')Response::forbidden('Wait until your text message request is accepted before sharing photos.');
        $id=Uuid::normalise($r->param('mediaId'));if($id===null)Response::validationError('Use a photo upload UUID.');
        self::store($r,'chat',(int)$c['id'],$id);Response::ok(['id'=>$id]);
    }
    public static function putCover(Request $r):void
    {
        $e=EventController::access($r);self::organizer($e,$r);self::store($r,'event',(int)$e['id'],Uuid::v4());EventController::show($r);
    }
    /** @param array<string,mixed> $e */
    private static function organizer(array $e,Request $r):void
    {
        if((int)$e['created_by']!==$r->userId()&&!\Circle\Repositories\MemberRepository::isAdmin((int)$e['group_id'],$r->userId()))Response::forbidden('Only organizers or group admins can change the cover.');
        if($e['status']!=='active'||$r->queryInt('version',0,0,PHP_INT_MAX)!==(int)$e['version'])Response::error('conflict','Event changed. Refresh before editing its cover.',409);
    }
    private static function store(Request $r,string $kind,int $scope,string $id):void
    {
        $bytes=$r->readRawBody(5*1024*1024);if($bytes===null)Response::error('media_too_large','Choose a photo smaller than 5 MB.',413);
        $mime=strtolower(trim(explode(';',$r->contentType)[0]));
        try{$info=ImageInspector::inspect($bytes,$mime,['image/jpeg','image/png','image/webp'],4194304);if($info['width']>2048||$info['height']>2048)Response::validationError('Resize the photo to at most 2048 pixels per side.');}
        catch(MediaRejected $e){Response::error($e->errorCode,$e->getMessage(),$e->status);}
        $hash=hash('sha256',$bytes);$old=Database::queryOne('SELECT * FROM feature_media WHERE id=:id',['id'=>$id]);
        if($old!==null){if($old['scope_kind']!==$kind||(int)$old['scope_id']!==$scope||(int)$old['uploader_id']!==$r->userId()||!hash_equals((string)$old['request_sha'],$hash))Response::error('conflict','This upload id was already used.',409);return;}
        RateLimitMiddleware::consumeForUser($r->userId(),'feature_photo',60,3600,'Please wait before uploading more photos.');
        $processor=MediaServices::processor();if($processor===null||!$processor->supports($mime))Response::unavailable('Photo processing is temporarily unavailable.');
        $storage=MediaServices::storage();$scratch=$storage->makeScratchDir();$prefix='media/features/'.Uuid::v4();$saved=false;
        try{
            $source=$scratch.'/source';if(file_put_contents($source,$bytes)!==strlen($bytes))throw new \RuntimeException('Photo staging failed.');unset($bytes);
            $image=$processor->process($source,$mime,self::SIZES,$scratch);
            if(!in_array($image->mimeType,['image/webp','image/jpeg'],true)||!in_array($image->extension,['webp','jpg','jpeg'],true))throw new \RuntimeException('Invalid processed photo type.');
            foreach(self::SIZES as $size=>$_){$v=$image->variants[$size]??null;if($v===null)throw new \RuntimeException('Photo size missing.');$storage->put($prefix.'/'.$size.'.'.$image->extension,$v['path']);}
            $saved=Database::transaction(static function()use($r,$kind,$scope,$id,$prefix,$image,$hash):bool {
                if($kind==='chat'){$c=ChatController::access($r,true);if(!$c['can_send']||($c['kind']==='direct'&&$c['request_state']!=='accepted'))Response::forbidden('Photo sharing is no longer available.');}
                else {$e=EventController::access($r,true);self::organizer($e,$r);}
                $existing=Database::queryOne('SELECT * FROM feature_media WHERE id=:id FOR UPDATE',['id'=>$id]);
                if($existing!==null){if($existing['scope_kind']!==$kind||(int)$existing['scope_id']!==$scope||(int)$existing['uploader_id']!==$r->userId()||!hash_equals((string)$existing['request_sha'],$hash))Response::error('conflict','This upload id was already used.',409);return false;}
                Database::execute('INSERT INTO feature_media(id,scope_kind,scope_id,uploader_id,request_sha,storage_prefix,mime_type,extension) VALUES(:id,:k,:s,:u,:h,:p,:m,:x)',['id'=>$id,'k'=>$kind,'s'=>$scope,'u'=>$r->userId(),'h'=>$hash,'p'=>$prefix,'m'=>$image->mimeType,'x'=>$image->extension]);
                if($kind==='event'){Database::execute('UPDATE events SET cover_id=:c,version=version+1 WHERE id=:id',['c'=>$id,'id'=>$scope]);self::eventChanged($scope,$r->userId());}
                return true;
            });
        }catch(ImageProcessingException){Response::validationError('This photo could not be processed. Choose another photo.');}
        finally{$storage->removeScratch($scratch);if(!$saved)$storage->deletePrefix($prefix);}
    }
    public static function deleteCover(Request $r):void
    {
        Database::transaction(static function()use($r):void{$e=EventController::access($r,true);self::organizer($e,$r);Database::execute('UPDATE events SET cover_id=NULL,version=version+1 WHERE id=:id',['id'=>$e['id']]);self::eventChanged((int)$e['id'],$r->userId());});EventController::show($r);
    }
    public static function cover(Request $r):void
    {
        $e=EventController::access($r);if($e['cover_id']===null)Response::notFound();self::stream((string)$e['cover_id'],$r);
    }
    public static function chatPhoto(Request $r):void
    {
        $c=ChatController::access($r);$id=Uuid::normalise($r->param('mediaId'));if($id===null)Response::notFound();
        $p=Database::queryOne('SELECT * FROM feature_media WHERE id=:id',['id'=>$id]);if($p===null||$p['scope_kind']!=='chat'||(int)$p['scope_id']!==(int)$c['id'])Response::notFound();
        if($p['message_id']===null){if((int)$p['uploader_id']!==$r->userId()||!$c['can_send'])Response::notFound();}
        else {
            if($c['kind']==='direct'&&$c['request_state']!=='accepted')Response::notFound();
            $v=Database::queryOne("SELECT v.removed FROM chat_versions v JOIN chat_messages m ON m.id=v.message_id JOIN conversations c ON c.id=m.conversation_id LEFT JOIN group_members gm ON gm.group_id=c.group_id AND gm.user_id=:u WHERE v.message_id=:m AND (c.kind='direct' OR gm.status='active' OR v.id<=COALESCE(gm.chat_frozen_id,0)) ORDER BY v.id DESC LIMIT 1",['m'=>$p['message_id'],'u'=>$r->userId()]);if($v===null||$v['removed'])Response::notFound();
        }
        self::stream($id,$r);
    }
    private static function eventChanged(int $id,int $user):void
    {
        Database::execute("UPDATE notification_outbox SET state='cancelled',last_error='event_changed' WHERE event_id=:id AND state='pending'",['id'=>$id]);
        \Circle\Notifications\FeatureNotifications::event($id,'event.updated',$user);
        \Circle\Notifications\FeatureNotifications::event($id,'event.reminder',$user);
    }
    private static function stream(string $id,Request $r):never
    {
        $size=$r->query('size','medium');if(!isset(self::SIZES[$size]))Response::validationError('Choose thumb, medium or full.');
        $p=Database::queryOne('SELECT * FROM feature_media WHERE id=:id',['id'=>$id]);if($p===null)Response::notFound();$path=MediaServices::storage()->localPath($p['storage_prefix'].'/'.$size.'.'.$p['extension']);if($path===null)Response::notFound();
        Response::header('Cache-Control','private, no-store');Response::header('X-Content-Type-Options','nosniff');Response::header('Content-Security-Policy',"default-src 'none'; sandbox");Response::file($path,(string)$p['mime_type']);
    }
}
