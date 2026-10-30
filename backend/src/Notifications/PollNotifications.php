<?php

declare(strict_types=1);
namespace Circle\Notifications;
use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Core\NotificationPreferences;
use Circle\Controllers\PollController;

final class PollNotifications
{
    public static function capture(int $id,string $kind,int $actor):void
    {
        if(Env::get('PUSH_QUEUE_ENABLED','false')!=='true')return;
        if(!Database::connection()->inTransaction())throw new \LogicException('Notification capture requires a transaction.');
        $scope=Database::queryOne('SELECT group_id FROM polls WHERE id=:id',['id'=>$id]);if($scope===null)return;
        Database::queryOne('SELECT id FROM `groups` WHERE id=:g FOR UPDATE',['g'=>$scope['group_id']]);
        $p=Database::queryOne('SELECT * FROM polls WHERE id=:id FOR UPDATE',['id'=>$id]);if($p===null)return;
        foreach(Database::query("SELECT user_id FROM group_members WHERE group_id=:g AND status='active' FOR UPDATE",['g'=>$p['group_id']]) as $u){$uid=(int)$u['user_id'];if($uid===$actor||!PollController::visible($p,$uid,true)||!NotificationPreferences::eligible($uid,'polls',(int)$p['group_id']))continue;
            if($kind==='poll.closed'&&$uid!==(int)$p['created_by']&&Database::queryOne('SELECT id FROM poll_votes WHERE poll_id=:p AND user_id=:u LIMIT 1 FOR UPDATE',['p'=>$id,'u'=>$uid])===null)continue;
            Database::execute("INSERT INTO notification_outbox(event_key,kind,user_id,device_id,session_id,group_id,poll_id,available_at,expires_at) SELECT :key,:kind,dt.user_id,dt.id,dt.session_id,:g,:p,UTC_TIMESTAMP(),DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY) FROM device_tokens dt WHERE dt.user_id=:u AND dt.platform IN ('android','ios') AND dt.session_id IS NOT NULL AND EXISTS(SELECT 1 FROM refresh_tokens rt WHERE rt.user_id=dt.user_id AND rt.session_id=dt.session_id AND rt.revoked_at IS NULL AND rt.expires_at>UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE event_key=notification_outbox.event_key",['key'=>$kind.':'.$id,'kind'=>$kind,'g'=>$p['group_id'],'p'=>$id,'u'=>$uid]);
        }
    }
    public static function closed(int $id,int $actor=0):void
    {
        $scope=Database::queryOne('SELECT group_id FROM polls WHERE id=:id',['id'=>$id]);if($scope===null)return;
        Database::queryOne('SELECT id FROM `groups` WHERE id=:g FOR UPDATE',['g'=>$scope['group_id']]);
        $p=Database::queryOne('SELECT * FROM polls WHERE id=:id FOR UPDATE',['id'=>$id]);if($p===null||!PollController::closed($p)||$p['close_notified_at']!==null)return;
        self::capture($id,'poll.closed',$actor);Database::execute('UPDATE polls SET close_notified_at=UTC_TIMESTAMP() WHERE id=:id',['id'=>$id]);
    }
    public static function scan():void
    {
        if(Env::get('PUSH_QUEUE_ENABLED','false')!=='true')return;
        foreach(Database::query('SELECT id FROM polls WHERE close_notified_at IS NULL AND (closed_at IS NOT NULL OR closes_at<=UTC_TIMESTAMP()) ORDER BY id LIMIT 100') as $p)Database::transaction(static fn()=>self::closed((int)$p['id']));
    }
    public static function eligible(int $id,int $user,string $kind):bool
    {
        $p=Database::queryOne('SELECT * FROM polls WHERE id=:id',['id'=>$id]);return $p!==null&&PollController::visible($p,$user)&&NotificationPreferences::eligible($user,'polls',(int)$p['group_id'])&&($kind==='poll.created'?!PollController::closed($p):PollController::closed($p));
    }
}
