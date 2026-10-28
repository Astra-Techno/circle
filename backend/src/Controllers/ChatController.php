<?php

declare(strict_types=1);
namespace Circle\Controllers;
use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Core\Validator;
use Circle\Repositories\BlockRepository;
use Circle\Repositories\MemberRepository;
use Circle\Notifications\FeatureNotifications;
final class ChatController
{
    /** @return array<string,mixed>|null */
    public static function shared(int $a,int $b):?array {return Database::queryOne("SELECT a.group_id FROM group_members a JOIN group_members b ON b.group_id=a.group_id WHERE a.user_id=:a AND b.user_id=:b AND a.status='active' AND b.status='active' ORDER BY a.group_id LIMIT 1",['a'=>$a,'b'=>$b]);}
    /** @param array<string,mixed> $c */
    public static function canSend(array $c,int $viewer):bool
    {
        if($c['kind']==='group')return MemberRepository::isActiveMember((int)$c['group_id'],$viewer);
        $other=(int)$c['pair_low']===$viewer?(int)$c['pair_high']:(int)$c['pair_low'];
        if(!in_array($viewer,[(int)$c['pair_low'],(int)$c['pair_high']],true) || BlockRepository::either($viewer,$other) || self::shared($viewer,$other)===null)return false;
        $user=Database::queryOne("SELECT status FROM users WHERE id=:id",['id'=>$other]);if(($user['status']??'')!=='active')return false;
        $privacy=Database::queryOne('SELECT who_can_message FROM chat_privacy WHERE user_id=:id',['id'=>$other]);$policy=$privacy['who_can_message']??'all';
        return $policy!=='none' && $c['request_state']!=='declined' && ($c['request_state']==='accepted' || ($policy==='all' && (int)$c['requested_by']===$viewer));
    }
    /** @return array<string,mixed> */
    public static function access(Request $r,bool $write=false):array
    {
        $id=(int)$r->param('id');$c=Database::queryOne('SELECT * FROM conversations WHERE id=:id',['id'=>$id]);if($c===null)Response::notFound('This conversation is not available.');
        if($write){
            if($c['kind']==='group')Database::queryOne('SELECT id FROM `groups` WHERE id=:id FOR UPDATE',['id'=>$c['group_id']]);
            else Database::query('SELECT id FROM users WHERE id IN (:a,:b) ORDER BY id FOR UPDATE',['a'=>$c['pair_low'],'b'=>$c['pair_high']]);
            $c=Database::queryOne('SELECT * FROM conversations WHERE id=:id FOR UPDATE',['id'=>$id]);if($c===null)Response::notFound();
            if(Database::queryOne('SELECT id FROM refresh_tokens WHERE user_id=:u AND session_id=:s AND revoked_at IS NULL AND expires_at>UTC_TIMESTAMP() FOR UPDATE',['u'=>$r->userId(),'s'=>$r->attr('session_id')])===null)Response::unauthorized();
        }
        if($c['kind']==='group'){
            $m=Database::queryOne('SELECT status,chat_frozen_id FROM group_members WHERE group_id=:g AND user_id=:u',['g'=>$c['group_id'],'u'=>$r->userId()]);if($m===null)Response::notFound('This conversation is not available.');$c['frozen']=$m['status']==='active'?PHP_INT_MAX:(int)($m['chat_frozen_id']??0);
        }elseif(!in_array($r->userId(),[(int)$c['pair_low'],(int)$c['pair_high']],true))Response::notFound('This conversation is not available.');else $c['frozen']=PHP_INT_MAX;
        $c['can_send']=self::canSend($c,$r->userId());return $c;
    }
    public static function group(Request $r):void
    {
        Response::header('Cache-Control','private, no-store');$c=Database::queryOne('SELECT c.id FROM conversations c JOIN group_members gm ON gm.group_id=c.group_id AND gm.user_id=:u WHERE c.group_id=:g',['u'=>$r->userId(),'g'=>(int)$r->param('id')]);if($c===null)Response::notFound();Response::ok(['id'=>(int)$c['id']]);
    }
    public static function inbox(Request $r):void
    {
        Response::header('Cache-Control','private, no-store');$limit=$r->queryInt('limit',30,1,100);$offset=$r->queryInt('offset',0,0,1000000);
        $rows=Database::query("SELECT c.*,g.name,other.display_name,COALESCE(s.muted,0) muted,COALESCE(s.pinned,0) pinned,COALESCE(s.archived,0) archived,
         (SELECT COUNT(*) FROM chat_messages m WHERE m.conversation_id=c.id AND m.author_id<>:author AND m.id>COALESCE(s.read_id,0) AND EXISTS(SELECT 1 FROM chat_versions v WHERE v.removed=0 AND v.id=(SELECT MAX(x.id) FROM chat_versions x WHERE x.message_id=m.id AND (c.kind='direct' OR gm.status='active' OR x.id<=COALESCE(gm.chat_frozen_id,0))))) unread
         FROM conversations c LEFT JOIN `groups` g ON g.id=c.group_id LEFT JOIN group_members gm ON gm.group_id=c.group_id AND gm.user_id=:member
         LEFT JOIN users other ON other.id=IF(c.pair_low=:who,c.pair_high,c.pair_low)
         LEFT JOIN chat_states s ON s.conversation_id=c.id AND s.user_id=:state_user
         WHERE (c.kind='group' AND gm.user_id IS NOT NULL) OR (c.kind='direct' AND (c.pair_low=:low OR c.pair_high=:high))
         ORDER BY COALESCE(s.pinned,0) DESC,c.id DESC LIMIT :lim OFFSET :off",['author'=>$r->userId(),'member'=>$r->userId(),'who'=>$r->userId(),'state_user'=>$r->userId(),'low'=>$r->userId(),'high'=>$r->userId(),'lim'=>$limit+1,'off'=>$offset]);
        $more=count($rows)>$limit;if($more)array_pop($rows);$out=[];foreach($rows as $c)$out[]=['id'=>(int)$c['id'],'kind'=>$c['kind'],'group_id'=>$c['group_id']===null?null:(int)$c['group_id'],'name'=>$c['kind']==='group'?$c['name']:$c['display_name'],'request_state'=>$c['request_state'],'incoming'=>$c['kind']==='direct' && (int)$c['requested_by']!==$r->userId(),'unread'=>(int)$c['unread'],'muted'=>(bool)$c['muted'],'pinned'=>(bool)$c['pinned'],'archived'=>(bool)$c['archived']];Response::ok(['items'=>$out,'has_more'=>$more]);
    }
    public static function direct(Request $r):void
    {
        $other=(int)$r->param('userId');$viewer=$r->userId();if($other===$viewer)Response::validationError('Choose another person.');
        if(!$r->jsonIsObject() || $r->all()!==[])Response::validationError('No body fields are needed.');
        $id=Database::transaction(static function()use($other,$viewer,$r):int {
            Database::query('SELECT id FROM users WHERE id IN (:a,:b) ORDER BY id FOR UPDATE',['a'=>$viewer,'b'=>$other]);
            if(Database::queryOne('SELECT id FROM refresh_tokens WHERE user_id=:u AND session_id=:s AND revoked_at IS NULL AND expires_at>UTC_TIMESTAMP() FOR UPDATE',['u'=>$viewer,'s'=>$r->attr('session_id')])===null)Response::unauthorized();
            $c=Database::queryOne('SELECT * FROM conversations WHERE pair_low=:a AND pair_high=:b',['a'=>min($viewer,$other),'b'=>max($viewer,$other)]);
            $candidate=$c??['kind'=>'direct','pair_low'=>min($viewer,$other),'pair_high'=>max($viewer,$other),'requested_by'=>$viewer,'request_state'=>'pending'];
            if(!self::canSend($candidate,$viewer))Response::notFound('This person is not accepting messages.');
            if($c!==null)return (int)$c['id'];
            Database::execute("INSERT INTO conversations(kind,pair_low,pair_high,requested_by,request_state) VALUES('direct',:a,:b,:u,'pending')",['a'=>min($viewer,$other),'b'=>max($viewer,$other),'u'=>$viewer]);return Database::lastInsertId();
        });Response::ok(['id'=>$id]);
    }
    public static function show(Request $r):void
    {
        Response::header('Cache-Control','private, no-store');$c=self::access($r);$limit=$r->queryInt('limit',50,1,100);$before=$r->queryInt('before',PHP_INT_MAX,1,PHP_INT_MAX);
        // Re-evaluate group status/cutoff inside the same statement that reads versions.
        $rows=Database::query("SELECT m.*,v.body,v.removed,v.edited,u.display_name FROM chat_messages m JOIN users u ON u.id=m.author_id JOIN conversations c ON c.id=m.conversation_id
          LEFT JOIN group_members gm ON gm.group_id=c.group_id AND gm.user_id=:viewer
          JOIN chat_versions v ON v.id=(SELECT MAX(x.id) FROM chat_versions x WHERE x.message_id=m.id AND (c.kind='direct' OR gm.status='active' OR x.id<=COALESCE(gm.chat_frozen_id,0)))
          WHERE m.conversation_id=:c AND m.id<:before ORDER BY m.id DESC LIMIT :lim",['viewer'=>$r->userId(),'c'=>$c['id'],'before'=>$before,'lim'=>$limit+1]);$more=count($rows)>$limit;if($more)array_pop($rows);
        $state=Database::queryOne('SELECT * FROM chat_states WHERE user_id=:u AND conversation_id=:c',['u'=>$r->userId(),'c'=>$c['id']]);
        $items=[];foreach(array_reverse($rows) as $v){$reactions=$c['frozen']===PHP_INT_MAX?Database::query('SELECT user_id,emoji FROM chat_reactions WHERE message_id=:id',['id'=>$v['id']]):[];$items[]=['id'=>(int)$v['id'],'author_id'=>(int)$v['author_id'],'display_name'=>$v['display_name'],'body'=>$v['removed']?'':$v['body'],'removed'=>(bool)$v['removed'],'edited'=>(bool)$v['edited'],'reply_to_id'=>$v['reply_to_id']===null?null:(int)$v['reply_to_id'],'created_at'=>str_replace(' ','T',(string)$v['created_at']).'Z','attachments'=>$v['removed']?[]:FeatureMediaController::attachments((int)$v['id']),'reactions'=>$reactions];}
        $label=$c['kind']==='group'?Database::queryOne('SELECT name FROM `groups` WHERE id=:id',['id'=>$c['group_id']]):Database::queryOne('SELECT display_name AS name FROM users WHERE id=:id',['id'=>(int)$c['pair_low']===$r->userId()?(int)$c['pair_high']:(int)$c['pair_low']]);
        Response::ok(['name'=>$label['name']??'Conversation','other_id'=>$c['kind']==='direct'?((int)$c['pair_low']===$r->userId()?(int)$c['pair_high']:(int)$c['pair_low']):null,'id'=>(int)$c['id'],'kind'=>$c['kind'],'group_id'=>$c['group_id']===null?null:(int)$c['group_id'],'can_send'=>$c['can_send'],'request_state'=>$c['request_state'],'incoming'=>$c['kind']==='direct' && (int)$c['requested_by']!==$r->userId(),'muted'=>(bool)($state['muted']??false),'pinned'=>(bool)($state['pinned']??false),'archived'=>(bool)($state['archived']??false),'items'=>$items,'has_more'=>$more]);
    }
    public static function send(Request $r):void
    {
        $attachments=$r->input('attachments',[]);if(!is_array($attachments)||!array_is_list($attachments)||count($attachments)>4||count(array_unique(array_filter($attachments,'is_string')))!==count($attachments))Response::validationError('Choose up to four different photos.');foreach($attachments as $photo)if(\Circle\Media\Uuid::normalise($photo)===null)Response::validationError('Choose valid photo ids.');
        $body=$r->input('body','');$key=$r->input('client_id');$reply=$r->input('reply_to_id');(new Validator())->string('body',$body,$attachments===[]?1:0,4000)->bail();
        if(!is_string($key) || !preg_match('/^[a-zA-Z0-9_-]{16,100}$/',$key) || ($reply!==null && (!is_int($reply)||$reply<1)) || array_diff(array_keys($r->all()),['body','client_id','reply_to_id','attachments'])!==[])Response::validationError('Include text and a valid send id.');
        $id=Database::transaction(static function()use($r,$body,$key,$reply,$attachments):int {
            $c=self::access($r,true);if(!$c['can_send'])Response::forbidden('Sending is not available in this conversation.');
            $hash=hash('sha256',json_encode($attachments===[]?[$c['id'],$body,$reply]:[$c['id'],$body,$reply,$attachments],JSON_THROW_ON_ERROR));$old=Database::queryOne('SELECT id,request_hash FROM chat_messages WHERE author_id=:u AND client_id=:key',['u'=>$r->userId(),'key'=>$key]);if($old!==null){if(!hash_equals((string)$old['request_hash'],$hash))Response::error('conflict','This send id was already used.',409);return (int)$old['id'];}
            if($c['kind']==='direct' && $c['request_state']==='pending' && Database::queryOne('SELECT id FROM chat_messages WHERE conversation_id=:c',['c'=>$c['id']])!==null)Response::forbidden('Wait until your message request is accepted.');
            if($reply!==null && Database::queryOne('SELECT id FROM chat_messages WHERE id=:id AND conversation_id=:c',['id'=>$reply,'c'=>$c['id']])===null)Response::validationError('Reply to a message in this conversation.');
            $n=Database::queryOne('SELECT COUNT(*) n FROM chat_messages WHERE author_id=:u AND created_at>DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 MINUTE)',['u'=>$r->userId()]);if((int)($n['n']??0)>=60)Response::error('rate_limited','Please wait before sending more messages.',429);
            Database::execute('INSERT INTO chat_messages(conversation_id,author_id,client_id,request_hash,reply_to_id) VALUES(:c,:u,:key,:hash,:reply)',['c'=>$c['id'],'u'=>$r->userId(),'key'=>$key,'hash'=>$hash,'reply'=>$reply]);$id=Database::lastInsertId();FeatureMediaController::attach($attachments,(int)$c['id'],$r->userId(),$id);Database::execute('INSERT INTO chat_versions(message_id,body) VALUES(:id,:body)',['id'=>$id,'body'=>$body]);FeatureNotifications::chat($id,$r->userId());return $id;
        });Response::ok(['id'=>$id]);
    }
    public static function state(Request $r):void
    {
        if(!$r->jsonIsObject() || $r->all()===[] || array_diff(array_keys($r->all()),['read_id','muted','pinned','archived'])!==[])Response::validationError('Choose a supported conversation setting.');
        foreach(['muted','pinned','archived'] as $key)if($r->has($key)&&!is_bool($r->input($key)))Response::validationError('Use true or false.');$read=$r->input('read_id');if($r->has('read_id')&&(!is_int($read)||$read<0))Response::validationError('Use a valid read marker.');
        Database::transaction(static function()use($r,$read):void {
            $c=self::access($r,true);if($read!==null&&$read>0 && Database::queryOne('SELECT m.id FROM chat_messages m JOIN chat_versions v ON v.message_id=m.id WHERE m.id=:id AND m.conversation_id=:c AND v.id<=:bound',['id'=>$read,'c'=>$c['id'],'bound'=>$c['frozen']])===null)Response::validationError('Read marker is not visible in this chat.');
            Database::execute('INSERT IGNORE INTO chat_states(user_id,conversation_id) VALUES(:u,:c)',['u'=>$r->userId(),'c'=>$c['id']]);foreach($r->all() as $key=>$value)Database::execute('UPDATE chat_states SET '.$key.'='.($key==='read_id'?'GREATEST(read_id,:value)':':value').' WHERE user_id=:u AND conversation_id=:c',['value'=>is_bool($value)?(int)$value:$value,'u'=>$r->userId(),'c'=>$c['id']]);
        });Response::ok(null);
    }
    public static function respond(Request $r):void
    {
        if(!in_array($r->input('action'),['accept','decline'],true)||array_keys($r->all())!==['action'])Response::validationError('Choose accept or decline.');
        Database::transaction(static function()use($r):void {$c=self::access($r,true);if($c['kind']!=='direct'||(int)$c['requested_by']===$r->userId())Response::forbidden('Only the recipient can answer this request.');if(BlockRepository::either((int)$c['pair_low'],(int)$c['pair_high']))Response::notFound();Database::execute('UPDATE conversations SET request_state=:s WHERE id=:id',['s'=>$r->input('action')==='accept'?'accepted':'declined','id'=>$c['id']]);});Response::ok(null);
    }
    public static function changeMessage(Request $r):void
    {
        $fields=$r->all();if(count($fields)!==1 || (!array_key_exists('body',$fields)&&!array_key_exists('removed',$fields)))Response::validationError('Edit text or change unsend state.');
        if($r->has('body'))(new Validator())->string('body',$r->input('body'),1,4000)->bail();else if(!is_bool($r->input('removed')))Response::validationError('Use true or false.');
        Database::transaction(static function()use($r):void {$c=self::access($r,true);if(!$c['can_send'])Response::forbidden('This conversation is read-only.');$m=Database::queryOne('SELECT m.*,v.body,v.removed,v.edited FROM chat_messages m JOIN chat_versions v ON v.id=(SELECT MAX(id) FROM chat_versions WHERE message_id=m.id) WHERE m.id=:id AND m.conversation_id=:c',['id'=>(int)$r->param('messageId'),'c'=>$c['id']]);if($m===null)Response::notFound();if((int)$m['author_id']!==$r->userId())Response::forbidden('Only the author can change this message.');if($r->has('body') && ($m['removed'] || strtotime((string)$m['created_at'].' UTC')<time()-900))Response::error('conflict','Messages can be edited for 15 minutes.',409);Database::execute('INSERT INTO chat_versions(message_id,body,removed,edited) VALUES(:id,:body,:removed,:edited)',['id'=>$m['id'],'body'=>$r->input('body',$m['body']),'removed'=>$r->has('removed')?(int)$r->input('removed'):(int)$m['removed'],'edited'=>$r->has('body')?1:(int)$m['edited']]);});Response::ok(null);
    }
    public static function react(Request $r):void
    {
        $emoji=$r->input('emoji');if(($emoji!==null&&!in_array($emoji,['❤️','👍','😂','😮','😢','🙏','🎉','👏'],true))||array_keys($r->all())!==['emoji'])Response::validationError('Choose a supported reaction.');
        Database::transaction(static function()use($r,$emoji):void{$c=self::access($r,true);if(!$c['can_send'])Response::forbidden('This conversation is read-only.');$m=Database::queryOne('SELECT m.id,v.removed FROM chat_messages m JOIN chat_versions v ON v.id=(SELECT MAX(id) FROM chat_versions WHERE message_id=m.id) WHERE m.id=:id AND m.conversation_id=:c',['id'=>(int)$r->param('messageId'),'c'=>$c['id']]);if($m===null||$m['removed'])Response::notFound();if($emoji===null)Database::execute('DELETE FROM chat_reactions WHERE message_id=:m AND user_id=:u',['m'=>$m['id'],'u'=>$r->userId()]);else Database::execute('INSERT INTO chat_reactions(message_id,user_id,emoji) VALUES(:id,:u,:e) ON DUPLICATE KEY UPDATE emoji=VALUES(emoji)',['id'=>$m['id'],'u'=>$r->userId(),'e'=>$emoji]);});Response::ok(null);
    }
    public static function privacy(Request $r):void
    {
        if($r->method==='PATCH'){
            if(array_keys($r->all())!==['who_can_message'] || !in_array($r->input('who_can_message'),['all','existing','none'],true))Response::validationError('Choose all, existing or none.');
            Database::execute('INSERT INTO chat_privacy(user_id,who_can_message) VALUES(:u,:p) ON DUPLICATE KEY UPDATE who_can_message=VALUES(who_can_message)',['u'=>$r->userId(),'p'=>$r->input('who_can_message')]);
        }
        Response::header('Cache-Control','private, no-store');$p=Database::queryOne('SELECT who_can_message FROM chat_privacy WHERE user_id=:u',['u'=>$r->userId()]);Response::ok(['who_can_message'=>$p['who_can_message']??'all']);
    }
    public static function contacts(Request $r):void
    {
        Response::header('Cache-Control','private, no-store');$limit=$r->queryInt('limit',30,1,100);$offset=$r->queryInt('offset',0,0,1000000);$rows=Database::query("SELECT DISTINCT u.id,u.display_name FROM users u JOIN group_members b ON b.user_id=u.id AND b.status='active' JOIN group_members a ON a.group_id=b.group_id AND a.user_id=:u AND a.status='active' WHERE u.id<>:self AND u.status='active' ORDER BY u.display_name,u.id LIMIT :lim OFFSET :off",['u'=>$r->userId(),'self'=>$r->userId(),'lim'=>$limit+1,'off'=>$offset]);$more=count($rows)>$limit;if($more)array_pop($rows);Response::ok(['items'=>array_map(static fn(array $v):array=>[...$v,'id'=>(int)$v['id']],$rows),'has_more'=>$more]);
    }
    public static function report(Request $r):void
    {
        $reason=$r->input('reason');$note=$r->input('note','');$message=$r->input('message_id');
        if(!is_int($message)||$message<1||array_diff(array_keys($r->all()),['reason','note','message_id'])!==[])Response::validationError('Choose one message to report.');
        (new Validator())->enum('reason',$reason,['spam','harassment','hate','nudity','violence','privateInfo','other'])->string('note',$note,0,2000)->bail();
        Database::transaction(static function()use($r,$reason,$note,$message):void {
            $c=self::access($r,true);if($c['kind']!=='direct')Response::validationError('Group member reports go to group admins.');
            $m=Database::queryOne('SELECT m.author_id,v.body,v.removed FROM chat_messages m JOIN chat_versions v ON v.id=(SELECT MAX(id) FROM chat_versions WHERE message_id=m.id) WHERE m.id=:id AND m.conversation_id=:c',['id'=>$message,'c'=>$c['id']]);
            if($m===null||$m['removed'])Response::notFound('This message is not available.');if((int)$m['author_id']===$r->userId())Response::validationError('Choose a message from the other person.');
            if(Database::queryOne('SELECT id FROM direct_chat_reports WHERE message_id=:m AND reporter_id=:u',['m'=>$message,'u'=>$r->userId()])!==null)return;
            $n=Database::queryOne('SELECT COUNT(*) n FROM direct_chat_reports WHERE reporter_id=:u AND created_at>DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 HOUR)',['u'=>$r->userId()]);if((int)($n['n']??0)>=10)Response::error('rate_limited','Please wait before sending more reports.',429);
            Database::execute('INSERT INTO direct_chat_reports(conversation_id,message_id,reporter_id,reported_user_id,reason,note,excerpt) VALUES(:c,:m,:u,:a,:r,:n,:text)',['c'=>$c['id'],'m'=>$message,'u'=>$r->userId(),'a'=>(int)$m['author_id'],'r'=>$reason,'n'=>$note,'text'=>$m['body']]);
        });Response::ok(null,'Report saved privately for server administrator review.');
    }
    public static function pushMessage(Request $r):void
    {
        Response::header('Cache-Control','private, no-store');$c=self::access($r);$id=(int)$r->param('messageId');$m=Database::queryOne('SELECT m.id,v.removed FROM chat_messages m JOIN chat_versions v ON v.id=(SELECT MAX(id) FROM chat_versions WHERE message_id=m.id) WHERE m.id=:id AND m.conversation_id=:c',['id'=>$id,'c'=>$c['id']]);if($m===null)Response::notFound();$s=Database::queryOne('SELECT muted,read_id FROM chat_states WHERE user_id=:u AND conversation_id=:c',['u'=>$r->userId(),'c'=>$c['id']]);$allowed=FeatureNotifications::chatEligible($id,$r->userId());Response::ok(['id'=>$id,'conversation_id'=>(int)$c['id'],'notification_allowed'=>$allowed && !$m['removed'] && !(bool)($s['muted']??false) && (int)($s['read_id']??0)<$id]);
    }
}
