<?php

declare(strict_types=1);
namespace Circle\Repositories;
use Circle\Core\Database;
final class BlockRepository
{
    public static function either(int $first,int $second): bool
    {
        return $first!==$second && Database::queryOne('SELECT blocker_id FROM user_blocks WHERE (blocker_id=:a AND blocked_id=:b) OR (blocker_id=:c AND blocked_id=:d) LIMIT 1',['a'=>$first,'b'=>$second,'c'=>$second,'d'=>$first])!==null;
    }
}
