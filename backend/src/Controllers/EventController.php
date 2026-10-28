<?php

declare(strict_types=1);
namespace Circle\Controllers;
use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Core\Validator;
use Circle\Repositories\MemberRepository;
use Circle\Notifications\FeatureNotifications;
final class EventController
{
    public const FIELDS=['title','description','event_type','venue','online_link','start_at','end_at','timezone','rsvp_deadline','max_capacity'];
    /** @return array<string,mixed> */
    private static function access(Request $r,bool $write=false):array
    {
        $e=Database::queryOne('SELECT * FROM events WHERE id=:id',['id'=>(int)$r->param('eventId')]);if($e===null)Response::notFound('This event is not available.');
        if($write){Database::queryOne('SELECT id FROM `groups` WHERE id=:g FOR UPDATE',['g'=>$e['group_id']]);$e=Database::queryOne('SELECT * FROM events WHERE id=:id FOR UPDATE',['id'=>$e['id']]);if($e===null)Response::notFound();self::session($r);}
        if(!MemberRepository::isActiveMember((int)$e['group_id'],$r->userId()))Response::notFound('This event is not available.');return $e;
    }
    private static function session(Request $r):void {if(Database::queryOne('SELECT id FROM refresh_tokens WHERE user_id=:u AND session_id=:s AND revoked_at IS NULL AND expires_at>UTC_TIMESTAMP() FOR UPDATE',['u'=>$r->userId(),'s'=>$r->attr('session_id')])===null)Response::unauthorized();}
    public static function index(Request $r):void
    {
        Response::header('Cache-Control','private, no-store');$limit=$r->queryInt('limit',30,1,100);$offset=$r->queryInt('offset',0,0,1000000);$g=$r->queryInt('group_id',0,0,PHP_INT_MAX);if($g>0)MemberRepository::requireActiveMember($g,$r->userId());
        $rows=Database::query("SELECT e.* FROM events e JOIN group_members gm ON gm.group_id=e.group_id AND gm.user_id=:u AND gm.status='active' WHERE (:all_groups=0 OR e.group_id=:g) ORDER BY (e.start_at>=UTC_TIMESTAMP()) DESC,IF(e.start_at>=UTC_TIMESTAMP(),e.start_at,NULL) ASC,e.start_at DESC,e.id DESC LIMIT :lim OFFSET :off",['u'=>$r->userId(),'all_groups'=>$g,'g'=>$g,'lim'=>$limit+1,'off'=>$offset]);$more=count($rows)>$limit;if($more)array_pop($rows);Response::ok(['items'=>array_map(self::payload(...),$rows),'has_more'=>$more]);
    }
    public static function show(Request $r):void
    {
        Response::header('Cache-Control','private, no-store');$e=self::access($r);$data=self::payload($e);$mine=Database::queryOne('SELECT status,guest_count,note FROM event_rsvps WHERE event_id=:e AND user_id=:u',['e'=>$e['id'],'u'=>$r->userId()]);if($mine!==null)$mine['guest_count']=(int)$mine['guest_count'];$data['my_rsvp']=$mine;$data['can_manage']=(int)$e['created_by']===$r->userId()||MemberRepository::isAdmin((int)$e['group_id'],$r->userId());$data['going_count']=(int)(Database::queryOne("SELECT COALESCE(SUM(1+guest_count),0) n FROM event_rsvps WHERE event_id=:e AND status='going'",['e'=>$e['id']])['n']??0);Response::ok($data);
    }
    /** @param array<string,mixed> $f
     * @return array<string,mixed>
     */
    private static function validate(array $f):array
    {
        foreach(['title'=>200,'description'=>10000,'venue'=>500,'online_link'=>1000] as $k=>$max)(new Validator())->string($k,$f[$k]??'', $k==='title'?1:0,$max)->bail();
        (new Validator())->enum('event_type',$f['event_type'],['function','wedding','reunion','meetup','birthday','trip','online','other'])->bail();
        if(!is_string($f['timezone']??null)||!in_array($f['timezone'],\DateTimeZone::listIdentifiers(\DateTimeZone::ALL_WITH_BC),true))Response::validationError('Choose a valid IANA time zone.');
        foreach(['start_at','end_at','rsvp_deadline'] as $key){
            if(($f[$key]??null)===null){if($key==='start_at')Response::validationError('Choose a start time.');$f[$key]=null;continue;}
            if(!is_string($f[$key])||!preg_match('/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:Z|[+-]\d\d:\d\d)$/',$f[$key]))Response::validationError('Use an ISO date and time with an offset.');
            try{$time=new \DateTimeImmutable($f[$key]);}catch(\Exception){Response::validationError('Choose a valid date and time.');}
            $errors=\DateTimeImmutable::getLastErrors();if(($errors!==false&&($errors['warning_count']>0||$errors['error_count']>0))||$time->getTimestamp()<1||$time->getTimestamp()>2147483647)Response::validationError('Choose a supported date before 2038.');$f[$key]=$time->setTimezone(new \DateTimeZone('UTC'))->format('Y-m-d H:i:s');
        }
        if(($f['end_at']!==null&&$f['end_at']<=$f['start_at'])||($f['rsvp_deadline']!==null&&$f['rsvp_deadline']>$f['start_at']))Response::validationError('End must follow start; deadline must not follow start.');
        if($f['max_capacity']!==null&&(!is_int($f['max_capacity'])||$f['max_capacity']<1||$f['max_capacity']>100000))Response::validationError('Capacity must be 1–100000 or empty.');
        $link=$f['online_link'];if($link!==''&&(filter_var($link,FILTER_VALIDATE_URL)===false||parse_url($link,PHP_URL_SCHEME)!=='https'||parse_url($link,PHP_URL_USER)!==null))Response::validationError('Use a valid HTTPS meeting link.');
        if(trim($f['venue'])===''&&$link==='')Response::validationError('Add a place or meeting link.');return $f;
    }
    public static function create(Request $r):void
    {
        $key=$r->input('client_id');if(!is_string($key)||!preg_match('/^[a-zA-Z0-9_-]{16,100}$/',$key)||array_diff(array_keys($r->all()),[...self::FIELDS,'client_id'])!==[])Response::validationError('Include a valid send id and supported event fields.');
        $f=$r->all();unset($f['client_id']);$f=self::validate(array_replace(['description'=>'','event_type'=>'other','venue'=>'','online_link'=>'','end_at'=>null,'rsvp_deadline'=>null,'max_capacity'=>null],$f));$g=(int)$r->param('id');
        $id=Database::transaction(static function()use($r,$f,$key,$g):int {
            $group=Database::queryOne('SELECT id,event_creation FROM `groups` WHERE id=:g FOR UPDATE',['g'=>$g]);MemberRepository::requireActiveMember($g,$r->userId());self::session($r);if(($group['event_creation']??'members')==='admins'&&!MemberRepository::isAdmin($g,$r->userId()))Response::forbidden('Only admins can create events in this group.');
            $old=Database::queryOne('SELECT * FROM events WHERE created_by=:u AND client_id=:c',['u'=>$r->userId(),'c'=>$key]);if($old!==null){if((int)$old['group_id']!==$g)Response::error('conflict','This event send id is already used.',409);foreach($f as $k=>$v)if(($old[$k]===null?null:(string)$old[$k])!==($v===null?null:(string)$v))Response::error('conflict','This event send id is already used.',409);return (int)$old['id'];}
            if($f['start_at']<=gmdate('Y-m-d H:i:s'))Response::validationError('Choose a future start time.');$n=Database::queryOne('SELECT COUNT(*) n FROM events WHERE created_by=:u AND created_at>DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 HOUR)',['u'=>$r->userId()]);if((int)($n['n']??0)>=20)Response::error('rate_limited','Please wait before creating more events.',429);
            Database::execute('INSERT INTO events(group_id,created_by,client_id,title,description,event_type,venue,online_link,start_at,end_at,timezone,rsvp_deadline,max_capacity) VALUES(:g,:u,:c,:title,:description,:event_type,:venue,:online_link,:start_at,:end_at,:timezone,:rsvp_deadline,:max_capacity)',['g'=>$g,'u'=>$r->userId(),'c'=>$key,...$f]);$id=Database::lastInsertId();FeatureNotifications::event($id,'event.created',$r->userId());FeatureNotifications::event($id,'event.reminder',$r->userId());return $id;
        });Response::ok(['id'=>$id,'group_id'=>$g]);
    }
    public static function update(Request $r):void
    {
        $all=$r->all();$version=$r->input('version');if(!is_int($version)||count($all)<2||array_diff(array_keys($all),[...self::FIELDS,'version','status'])!==[])Response::validationError('Include the current version and supported changes.');
        Database::transaction(static function()use($r,$all,$version):void {
            $e=self::access($r,true);if((int)$e['created_by']!==$r->userId()&&!MemberRepository::isAdmin((int)$e['group_id'],$r->userId()))Response::forbidden('Only organizers or group admins can edit.');if((int)$e['version']!==$version||$e['status']!=='active')Response::error('conflict','Event changed or was cancelled. Refresh and try again.',409);if($r->has('status')&&$all['status']!=='cancelled')Response::validationError('Only cancellation is supported.');
            $f=[];foreach(self::FIELDS as $key)$f[$key]=array_key_exists($key,$all)?$all[$key]:$e[$key];foreach(['start_at','end_at','rsvp_deadline'] as $key)if(!array_key_exists($key,$all)&&$f[$key]!==null)$f[$key]=str_replace(' ','T',(string)$f[$key]).'Z';if(!array_key_exists('max_capacity',$all)&&$f['max_capacity']!==null)$f['max_capacity']=(int)$f['max_capacity'];$f=self::validate($f);
            if($f['start_at']!==$e['start_at']&&$f['start_at']<=gmdate('Y-m-d H:i:s'))Response::validationError('Choose a future start time.');$count=(int)(Database::queryOne("SELECT COALESCE(SUM(1+guest_count),0) n FROM event_rsvps WHERE event_id=:e AND status='going'",['e'=>$e['id']])['n']??0);if($f['max_capacity']!==null&&$f['max_capacity']<$count)Response::error('conflict','Capacity is below existing attendance.',409);
            $status=$all['status']??'active';Database::execute('UPDATE events SET title=:title,description=:description,event_type=:event_type,venue=:venue,online_link=:online_link,start_at=:start_at,end_at=:end_at,timezone=:timezone,rsvp_deadline=:rsvp_deadline,max_capacity=:max_capacity,status=:status,version=version+1 WHERE id=:id',[...$f,'status'=>$status,'id'=>$e['id']]);Database::execute("UPDATE notification_outbox SET state='cancelled',last_error='event_changed' WHERE event_id=:id AND state='pending'",['id'=>$e['id']]);FeatureNotifications::event((int)$e['id'],$status==='cancelled'?'event.cancelled':'event.updated',$r->userId());if($status==='active')FeatureNotifications::event((int)$e['id'],'event.reminder',$r->userId());
        });self::show($r);
    }
    public static function rsvp(Request $r):void
    {
        $s=$r->input('status');$g=$r->input('guest_count',0);$note=$r->input('note','');(new Validator())->enum('status',$s,['going','maybe','not_going'])->intRange('guest_count',$g,0,10)->string('note',$note,0,500)->bail();if(array_diff(array_keys($r->all()),['status','guest_count','note'])!==[])Response::validationError('Unsupported RSVP fields.');
        Database::transaction(static function()use($r,$s,$g,$note):void {
            $e=self::access($r,true);if($e['status']!=='active'||$e['start_at']<=gmdate('Y-m-d H:i:s')||($e['rsvp_deadline']!==null&&$e['rsvp_deadline']<=gmdate('Y-m-d H:i:s')))Response::error('conflict','RSVPs are closed.',409);$g=$s==='going'?$g:0;
            $old=Database::queryOne('SELECT status,guest_count,note FROM event_rsvps WHERE event_id=:e AND user_id=:u',['e'=>$e['id'],'u'=>$r->userId()]);if($old!==null&&$old['status']===$s&&(int)$old['guest_count']===$g&&$old['note']===$note)return;
            $count=(int)(Database::queryOne("SELECT COALESCE(SUM(1+guest_count),0) n FROM event_rsvps WHERE event_id=:e AND user_id<>:u AND status='going'",['e'=>$e['id'],'u'=>$r->userId()])['n']??0);if($s==='going'&&$e['max_capacity']!==null&&$count+1+$g>(int)$e['max_capacity'])Response::error('conflict','This event is at capacity.',409);
            Database::execute('INSERT INTO event_rsvps(event_id,user_id,status,guest_count,note) VALUES(:e,:u,:s,:g,:n) ON DUPLICATE KEY UPDATE status=VALUES(status),guest_count=VALUES(guest_count),note=VALUES(note)',['e'=>$e['id'],'u'=>$r->userId(),'s'=>$s,'g'=>$g,'n'=>$note]);FeatureNotifications::event((int)$e['id'],'event.rsvp',$r->userId());
        });self::show($r);
    }
    public static function attendees(Request $r):void
    {
        Response::header('Cache-Control','private, no-store');$e=self::access($r);$limit=$r->queryInt('limit',30,1,100);$offset=$r->queryInt('offset',0,0,1000000);$rows=Database::query('SELECT u.id,u.display_name,a.status,a.guest_count FROM event_rsvps a JOIN users u ON u.id=a.user_id WHERE a.event_id=:id ORDER BY a.id LIMIT :lim OFFSET :off',['id'=>$e['id'],'lim'=>$limit+1,'off'=>$offset]);$more=count($rows)>$limit;if($more)array_pop($rows);Response::ok(['items'=>array_map(static fn(array $v):array=>[...$v,'id'=>(int)$v['id'],'guest_count'=>(int)$v['guest_count']],$rows),'has_more'=>$more]);
    }
    /** @param array<string,mixed> $e
     * @return array<string,mixed>
     */
    private static function payload(array $e):array
    {
        $out=[];foreach(['id','group_id','created_by',...self::FIELDS,'status','version'] as $key)$out[$key]=$e[$key];foreach(['id','group_id','created_by','max_capacity','version'] as $key)if($out[$key]!==null)$out[$key]=(int)$out[$key];foreach(['start_at','end_at','rsvp_deadline'] as $key)if($out[$key]!==null)$out[$key]=str_replace(' ','T',(string)$out[$key]).'Z';return $out;
    }
}
