<?php

declare(strict_types=1);
namespace Circle\Controllers;
use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Core\Validator;
use Circle\Repositories\MemberRepository;
use Circle\Middleware\RateLimitMiddleware;
use Circle\Notifications\PollNotifications;

final class PollController
{
    /** Retry a rolled-back snapshot/deadlock conflict with fresh authorization reads.
     * @template T
     * @param callable():T $work
     * @return T
     */
    public static function write(callable $work):mixed
    {
        for($attempt=0;;$attempt++){
            try{return Database::transaction($work);}
            catch(\PDOException $e){
                if(!in_array((int)($e->errorInfo[1]??0),[1020,1213],true))throw $e;
                if($attempt>=2)Response::error('conflict','This poll changed while saving. Refresh and try again.',409);
            }
        }
    }
    /** @param array<string,mixed> $p */
    public static function visible(array $p,int $user,bool $lock=false):bool
    {
        // Read mutable status after locking the immutable membership/context key.
        $suffix=$lock?' FOR UPDATE':'';
        $member=Database::queryOne('SELECT status FROM group_members WHERE group_id=:g AND user_id=:u'.$suffix,['g'=>$p['group_id'],'u'=>$user]);
        if($member===null||$member['status']!=='active')return false;
        if($p['memory_id']!==null){
            $memory=Database::queryOne('SELECT status FROM memories WHERE id=:id AND group_id=:g'.$suffix,['id'=>$p['memory_id'],'g'=>$p['group_id']]);
            if($memory===null||$memory['status']!=='active')return false;
        }
        if($p['event_id']!==null&&Database::queryOne('SELECT id FROM events WHERE id=:id AND group_id=:g'.$suffix,['id'=>$p['event_id'],'g'=>$p['group_id']])===null)return false;
        return true;
    }
    /** @param array<string,mixed> $p */
    public static function canManage(array $p,int $user,bool $lock=false):bool
    {
        $m=Database::queryOne('SELECT role,status FROM group_members WHERE group_id=:g AND user_id=:u'.($lock?' FOR UPDATE':''),['g'=>$p['group_id'],'u'=>$user]);
        return $m!==null&&$m['status']==='active'&&((int)$p['created_by']===$user||$m['role']==='admin');
    }
    /** @return array<string,mixed> */
    private static function access(Request $r,bool $write=false):array
    {
        $p=Database::queryOne('SELECT * FROM polls WHERE id=:id',['id'=>(int)$r->param('pollId')]);if($p===null)Response::notFound('This poll is not available.');
        if($write){Database::queryOne('SELECT id FROM `groups` WHERE id=:g FOR UPDATE',['g'=>$p['group_id']]);$p=Database::queryOne('SELECT * FROM polls WHERE id=:id FOR UPDATE',['id'=>$p['id']]);if($p===null)Response::notFound();self::session($r);}
        if(!self::visible($p,$r->userId(),$write))Response::notFound('This poll is not available.');return $p;
    }
    private static function session(Request $r):void
    {
        if(Database::queryOne('SELECT id FROM refresh_tokens WHERE user_id=:u AND session_id=:s AND revoked_at IS NULL AND expires_at>UTC_TIMESTAMP() FOR UPDATE',['u'=>$r->userId(),'s'=>$r->attr('session_id')])===null)Response::unauthorized();
    }
    /** @param array<string,mixed> $p */
    public static function closed(array $p):bool{return $p['closed_at']!==null||($p['closes_at']!==null&&$p['closes_at']<=gmdate('Y-m-d H:i:s'));}
    public static function index(Request $r):void
    {
        Response::header('Cache-Control','private, no-store');$g=$r->queryInt('group_id',0,0,PHP_INT_MAX);$event=$r->queryInt('event_id',0,0,PHP_INT_MAX);$memory=$r->queryInt('memory_id',0,0,PHP_INT_MAX);$limit=$r->queryInt('limit',30,1,100);$offset=$r->queryInt('offset',0,0,1000000);
        $rows=Database::query("SELECT p.* FROM polls p JOIN group_members gm ON gm.group_id=p.group_id AND gm.user_id=:u AND gm.status='active' LEFT JOIN memories m ON m.id=p.memory_id WHERE (:allg=0 OR p.group_id=:g) AND (:alle=0 OR p.event_id=:e) AND (:allm=0 OR p.memory_id=:m) AND (p.memory_id IS NULL OR (m.status='active')) ORDER BY p.id DESC LIMIT :lim OFFSET :off",['u'=>$r->userId(),'allg'=>$g,'g'=>$g,'alle'=>$event,'e'=>$event,'allm'=>$memory,'m'=>$memory,'lim'=>$limit+1,'off'=>$offset]);$more=count($rows)>$limit;if($more)array_pop($rows);Response::ok(['items'=>array_map(static fn(array $p):array=>self::payload($p,$r->userId()),$rows),'has_more'=>$more]);
    }
    public static function create(Request $r):void
    {
        $f=$r->all();$allowed=['question','options','poll_type','anonymous','allow_add_options','results_visibility','allow_change_vote','closes_at','client_id','memory_id','event_id'];if(array_diff(array_keys($f),$allowed)!==[])Response::validationError('Choose supported poll settings.');
        $f=array_replace(['poll_type'=>'single','anonymous'=>false,'allow_add_options'=>false,'results_visibility'=>'always','allow_change_vote'=>true,'closes_at'=>null,'memory_id'=>null,'event_id'=>null],$f);
        (new Validator())->string('question',$f['question']??null,1,500)->enum('poll_type',$f['poll_type'],['single','multiple'])->enum('results_visibility',$f['results_visibility'],['always','after_voting','after_closing'])->bail();
        foreach(['anonymous','allow_add_options','allow_change_vote'] as $k)if(!is_bool($f[$k]))Response::validationError('Use true or false for poll settings.');
        foreach(['memory_id','event_id'] as $k)if($f[$k]!==null&&(!is_int($f[$k])||$f[$k]<1))Response::validationError('Choose a valid audience.');
        if($f['memory_id']!==null&&$f['event_id']!==null)Response::validationError('Choose one poll context.');
        if(!is_string($f['client_id']??null)||!preg_match('/^[a-zA-Z0-9_-]{16,100}$/',$f['client_id']))Response::validationError('Include a valid send id.');
        $options=$f['options']??null;if(!is_array($options)||!array_is_list($options)||count($options)<2||count($options)>12)Response::validationError('Add 2–12 options.');$labels=[];
        foreach($options as $label){(new Validator())->string('option',$label,1,200)->bail();$labels[]=trim($label);}if(in_array('',$labels,true)||count(array_unique(array_map(mb_strtolower(...),$labels)))!==count($labels))Response::validationError('Options must be different and non-empty.');
        if(trim($f['question'])==='')Response::validationError('Add a question.');$f['question']=trim($f['question']);
        if($f['closes_at']!==null){if(!is_string($f['closes_at'])||!preg_match('/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:Z|[+-]\d\d:\d\d)$/',$f['closes_at']))Response::validationError('Choose a valid end time with offset.');try{$d=new \DateTimeImmutable($f['closes_at']);}catch(\Exception){Response::validationError('Choose a valid end time.');}$errors=\DateTimeImmutable::getLastErrors();if(($errors!==false&&($errors['warning_count']||$errors['error_count']))||$d->getTimestamp()>2147483647)Response::validationError('Choose a valid end time before2038.');$f['closes_at']=$d->setTimezone(new \DateTimeZone('UTC'))->format('Y-m-d H:i:s');}
        $f['options']=$labels;ksort($f);
        $g=(int)$r->param('id');$hash=hash('sha256',json_encode([$g,$f,$labels],JSON_THROW_ON_ERROR));
        $id=self::write(static function()use($r,$f,$labels,$g,$hash):int{
            Database::queryOne('SELECT id FROM `groups` WHERE id=:g FOR UPDATE',['g'=>$g]);MemberRepository::requireActiveMember($g,$r->userId());self::session($r);
            $candidate=['group_id'=>$g,'memory_id'=>$f['memory_id'],'event_id'=>$f['event_id']];if(!self::visible($candidate,$r->userId(),true))Response::notFound('This audience is not available.');
            $old=Database::queryOne('SELECT id,request_hash FROM polls WHERE created_by=:u AND client_id=:c FOR UPDATE',['u'=>$r->userId(),'c'=>$f['client_id']]);if($old!==null){if(!hash_equals((string)$old['request_hash'],$hash))Response::error('conflict','This send id is already used.',409);return (int)$old['id'];}
            if($f['closes_at']!==null&&$f['closes_at']<=gmdate('Y-m-d H:i:s'))Response::validationError('Choose a future end time.');
            if($f['event_id']!==null&&Database::queryOne("SELECT id FROM events WHERE id=:id AND status='active'",['id'=>$f['event_id']])===null)Response::error('conflict','This event is cancelled.',409);
            RateLimitMiddleware::consumeForUser($r->userId(),'poll_create',20,3600,'Please wait before creating more polls.');
            Database::execute('INSERT INTO polls(group_id,created_by,client_id,request_hash,question,poll_type,anonymous,allow_add_options,results_visibility,allow_change_vote,closes_at,memory_id,event_id) VALUES(:g,:u,:client_id,:hash,:question,:poll_type,:anonymous,:allow_add_options,:results_visibility,:allow_change_vote,:closes_at,:memory_id,:event_id)',['g'=>$g,'u'=>$r->userId(),'hash'=>$hash,...array_diff_key($f,['options'=>true])]);$id=Database::lastInsertId();foreach($labels as $i=>$label)Database::execute('INSERT INTO poll_options(poll_id,label,sort_order,added_by) VALUES(:p,:l,:s,:u)',['p'=>$id,'l'=>$label,'s'=>$i,'u'=>$r->userId()]);PollNotifications::capture($id,'poll.created',$r->userId());return $id;
        });Response::ok(['id'=>$id,'group_id'=>$g]);
    }
    public static function show(Request $r):void{Response::header('Cache-Control','private, no-store');Response::ok(self::payload(self::access($r),$r->userId()));}
    /** @param array<string,mixed> $p
     * @return array<string,mixed> */
    private static function payload(array $p,int $user):array
    {
        $mine=array_map('intval',array_column(Database::query('SELECT option_id FROM poll_votes WHERE poll_id=:p AND user_id=:u ORDER BY option_id',['p'=>$p['id'],'u'=>$user]),'option_id'));$closed=self::closed($p);$results=$p['results_visibility']==='always'||$closed||($p['results_visibility']==='after_voting'&&$mine!==[]);
        $options=Database::query('SELECT o.id,o.label,COUNT(v.id) votes FROM poll_options o LEFT JOIN poll_votes v ON v.option_id=o.id AND v.poll_id=o.poll_id WHERE o.poll_id=:p GROUP BY o.id,o.label,o.sort_order ORDER BY o.sort_order,o.id',['p'=>$p['id']]);foreach($options as &$o){$o['id']=(int)$o['id'];if($results)$o['votes']=(int)$o['votes'];else unset($o['votes']);}unset($o);
        $out=[];foreach(['id','group_id','created_by','memory_id','event_id','question','poll_type','results_visibility','closes_at'] as $k)$out[$k]=$p[$k];foreach(['id','group_id','created_by','memory_id','event_id'] as $k)if($out[$k]!==null)$out[$k]=(int)$out[$k];if($out['closes_at']!==null)$out['closes_at']=str_replace(' ','T',(string)$out['closes_at']).'Z';foreach(['anonymous','allow_add_options','allow_change_vote'] as $k)$out[$k]=(bool)$p[$k];
        $out['group_name']=Database::queryOne('SELECT name FROM `groups` WHERE id=:id',['id'=>$p['group_id']])['name']??'Circle';
        return [...$out,'closed'=>$closed,'options'=>$options,'my_votes'=>$mine,'results_available'=>$results,'voter_count'=>$results?(int)(Database::queryOne('SELECT COUNT(DISTINCT user_id) n FROM poll_votes WHERE poll_id=:p',['p'=>$p['id']])['n']??0):null,'can_manage'=>self::canManage($p,$user),'notification_allowed'=>true];
    }
    public static function vote(Request $r):void
    {
        $ids=$r->input('option_ids');if(array_keys($r->all())!==['option_ids']||!is_array($ids)||!array_is_list($ids)||count($ids)>12||count(array_unique(array_filter($ids,'is_int')))!==count($ids))Response::validationError('Choose valid options.');sort($ids);
        self::write(static function()use($r,$ids):void{$p=self::access($r,true);$old=array_map('intval',array_column(Database::query('SELECT option_id FROM poll_votes WHERE poll_id=:p AND user_id=:u ORDER BY option_id FOR UPDATE',['p'=>$p['id'],'u'=>$r->userId()]),'option_id'));if($old===$ids)return;if(self::closed($p))Response::error('conflict','This poll is closed.',409);if(!$p['allow_change_vote']&&$old!==[])Response::error('conflict','Votes cannot be changed in this poll.',409);if($p['poll_type']==='single'&&count($ids)>1)Response::validationError('Choose one option.');foreach($ids as $id)if(Database::queryOne('SELECT id FROM poll_options WHERE id=:id AND poll_id=:p FOR UPDATE',['id'=>$id,'p'=>$p['id']])===null)Response::validationError('Choose options from this poll.');RateLimitMiddleware::consumeForUser($r->userId(),'poll_vote',120,60,'Please wait before voting again.');Database::execute('DELETE FROM poll_votes WHERE poll_id=:p AND user_id=:u',['p'=>$p['id'],'u'=>$r->userId()]);foreach($ids as $id)Database::execute('INSERT INTO poll_votes(poll_id,option_id,user_id) VALUES(:p,:o,:u)',['p'=>$p['id'],'o'=>$id,'u'=>$r->userId()]);});self::show($r);
    }
    public static function addOption(Request $r):void
    {
        $label=$r->input('label');(new Validator())->string('label',$label,1,200)->bail();if(array_keys($r->all())!==['label']||trim($label)==='')Response::validationError('Add an option.');$label=trim($label);
        self::write(static function()use($r,$label):void{$p=self::access($r,true);if(self::closed($p))Response::error('conflict','This poll is closed.',409);if(!$p['allow_add_options'])Response::forbidden('Adding options is disabled.');$options=Database::query('SELECT label FROM poll_options WHERE poll_id=:p FOR UPDATE',['p'=>$p['id']]);foreach($options as $o)if(mb_strtolower((string)$o['label'])===mb_strtolower($label))return;if(count($options)>=12)Response::error('conflict','This poll already has12 options.',409);Database::execute('INSERT INTO poll_options(poll_id,label,sort_order,added_by) VALUES(:p,:l,:s,:u)',['p'=>$p['id'],'l'=>$label,'s'=>count($options),'u'=>$r->userId()]);});self::show($r);
    }
    public static function close(Request $r):void
    {
        if(!$r->jsonIsObject()||$r->all()!==[])Response::validationError('No fields are needed.');self::write(static function()use($r):void{$p=self::access($r,true);if(!self::canManage($p,$r->userId(),true))Response::forbidden('Only the creator or group admins can close this poll.');Database::execute('UPDATE polls SET closed_at=COALESCE(closed_at,UTC_TIMESTAMP()) WHERE id=:id',['id'=>$p['id']]);PollNotifications::closed((int)$p['id'],$r->userId());});self::show($r);
    }
    public static function voters(Request $r):void
    {
        Response::header('Cache-Control','private, no-store');$p=self::access($r);if($p['anonymous']||!self::payload($p,$r->userId())['results_available'])Response::forbidden('Voter identities are private for this poll.');$limit=$r->queryInt('limit',30,1,100);$offset=$r->queryInt('offset',0,0,1000000);$rows=Database::query('SELECT u.id,u.display_name,v.option_id,o.label FROM poll_votes v JOIN users u ON u.id=v.user_id JOIN poll_options o ON o.id=v.option_id AND o.poll_id=v.poll_id WHERE v.poll_id=:p ORDER BY v.user_id,v.option_id LIMIT :lim OFFSET :off',['p'=>$p['id'],'lim'=>$limit+1,'off'=>$offset]);$more=count($rows)>$limit;if($more)array_pop($rows);foreach($rows as &$v){$v['id']=(int)$v['id'];$v['option_id']=(int)$v['option_id'];}Response::ok(['items'=>$rows,'has_more'=>$more]);
    }
}
