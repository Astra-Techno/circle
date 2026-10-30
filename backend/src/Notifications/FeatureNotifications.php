<?php

declare(strict_types=1);
namespace Circle\Notifications;
use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Core\NotificationPreferences;
use Circle\Controllers\ChatController;
use Circle\Repositories\BlockRepository;
final class FeatureNotifications
{
    public static function scheduleReminders():void
    {
        if(Env::get('PUSH_QUEUE_ENABLED','false')!=='true')return;
        $events=Database::query("SELECT id FROM events WHERE status='active' AND start_at>UTC_TIMESTAMP() AND start_at<=DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 HOUR) ORDER BY COALESCE(reminder_scanned_at,'1970-01-01'),id LIMIT 100");
        foreach($events as $e)Database::transaction(static function()use($e):void {
            Database::execute('UPDATE events SET reminder_scanned_at=UTC_TIMESTAMP(6) WHERE id=:id',['id'=>$e['id']]);
            self::event((int)$e['id'],'event.reminder',0);
        });
    }
    public static function chat(int $message,int $actor):void
    {
        if(Env::get('PUSH_QUEUE_ENABLED','false')!=='true')return;
        if(!Database::connection()->inTransaction())throw new \LogicException('Notification capture requires a transaction.');
        $c=Database::queryOne('SELECT c.* FROM conversations c JOIN chat_messages m ON m.conversation_id=c.id WHERE m.id=:id',['id'=>$message]);if($c===null)return;
        if($c['kind']==='group'){$g=(int)$c['group_id'];$users=Database::query("SELECT user_id FROM group_members WHERE group_id=:g AND status='active'",['g'=>$g]);}
        else {$shared=ChatController::shared((int)$c['pair_low'],(int)$c['pair_high']);if($shared===null)return;$g=(int)$shared['group_id'];$users=[['user_id'=>(int)$c['pair_low']],['user_id'=>(int)$c['pair_high']]];}
        foreach($users as $user){$uid=(int)$user['user_id'];if($uid===$actor)continue;self::enqueue('chat.message:'.$message,'chat.message',$uid,$g,$message,null,null,gmdate('Y-m-d H:i:s'),gmdate('Y-m-d H:i:s',time()+86400));}
    }
    public static function event(int $event,string $kind,int $actor):void
    {
        if(Env::get('PUSH_QUEUE_ENABLED','false')!=='true')return;
        if(!Database::connection()->inTransaction())throw new \LogicException('Notification capture requires a transaction.');$e=Database::queryOne('SELECT * FROM events WHERE id=:id',['id'=>$event]);if($e===null)return;
        $reminder=$kind==='event.reminder';if($reminder&&($e['status']!=='active'||$e['start_at']<=gmdate('Y-m-d H:i:s')))return;
        $at=$reminder?max(gmdate('Y-m-d H:i:s'),gmdate('Y-m-d H:i:s',(int)strtotime((string)$e['start_at'].' UTC')-3600)):gmdate('Y-m-d H:i:s');$expires=$reminder?(string)$e['start_at']:gmdate('Y-m-d H:i:s',time()+86400);$users=Database::query("SELECT user_id FROM group_members WHERE group_id=:g AND status='active'",['g'=>$e['group_id']]);$key=$kind.':'.$event.':'.$e['version'].($kind==='event.rsvp'?':'.bin2hex(random_bytes(8)):'');
        foreach($users as $u){$uid=(int)$u['user_id'];if((!$reminder&&$uid===$actor)||($kind==='event.rsvp'&&$uid!==(int)$e['created_by']))continue;self::enqueue($key,$kind,$uid,(int)$e['group_id'],null,$event,(int)$e['version'],$at,$expires);}
    }
    private static function enqueue(string $key,string $kind,int $user,int $group,?int $message,?int $event,?int $version,string $at,string $expires):void
    {
        $category=$message!==null?'chats':'events';if(!NotificationPreferences::eligible($user,$category,$group))return;
        if($message!==null&&!self::chatEligible($message,$user))return;
        Database::execute("INSERT INTO notification_outbox(event_key,kind,user_id,device_id,session_id,group_id,chat_message_id,event_id,event_version,available_at,expires_at)
        SELECT :key,:kind,dt.user_id,dt.id,dt.session_id,:g,:message,:event,:version,:at,:expires FROM device_tokens dt WHERE dt.user_id=:u AND dt.platform IN ('android','ios') AND dt.session_id IS NOT NULL AND EXISTS(SELECT 1 FROM refresh_tokens rt WHERE rt.user_id=dt.user_id AND rt.session_id=dt.session_id AND rt.revoked_at IS NULL AND rt.expires_at>UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE event_key=notification_outbox.event_key",['key'=>$key,'kind'=>$kind,'g'=>$group,'message'=>$message,'event'=>$event,'version'=>$version,'at'=>$at,'expires'=>$expires,'u'=>$user]);
    }
    public static function chatEligible(int $message,int $viewer):bool
    {
        $c=Database::queryOne('SELECT c.*,m.id message_id,v.removed FROM conversations c JOIN chat_messages m ON m.conversation_id=c.id JOIN users sender ON sender.id=m.author_id AND sender.status=\'active\' JOIN chat_versions v ON v.id=(SELECT MAX(id) FROM chat_versions WHERE message_id=m.id) WHERE m.id=:id',['id'=>$message]);if($c===null||$c['removed'])return false;
        if($c['kind']==='direct'){
            if(!in_array($viewer,[(int)$c['pair_low'],(int)$c['pair_high']],true)||BlockRepository::either((int)$c['pair_low'],(int)$c['pair_high'])||ChatController::shared((int)$c['pair_low'],(int)$c['pair_high'])===null)return false;
            $p=Database::queryOne('SELECT who_can_message FROM chat_privacy WHERE user_id=:u',['u'=>$viewer]);$policy=$p['who_can_message']??'all';if($policy==='none'||$c['request_state']==='declined'||($policy==='existing'&&$c['request_state']!=='accepted'))return false;
        }else if(!\Circle\Repositories\MemberRepository::isActiveMember((int)$c['group_id'],$viewer))return false;
        $s=Database::queryOne('SELECT read_id,muted FROM chat_states WHERE user_id=:u AND conversation_id=:c',['u'=>$viewer,'c'=>$c['id']]);return !(bool)($s['muted']??false)&&(int)($s['read_id']??0)<$message;
    }
}
