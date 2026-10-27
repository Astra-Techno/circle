<?php

/**
 * One-time push notification test. Hit from browser:
 * https://circle.cloudkart24.com/push-test.php?key=YOUR_DEPLOY_KEY
 *
 * Sends a test push to ALL registered FCM tokens for verification.
 * DELETE this file after testing.
 */

declare(strict_types=1);

require_once __DIR__ . '/../vendor/autoload.php';

use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Core\FcmSender;

header('Content-Type: text/html; charset=utf-8');
echo '<pre style="font-family:monospace;font-size:14px;padding:20px;">';

// Auth check
$key = $_GET['key'] ?? '';
if ($key === '' || !hash_equals(Env::get('DEPLOY_KEY'), $key)) {
    echo "Unauthorized.\n";
    exit;
}

echo "=== CIRCLE Push Notification Test ===\n\n";

// 1. Check FCM config
$projectId = Env::get('FCM_PROJECT_ID');
$saPath = Env::get('FCM_SERVICE_ACCOUNT_PATH');
echo "FCM_PROJECT_ID: " . ($projectId ?: '(not set)') . "\n";
echo "FCM_SERVICE_ACCOUNT_PATH: " . ($saPath ?: '(not set)') . "\n";
echo "Service account file exists: " . (is_file($saPath) ? 'YES' : 'NO') . "\n";
echo "OpenSSL available: " . (function_exists('openssl_pkey_get_private') ? 'YES' : 'NO') . "\n";
echo "cURL available: " . (function_exists('curl_init') ? 'YES' : 'NO') . "\n\n";

// 2. Check FcmSender readiness
$sender = new FcmSender();
echo "FcmSender::isReady(): " . ($sender->isReady() ? 'YES' : 'NO') . "\n\n";

if (!$sender->isReady()) {
    echo "FCM is not ready. Check service account file and .env config.\n";
    exit;
}

// 3. Get registered device tokens
$db = Database::connection();
$tokens = $db->query(
    'SELECT dt.id, dt.fcm_token, dt.platform, dt.user_id, u.name, dt.created_at
     FROM device_tokens dt JOIN users u ON u.id = dt.user_id
     ORDER BY dt.created_at DESC LIMIT 20'
)->fetchAll(\PDO::FETCH_ASSOC);

echo "Registered devices: " . count($tokens) . "\n";
if (empty($tokens)) {
    echo "\nNo devices registered. Open the app, log in, and allow notifications first.\n";
    exit;
}

echo "\n";
foreach ($tokens as $i => $row) {
    $short = substr($row['fcm_token'], 0, 20) . '...';
    echo ($i + 1) . ". {$row['name']} ({$row['platform']}) - token: {$short} - registered: {$row['created_at']}\n";
}

// 4. Send test notification to each device
echo "\n=== Sending Test Notifications ===\n\n";

$now = time();
foreach ($tokens as $i => $row) {
    $data = [
        'type'       => 'test',
        'title'      => 'Circle Push Test',
        'body'       => 'If you see this, push notifications are working!',
        'event'      => 'push_test',
        'scope'      => 'system',
        'expires_at' => (string) ($now + 300), // 5 min TTL
        'sent_at'    => (string) $now,
    ];

    echo ($i + 1) . ". Sending to {$row['name']}... ";
    $result = $sender->send($row['fcm_token'], $data);
    echo $result->status->name . "\n";
    if ($result->status->name !== 'sent') {
        echo "   retryAfter: {$result->retryAfter}s\n";
    }
}

echo "\n=== Done ===\n";
echo "Check your Android device for the notification.\n";
echo '</pre>';
