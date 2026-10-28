<?php

declare(strict_types=1);
namespace Circle\Tests;
use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Controllers\PollController;

/** Two real connections reproduce a stale repeatable-read authorization snapshot. */
final class PollLockTest extends ApiTestCase
{
    public function testWriteVisibilityUsesCommittedMembershipAndMemoryStateAfterOldSnapshot():void
    {
        self::assertSame('circle_test',Database::queryOne('SELECT DATABASE() name')['name']);
        $a=$this->user();$b=$this->user('Member');$g=$this->createGroup($a);$this->join($a,$b,$g);$m=$this->createMemory($a,$g,'Fictional memory');
        $other=new \PDO('mysql:host='.Env::get('DB_HOST').';port='.Env::get('DB_PORT').';dbname=circle_test;charset=utf8mb4',Env::get('DB_USERNAME'),Env::get('DB_PASSWORD'),[\PDO::ATTR_ERRMODE=>\PDO::ERRMODE_EXCEPTION]);
        $candidate=['group_id'=>$g,'memory_id'=>$m,'event_id'=>null];
        $changed=false;
        Database::execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
        $visible=PollController::write(static function()use($g,$b,$other,$candidate,&$changed):bool {
            if(!$changed){
                self::assertSame('active',Database::queryOne('SELECT status FROM group_members WHERE group_id=:g AND user_id=:u',['g'=>$g,'u'=>$b['id']])['status']);
                $other->exec("UPDATE group_members SET status='left' WHERE group_id=".$g.' AND user_id='.$b['id']);
                $changed=true;
            }
            return PollController::visible($candidate,$b['id'],true);
        });
        self::assertFalse($visible);
        $other->exec("UPDATE group_members SET status='active' WHERE group_id=".$g.' AND user_id='.$b['id']);
        $changed=false;
        Database::execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
        $visible=PollController::write(static function()use($m,$b,$other,$candidate,&$changed):bool {
            if(!$changed){
                self::assertSame('active',Database::queryOne('SELECT status FROM memories WHERE id=:m',['m'=>$m])['status']);
                $other->exec("UPDATE memories SET status='hidden' WHERE id=".$m);
                $changed=true;
            }
            return PollController::visible($candidate,$b['id'],true);
        });
        self::assertFalse($visible);
        $other->exec("UPDATE group_members SET role='admin' WHERE group_id=".$g.' AND user_id='.$b['id']);
        $changed=false;
        Database::execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
        $manage=PollController::write(static function()use($a,$g,$b,$other,$candidate,&$changed):bool {
            if(!$changed){
                self::assertSame('admin',Database::queryOne('SELECT role FROM group_members WHERE group_id=:g AND user_id=:u',['g'=>$g,'u'=>$b['id']])['role']);
                $other->exec("UPDATE group_members SET role='member' WHERE group_id=".$g.' AND user_id='.$b['id']);
                $changed=true;
            }
            return PollController::canManage([...$candidate,'created_by'=>$a['id']],$b['id'],true);
        });
        self::assertFalse($manage);
    }

    public function testOptionCapAndDuplicateRetryAtCapacityRemainEnforced():void
    {
        $a=$this->user();$b=$this->user('Member');$g=$this->createGroup($a);$this->join($a,$b,$g);
        $id=$this->request('POST',"/api/v1/groups/$g/polls",['question'=>'Fictional choices','options'=>array_map(static fn(int $i):string=>'Choice '.$i,range(1,12)),'allow_add_options'=>true,'client_id'=>'fictional-poll-capacity-01'],$a['token'])->data()['id'];
        self::assertSame(409,$this->request('POST',"/api/v1/polls/$id/options",['label'=>'Thirteenth'],$b['token'])->status());
        self::assertSame(200,$this->request('POST',"/api/v1/polls/$id/options",['label'=>' choice 1 '],$b['token'])->status());
        self::assertCount(12,$this->request('GET',"/api/v1/polls/$id",[],$a['token'])->data()['options']);
    }
}
