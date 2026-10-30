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
final class FcmSender implements \Circle\Notifications\PushTransport
{
    private static ?string $accessToken = null;
    private static int $tokenExpiry = 0;

    public function isReady(): bool
    {
        return Env::get('FCM_PROJECT_ID') !== '' && function_exists('curl_init') && self::credentials() !== null;
    }

    /** @param array<string, string> $data */
    public function send(string $token, array $data): \Circle\Notifications\PushResult
    {
        if (!$this->isReady()) return \Circle\Notifications\PushResult::retry();
        $accessToken = self::getAccessToken();
        if ($accessToken === null) return \Circle\Notifications\PushResult::retry();
        $ttl = min(86400, (int) ($data['expires_at'] ?? 0) - time());
        if ($ttl <= 0) return \Circle\Notifications\PushResult::permanent();
        $project = rawurlencode(Env::get('FCM_PROJECT_ID'));
        $retryAfter = '';
        $ch = curl_init("https://fcm.googleapis.com/v1/projects/{$project}/messages:send");
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_HTTPHEADER => ['Authorization: Bearer ' . $accessToken, 'Content-Type: application/json'],
            CURLOPT_POSTFIELDS => json_encode(['message' => self::message($token, $data, $ttl)], JSON_THROW_ON_ERROR),
            CURLOPT_RETURNTRANSFER => true, CURLOPT_CONNECTTIMEOUT => 5, CURLOPT_TIMEOUT => 10,
            CURLOPT_PROTOCOLS => CURLPROTO_HTTPS,
            CURLOPT_HEADERFUNCTION => static function ($handle, string $line) use (&$retryAfter): int {
                if (stripos($line, 'Retry-After:') === 0) $retryAfter = trim(substr($line, 12));
                return strlen($line);
            },
        ]);
        $response = curl_exec($ch);
        $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        if ($status === 401) self::$accessToken = null;
        return self::classify($status, is_string($response) ? $response : '', $retryAfter);
    }

    /** @param array<string,string> $data
     * @return array<string,mixed>
     */
    public static function message(string $token, array $data, int $ttl): array
    {
        return ['token' => $token, 'data' => $data,
            'android' => ['priority' => 'normal', 'ttl' => $ttl . 's'],
            'apns' => ['headers' => ['apns-push-type' => 'alert', 'apns-priority' => '10',
                'apns-collapse-id' => hash('sha256', $data['event_id'] ?? ''),
                'apns-expiration' => (string)(time() + $ttl)],
                'payload' => ['aps' => ['alert' => ['title' => 'CIRCLE',
                    'body' => 'You have a new update. Open CIRCLE to view it.'], 'sound' => 'default']]]];
    }

    public static function classify(int $status, string $body, string $retryAfter = ''): \Circle\Notifications\PushResult
    {
        $json = json_decode($body, true);
        if ($status === 200 && is_array($json) && is_string($json['name'] ?? null) && $json['name'] !== '') return \Circle\Notifications\PushResult::sent();
        if (self::isUnregistered($status, $body)) return \Circle\Notifications\PushResult::invalid();
        if ($status === 0 || in_array($status, [200, 401, 403, 408, 429], true) || $status >= 500) {
            $after = ctype_digit($retryAfter) ? min(604800, (int) $retryAfter) : max(0, (strtotime($retryAfter) ?: time()) - time());
            return \Circle\Notifications\PushResult::retry($after);
        }
        return \Circle\Notifications\PushResult::permanent();
    }

    /** @return array{private_key: string, client_email: string, token_uri: string}|null */
    private static function credentials(): ?array
    {
        $path = Env::get('FCM_SERVICE_ACCOUNT_PATH');
        if ($path === '' || !is_file($path) || !is_readable($path)) return null;
        $raw = @file_get_contents($path);
        $key = is_string($raw) ? json_decode($raw, true) : null;
        if (!is_array($key) || !is_string($key['private_key'] ?? null) || !is_string($key['client_email'] ?? null)
            || ($key['token_uri'] ?? '') !== 'https://oauth2.googleapis.com/token'
            || openssl_pkey_get_private($key['private_key']) === false) return null;
        return ['private_key' => $key['private_key'], 'client_email' => $key['client_email'], 'token_uri' => $key['token_uri']];
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

        $key = self::credentials();
        if ($key === null) return null;

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
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_PROTOCOLS      => CURLPROTO_HTTPS,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($httpCode !== 200) {
            self::log("OAuth2 token request failed (HTTP {$httpCode})");
            return null;
        }

        $token = json_decode((string) $response, true);
        if (!is_array($token) || !is_string($token['access_token'] ?? null) || $token['access_token'] === '') {
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
