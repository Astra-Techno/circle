<?php
/** Operator-only private review. Never expose through the HTTP document root. */
declare(strict_types=1);
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/../../vendor/autoload.php';
\Circle\Core\Env::load(__DIR__.'/../..');
use Circle\Core\Database;
$args=array_slice($argv,1);
if(($args[0]??'')==='reviewed' && ctype_digit($args[1]??'')){
 Database::execute("UPDATE direct_chat_reports SET state='reviewed',reviewed_at=UTC_TIMESTAMP() WHERE id=:id",['id'=>(int)$args[1]]);echo "Review state saved.\n";exit;
}
if(($args[0]??'')==='details' && ctype_digit($args[1]??'')){
 $row=Database::queryOne('SELECT * FROM direct_chat_reports WHERE id=:id',['id'=>(int)$args[1]]);if($row!==null)$row['photo_ids']=\Circle\Controllers\FeatureMediaController::attachments((int)$row['message_id']);echo json_encode($row,JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR)."\n";exit;
}
echo "Private direct-message reports. Access only as an authorized server operator.\n";
echo "Commands: details ID | reviewed ID. Details contain personal data: do not copy to public logs.\n";
foreach(Database::query("SELECT id,reason,created_at FROM direct_chat_reports WHERE state='open' ORDER BY id LIMIT 100") as $row)echo json_encode($row,JSON_THROW_ON_ERROR)."\n";
