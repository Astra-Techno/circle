<?php

declare(strict_types=1);

namespace Circle\Core;

/**
 * Minimal HS256 JWT. Tokens must carry exp, iat, sub, sid, jti and type.
 */
final class JWT
{
    /** Values shipped in .env.example or commonly copied from docs; never accepted. */
    private const PLACEHOLDER_SECRETS = [
        'change-this-to-a-random-64-char-string',
        'changeme',
        'secret',
    ];

    public const MIN_SECRET_BYTES = 32;

    /** Returns the signing secret or throws when it is missing, short or a placeholder. */
    public static function secret(): string
    {
        $secret = Env::get('JWT_SECRET');
        if (strlen($secret) < self::MIN_SECRET_BYTES
            || in_array(strtolower($secret), self::PLACEHOLDER_SECRETS, true)
            || str_starts_with(strtolower($secret), 'change-this')
        ) {
            throw new ConfigException('JWT_SECRET is missing, shorter than 32 bytes or a placeholder.');
        }
        return $secret;
    }

    /**
     * @param array<string, mixed> $payload
     */
    public static function encode(array $payload, string $secret): string
    {
        $header = self::base64url(['alg' => 'HS256', 'typ' => 'JWT']);
        $body = self::base64url($payload);
        $signature = self::sign("{$header}.{$body}", $secret);
        return "{$header}.{$body}.{$signature}";
    }

    /**
     * Verifies signature, algorithm and a mandatory, unexpired `exp`.
     * @return array<string, mixed>|null
     */
    public static function decode(string $token, string $secret): ?array
    {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            return null;
        }

        [$header, $body, $signature] = $parts;

        $expectedSig = self::sign("{$header}.{$body}", $secret);
        if (!hash_equals($expectedSig, $signature)) {
            return null;
        }

        $head = json_decode(self::base64urlDecode($header), true);
        if (!is_array($head) || ($head['alg'] ?? null) !== 'HS256') {
            return null;
        }

        $payload = json_decode(self::base64urlDecode($body), true);
        if (!is_array($payload)) {
            return null;
        }

        if (!isset($payload['exp']) || !is_int($payload['exp']) || $payload['exp'] <= time()) {
            return null;
        }

        return $payload;
    }

    /** @param array<string, mixed> $data */
    private static function base64url(array $data): string
    {
        return rtrim(strtr(base64_encode(
            json_encode($data, JSON_THROW_ON_ERROR)
        ), '+/', '-_'), '=');
    }

    private static function base64urlDecode(string $data): string
    {
        return base64_decode(strtr($data, '-_', '+/'), true) ?: '';
    }

    private static function sign(string $data, string $secret): string
    {
        return rtrim(strtr(base64_encode(
            hash_hmac('sha256', $data, $secret, true)
        ), '+/', '-_'), '=');
    }

    /**
     * Generate a pair of access + refresh tokens for a user session.
     * Each token gets a random jti so two tokens issued in the same second differ.
     * @return array{access_token: string, refresh_token: string, token_type: string, expires_in: int}
     */
    public static function issueTokens(int $userId, string $sessionId): array
    {
        $secret = self::secret();
        $accessExpiry = Env::int('JWT_EXPIRY', 3600);
        $refreshExpiry = Env::int('JWT_REFRESH_EXPIRY', 604800);
        $now = time();

        $accessToken = self::encode([
            'sub' => $userId,
            'sid' => $sessionId,
            'jti' => bin2hex(random_bytes(16)),
            'iat' => $now,
            'exp' => $now + $accessExpiry,
            'type' => 'access',
        ], $secret);

        $refreshToken = self::encode([
            'sub' => $userId,
            'sid' => $sessionId,
            'jti' => bin2hex(random_bytes(16)),
            'iat' => $now,
            'exp' => $now + $refreshExpiry,
            'type' => 'refresh',
        ], $secret);

        return [
            'access_token' => $accessToken,
            'refresh_token' => $refreshToken,
            'token_type' => 'Bearer',
            'expires_in' => $accessExpiry,
        ];
    }

    /** @return array{user_id: int, session_id: string}|null */
    public static function validateAccess(string $token): ?array
    {
        return self::validate($token, 'access');
    }

    /** @return array{user_id: int, session_id: string}|null */
    public static function validateRefresh(string $token): ?array
    {
        return self::validate($token, 'refresh');
    }

    /** @return array{user_id: int, session_id: string}|null */
    private static function validate(string $token, string $type): ?array
    {
        $payload = self::decode($token, self::secret());
        if ($payload === null || ($payload['type'] ?? '') !== $type) {
            return null;
        }
        $sub = $payload['sub'] ?? null;
        $sid = $payload['sid'] ?? null;
        if (!is_int($sub) || $sub <= 0 || !is_string($sid) || $sid === '') {
            return null;
        }
        return ['user_id' => $sub, 'session_id' => $sid];
    }
}
