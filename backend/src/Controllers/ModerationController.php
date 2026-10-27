<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Core\Validator;
use Circle\Notifications\NotificationOutbox;
use Circle\Repositories\MemberRepository;

/** Exact-group reports. Reporter identities never leave the write-side table. */
final class ModerationController
{
    public const REASONS = ['spam','harassment','hate','nudity','violence','privateInfo','other'];

    /** Locks serialize moderation with membership/role changes and session revocation. */
    private static function lock(Request $request, bool $admin): int
    {
        $gid = (int) $request->param('id');
        if (Database::queryOne('SELECT id FROM `groups` WHERE id=:id FOR UPDATE', ['id'=>$gid]) === null) Response::forbidden();
        $user = Database::queryOne('SELECT status FROM users WHERE id=:id FOR UPDATE', ['id'=>$request->userId()]);
        $session = Database::queryOne('SELECT id FROM refresh_tokens WHERE user_id=:uid AND session_id=:sid AND revoked_at IS NULL AND expires_at>UTC_TIMESTAMP() FOR UPDATE', ['uid'=>$request->userId(),'sid'=>$request->attr('session_id')]);
        if ($user === null || $user['status'] !== 'active' || $session === null) Response::unauthorized();
        $member = Database::queryOne('SELECT role,status FROM group_members WHERE group_id=:gid AND user_id=:uid FOR UPDATE', ['gid'=>$gid,'uid'=>$request->userId()]);
        if ($member === null || $member['status'] !== 'active' || ($admin && $member['role'] !== 'admin')) Response::forbidden();
        return $gid;
    }

    /** @return array<string,mixed>|null */
    private static function content(int $gid, string $kind, int $id, bool $lock = false): ?array
    {
        $suffix = $lock ? ' FOR UPDATE' : '';
        return match ($kind) {
            'memory' => Database::queryOne('SELECT id,author_id,body,status FROM memories WHERE id=:id AND group_id=:gid' . $suffix, ['id'=>$id,'gid'=>$gid]),
            'comment' => Database::queryOne('SELECT c.id,c.author_id,c.body,c.status FROM comments c JOIN memories m ON m.id=c.memory_id WHERE c.id=:id AND m.group_id=:gid AND m.status<>\'removed\'' . $suffix, ['id'=>$id,'gid'=>$gid]),
            'member' => Database::queryOne('SELECT u.id,u.id AS author_id,u.display_name AS body,gm.status FROM group_members gm JOIN users u ON u.id=gm.user_id WHERE gm.user_id=:id AND gm.group_id=:gid' . $suffix, ['id'=>$id,'gid'=>$gid]),
            default => null,
        };
    }

    private static function summary(string $text): string
    {
        preg_match('/^.{0,500}/us', $text, $match);
        return $match[0] ?? '';
    }

    public static function create(Request $request): void
    {
        $kind=$request->string('kind'); $id=$request->input('target_id');
        $reason=$request->string('reason'); $note=$request->string('note');
        if ($request->has('note') && !is_string($request->input('note'))) Response::validationError('Use text for the optional note.');
        $v=new Validator(); $v->string('note',$note,0,500); $v->bail();
        if (!in_array($kind,['memory','comment','member'],true) || !is_int($id) || $id<1 || !in_array($reason,self::REASONS,true)) Response::validationError('Choose a supported item and report reason.');
        Database::transaction(static function () use ($request,$kind,$id,$reason,$note): void {
            $gid=self::lock($request,false);
            $content=self::content($gid,$kind,$id,true);
            if ($kind==='comment' && !MemoryController::commentIsVisible($id,$request->userId())) Response::notFound();
            if ($content===null || $content['status']!=='active') Response::notFound();
            if ((int)$content['author_id']===$request->userId()) Response::validationError('You cannot report your own content.');
            Database::execute('INSERT INTO moderation_targets(group_id,kind,target_id) VALUES(:gid,:kind,:target) ON DUPLICATE KEY UPDATE id=LAST_INSERT_ID(id)', ['gid'=>$gid,'kind'=>$kind,'target'=>$id]);
            $target=Database::queryOne('SELECT id FROM moderation_targets WHERE group_id=:gid AND kind=:kind AND target_id=:target FOR UPDATE', ['gid'=>$gid,'kind'=>$kind,'target'=>$id]);
            $existing=Database::queryOne('SELECT id FROM reports WHERE target_id=:t AND reporter_id=:u',['t'=>$target['id'],'u'=>$request->userId()]);
            if ($existing===null && (int)(Database::queryOne('SELECT COUNT(*) n FROM reports WHERE reporter_id=:u AND created_at>DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 HOUR)',['u'=>$request->userId()])['n']??0)>=10) Response::error('rate_limited','Try reporting again later.',429);
            $changed=Database::execute('INSERT IGNORE INTO reports(target_id,reporter_id,reason,note) VALUES(:target,:user,:reason,:note)', ['target'=>$target['id'],'user'=>$request->userId(),'reason'=>$reason,'note'=>$note===''?null:$note]);
            if ($changed>0) {
                Database::execute('UPDATE moderation_targets SET version=version+1,updated_at=UTC_TIMESTAMP() WHERE id=:id',['id'=>$target['id']]);
                NotificationOutbox::groupReportCreated($gid, (int)$target['id'], $request->userId());
            }
        });
        Response::ok(null,'Thanks. Group admins can review your report.');
    }

