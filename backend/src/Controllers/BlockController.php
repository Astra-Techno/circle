<?php

declare(strict_types=1);
namespace Circle\Controllers;
use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;
final class BlockController
{
    public static function index(Request $request): void
    {
        Response::header('Cache-Control','private, no-store');
        $limit=$request->queryInt('limit',50,1,100);$offset=$request->queryInt('offset',0,0,1000000);
        $rows=Database::query('SELECT blocked_id AS id,label AS display_name,created_at FROM user_blocks WHERE blocker_id=:id ORDER BY blocked_id LIMIT :lim OFFSET :off',['id'=>$request->userId(),'lim'=>$limit+1,'off'=>$offset]);
        $more=count($rows)>$limit;if($more)array_pop($rows);
        $rows=array_map(static fn(array $r):array=>[...$r,'id'=>(int)$r['id']],$rows);
        Response::ok(['items'=>$rows,'has_more'=>$more,'limit'=>$limit,'offset'=>$offset]);
    }
    public static function show(Request $request): void
    {
        Response::header('Cache-Control','private, no-store');
        $row=Database::queryOne('SELECT created_at FROM user_blocks WHERE blocker_id=:a AND blocked_id=:b',['a'=>$request->userId(),'b'=>(int)$request->param('userId')]);
        Response::ok(['blocked'=>$row!==null]);
    }
    public static function put(Request $request): void { self::mutate($request,true); }
    public static function delete(Request $request): void { self::mutate($request,false); }
    private static function mutate(Request $request,bool $block): void
    {
        $target=(int)$request->param('userId');$viewer=$request->userId();
        if($target===$viewer)Response::validationError('You cannot block yourself.');
        if(!$request->jsonIsObject() || $request->all()!==[])Response::validationError('No body fields are needed.');
        Database::transaction(static function()use($request,$target,$viewer,$block):void {
            $users=Database::query('SELECT id,display_name,status FROM users WHERE id IN (:a,:b) ORDER BY id FOR UPDATE',['a'=>$viewer,'b'=>$target]);
            foreach($users as $u)if((int)$u['id']===$viewer && $u['status']!=='active')Response::unauthorized();
            $session=Database::queryOne('SELECT id FROM refresh_tokens WHERE user_id=:uid AND session_id=:sid AND revoked_at IS NULL AND expires_at>UTC_TIMESTAMP() FOR UPDATE',['uid'=>$viewer,'sid'=>$request->attr('session_id')]);
            if($session===null)Response::unauthorized();
            $existing=Database::queryOne('SELECT blocker_id FROM user_blocks WHERE blocker_id=:a AND blocked_id=:b FOR UPDATE',['a'=>$viewer,'b'=>$target]);
            if($block && $existing===null) {
                $person=null;foreach($users as $u)if((int)$u['id']===$target)$person=$u;
                $shared=Database::queryOne("SELECT a.group_id FROM group_members a JOIN group_members b ON a.group_id=b.group_id WHERE a.user_id=:a AND b.user_id=:b AND a.status='active' AND b.status='active' LIMIT 1",['a'=>$viewer,'b'=>$target]);
                $received=Database::queryOne('SELECT id FROM group_invitations WHERE recipient_id=:a AND inviter_id=:b LIMIT 1',['a'=>$viewer,'b'=>$target]);
                $direct=Database::queryOne('SELECT id FROM conversations WHERE pair_low=:a AND pair_high=:b',['a'=>min($viewer,$target),'b'=>max($viewer,$target)]);
                if($person===null || $person['status']!=='active' || ($shared===null && $received===null && $direct===null))Response::notFound('This person is not available.');
                Database::execute('INSERT INTO user_blocks(blocker_id,blocked_id,label) VALUES(:a,:b,:label)',['a'=>$viewer,'b'=>$target,'label'=>$person['display_name']]);
                Database::execute("UPDATE group_invitations SET status='expired' WHERE status='pending' AND ((inviter_id=:a AND recipient_id=:b) OR (inviter_id=:c AND recipient_id=:d))",['a'=>$viewer,'b'=>$target,'c'=>$target,'d'=>$viewer]);
            } elseif(!$block) Database::execute('DELETE FROM user_blocks WHERE blocker_id=:a AND blocked_id=:b',['a'=>$viewer,'b'=>$target]);
        });
        Response::ok(null,$block?'Blocked.':'Unblocked.');
    }
}
