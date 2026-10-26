<?php

declare(strict_types=1);

namespace Circle\Core;

/**
 * Sends push notifications via Firebase Cloud Messaging HTTP v1 API.
 *
 * Requires a Firebase service account key JSON file. The path is read from
 * the FCM_SERVICE_ACCOUNT_PATH env variable.
 *
 * Legacy API (server key) is deprecated; this uses OAuth2 access tokens
 * from the service account for the v1 endpoint.
 */
final class FcmSender
{
    private static ?string $accessToken = null;
    private static int $tokenExpiry = 0;

    /**
     * Send a notification to specific user(s) by their user IDs.
     *
     * @param int[]  $userIds  Target user IDs
     * @param string $title    Notification title
     * @param string $body     Notification body text
     * @param array<string, string> $data     Optional data payload (key-value strings)
     */
    public static function sendToUsers(array $userIds, string $title, string $body, array $data = []): int
    {
        if (empty($userIds)) return 0;

        $db = Database::connection();
        $placeholders = implode(',', array_fill(0, count($userIds), '?'));
        $stmt = $db->prepare(
            "SELECT DISTINCT fcm_token FROM device_tokens WHERE user_id IN ($placeholders)"
        );
        $stmt->execute(array_values($userIds));
        $tokens = $stmt->fetchAll(\PDO::FETCH_COLUMN);

        $sent = 0;
        foreach ($tokens as $token) {
            if (self::send($token, $title, $body, $data)) {
                $sent++;
            }
        }
        return $sent;
    }

    /**
     * Send a notification to a single FCM token.
     * @param array<string, string> $data
     */
    public static function send(string $fcmToken, string $title, string $body, array $data = []): bool
    {
        $projectId = Env::get('FCM_PROJECT_ID', '');
        if ($projectId === '') {
            self::log('FCM_PROJECT_ID not set, skipping push notification');
            return false;
        }

        $accessToken = self::getAccessToken();
        if ($accessToken === null) return false;

        $message = [
            'message' => [
                'token' => $fcmToken,
                'notification' => [
                    'title' => $title,
                    'body'  => $body,
                ],
            ],
        ];

        if (!empty($data)) {
            // FCM data values must all be strings.
            $message['message']['data'] = array_map('strval', $data);
        }

        $url = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_HTTPHEADER     => [
                'Authorization: Bearer ' . $accessToken,
                'Content-Type: application/json',
            ],
            CURLOPT_POSTFIELDS     => json_encode($message),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 10,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($httpCode === 200) {
            return true;
        }

        // A project/route 404 does not establish that a device token expired.
        if (self::isUnregistered($httpCode, (string) $response)) {
            $db = Database::connection();
            $stmt = $db->prepare('DELETE FROM device_tokens WHERE fcm_token = ?');
            $stmt->execute([$fcmToken]);
            self::log("Removed stale FCM token");
        } else {
            self::log("FCM send failed (HTTP {$httpCode})");
        }

        return false;
    }

    public static function isUnregistered(int $status, string $response): bool
    {
        if ($status !== 404) return false;
        $payload = json_decode($response, true);
        if (!is_array($payload)) return false;
        $details = $payload['error']['details'] ?? [];
        if (!is_array($details)) return false;
        foreach ($details as $detail) {
            if (is_array($detail)
                && ($detail['@type'] ?? '') === 'type.googleapis.com/google.firebase.fcm.v1.FcmError'
                && ($detail['errorCode'] ?? '') === 'UNREGISTERED') return true;
        }
        return false;
    }

    private static function log(string $message): void
    {
        // Callers supply static operational messages, never provider payloads.
        error_log('[CIRCLE] fcm: ' . $message);
    }

    /**
     * Get an OAuth2 access token from the service account credentials.
     * Caches the token until 5 minutes before expiry.
     */
    private static function getAccessToken(): ?string
    {
        if (self::$accessToken !== null && time() < self::$tokenExpiry) {
            return self::$accessToken;
        }

        $keyPath = Env::get('FCM_SERVICE_ACCOUNT_PATH', '');
        if ($keyPath === '' || !file_exists($keyPath)) {
            self::log('FCM_SERVICE_ACCOUNT_PATH not set or file missing');
            return null;
        }

        $key = json_decode(file_get_contents($keyPath), true);
        if (!$key || !isset($key['private_key'], $key['client_email'], $key['token_uri'])) {
            self::log('Invalid service account key file');
            return null;
        }

        $now = time();
        $header = base64url_encode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
        $claims = base64url_encode(json_encode([
            'iss'   => $key['client_email'],
            'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud'   => $key['token_uri'],
            'iat'   => $now,
            'exp'   => $now + 3600,
        ]));

        $unsigned = "{$header}.{$claims}";
        $signature = '';
        $pkeyId = openssl_pkey_get_private($key['private_key']);
        if (!$pkeyId || !openssl_sign($unsigned, $signature, $pkeyId, OPENSSL_ALGO_SHA256)) {
            self::log('Failed to sign JWT with service account key');
            return null;
        }

        $jwt = $unsigned . '.' . base64url_encode($signature);

        $ch = curl_init($key['token_uri']);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => http_build_query([
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion'  => $jwt,
            ]),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 10,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($httpCode !== 200) {
            self::log("OAuth2 token request failed (HTTP {$httpCode})");
            return null;
        }

        $token = json_decode((string) $response, true);
        if (!isset($token['access_token'])) {
            self::log('OAuth2 response missing access_token');
            return null;
        }

        self::$accessToken = $token['access_token'];
        self::$tokenExpiry = $now + ($token['expires_in'] ?? 3600) - 300; // refresh 5 min early

        return self::$accessToken;
    }
}

/**
 * URL-safe base64 encoding (no padding).
 */
function base64url_encode(string $data): string
{
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}