    public static function index(Request $request): void
    {
        Response::header('Cache-Control','private, no-store');
        $gid=(int)$request->param('id');
        MemberRepository::requireAdmin($gid,$request->userId());
        $offset=$request->queryInt('offset',0,0,1000000); $limit=$request->queryInt('limit',30,1,50);
        $rows=Database::query('SELECT t.* FROM moderation_targets t WHERE t.group_id=:gid AND (EXISTS(SELECT 1 FROM reports r WHERE r.target_id=t.id AND r.dismissed=0) OR (t.kind=\'memory\' AND EXISTS(SELECT 1 FROM memories m WHERE m.id=t.target_id AND m.status=\'hidden\')) OR (t.kind=\'comment\' AND EXISTS(SELECT 1 FROM comments c JOIN memories cm ON cm.id=c.memory_id WHERE c.id=t.target_id AND c.status=\'hidden\' AND cm.status<>\'removed\'))) ORDER BY t.updated_at DESC,t.id DESC LIMIT :lim OFFSET :off', ['gid'=>$gid,'lim'=>$limit+1,'off'=>$offset]);
        $more=count($rows)>$limit; if ($more) array_pop($rows);
        $items=[];
        foreach ($rows as $row) {
            $content=self::content($gid,(string)$row['kind'],(int)$row['target_id']);
            $reasons=Database::query('SELECT reason,COUNT(*) AS count FROM reports WHERE target_id=:id AND dismissed=0 GROUP BY reason ORDER BY reason',['id'=>$row['id']]);
            // Notes are intentionally not forwarded: their text may identify the reporter.
            $items[]=['id'=>(int)$row['id'],'kind'=>$row['kind'],'target_id'=>(int)$row['target_id'],'version'=>(int)$row['version'],'updated_at'=>$row['updated_at'],'summary'=>$content!==null && $content['status']!=='removed'?self::summary((string)$content['body']):null,'hidden'=>($content['status']??'')==='hidden','available'=>$content!==null && in_array($content['status'],['active','hidden'],true),'reasons'=>array_map(static fn(array $r):array=>['reason'=>$r['reason'],'count'=>(int)$r['count']],$reasons)];
        }
        $audit=Database::query('SELECT a.id,a.action,a.created_at,t.kind,t.target_id,u.display_name AS actor_name FROM moderation_audit a JOIN moderation_targets t ON t.id=a.target_id JOIN users u ON u.id=a.actor_id WHERE a.group_id=:gid ORDER BY a.id DESC LIMIT 50',['gid'=>$gid]);
        $audit=array_map(static fn(array $a):array=>[...$a,'id'=>(int)$a['id'],'target_id'=>(int)$a['target_id']],$audit);
        Response::ok(['group_id'=>$gid,'items'=>$items,'has_more'=>$more,'offset'=>$offset,'limit'=>$limit,'audit'=>$audit]);
    }

    public static function action(Request $request): void
    {
        $action=$request->string('action'); $version=$request->input('version');
        if (!in_array($action,['hide','unhide','dismiss','restore'],true) || !is_int($version) || $version<1) Response::validationError('Choose a current report action.');
        Database::transaction(static function () use ($request,$action,$version): void {
            $gid=self::lock($request,true);
            $target=Database::queryOne('SELECT * FROM moderation_targets WHERE id=:id AND group_id=:gid FOR UPDATE',['id'=>(int)$request->param('reportTargetId'),'gid'=>$gid]);
            if ($target===null) Response::notFound();
            if ((int)$target['version']!==$version) Response::error('conflict','Reports changed. Refresh before trying again.',409);
            $content=self::content($gid,(string)$target['kind'],(int)$target['target_id'],true);
            if ($action==='hide' || $action==='unhide') {
                if ($target['kind']==='member') Response::validationError('Members cannot be hidden. Use group member controls.');
                if ($content===null || !in_array($content['status'],['active','hidden'],true)) Response::error('conflict','This content is no longer available.',409);
                $table=$target['kind']==='memory'?'memories':'comments';
                Database::execute("UPDATE $table SET status=:status WHERE id=:id",['status'=>$action==='hide'?'hidden':'active','id'=>$target['target_id']]);
                if ($target['kind']==='memory') Database::execute('UPDATE media_assets ma JOIN memory_media_assets mma ON mma.media_id=ma.id SET ma.hidden_at=:hidden WHERE mma.memory_id=:mid AND ma.status=\'ready\'',['hidden'=>$action==='hide'?gmdate('Y-m-d H:i:s'):null,'mid'=>$target['target_id']]);
            } else {
                Database::execute('UPDATE reports SET dismissed=:dismissed WHERE target_id=:id',['dismissed'=>$action==='dismiss'?1:0,'id'=>$target['id']]);
            }
            Database::execute('UPDATE moderation_targets SET version=version+1,updated_at=UTC_TIMESTAMP() WHERE id=:id',['id'=>$target['id']]);
            Database::execute('INSERT INTO moderation_audit(group_id,target_id,actor_id,action) VALUES(:gid,:target,:actor,:action)',['gid'=>$gid,'target'=>$target['id'],'actor'=>$request->userId(),'action'=>$action]);
        });
        Response::ok(null,'Saved.');
    }
}
