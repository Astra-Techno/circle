<?php

declare(strict_types=1);

namespace Circle\Core;

final class JWT
{
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

        $payload = json_decode(self::base64urlDecode($body), true);
        if (!is_array($payload)) {
            return null;
        }

        if (isset($payload['exp']) && $payload['exp'] < time()) {
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
     * Generate a pair of access + refresh tokens for a user.
     * @return array{access_token: string, refresh_token: string, expires_in: int}
     */
    public static function issueTokens(int $userId): array
    {
        $secret = Env::get('JWT_SECRET');
        $accessExpiry = Env::int('JWT_EXPIRY', 3600);
        $refreshExpiry = Env::int('JWT_REFRESH_EXPIRY', 604800);
        $now = time();

        $accessToken = self::encode([
            'sub' => $userId,
            'iat' => $now,
            'exp' => $now + $accessExpiry,
            'type' => 'access',
        ], $secret);

        $refreshToken = self::encode([
            'sub' => $userId,
            'iat' => $now,
            'exp' => $now + $refreshExpiry,
            'type' => 'refresh',
        ], $secret);

        return [
            'access_token' => $accessToken,
            'refresh_token' => $refreshToken,
            'expires_in' => $accessExpiry,
        ];
    }

    /**
     * Validate access token, return user ID or null.
     */
    public static function validateAccess(string $token): ?int
    {
        $payload = self::decode($token, Env::get('JWT_SECRET'));
        if ($payload === null || ($payload['type'] ?? '') !== 'access') {
            return null;
        }
        return (int) ($payload['sub'] ?? 0) ?: null;
    }

    /**
     * Validate refresh token, return user ID or null.
     */
    public static function validateRefresh(string $token): ?int
    {
        $payload = self::decode($token, Env::get('JWT_SECRET'));
        if ($payload === null || ($payload['type'] ?? '') !== 'refresh') {
            return null;
        }
        return (int) ($payload['sub'] ?? 0) ?: null;
    }
}
