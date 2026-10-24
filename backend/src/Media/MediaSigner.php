<?php

declare(strict_types=1);

namespace Circle\Media;

use Circle\Core\ConfigException;
use Circle\Core\Env;

/**
 * Short-lived signed media links: hex HMAC-SHA256 over "id|size|expires" with
 * MEDIA_SIGNING_SECRET, which must be ≥ 32 bytes, not a placeholder and
 * different from JWT_SECRET. Media endpoints refuse to work otherwise.
 */
final class MediaSigner
{
    public const MIN_SECRET_BYTES = 32;
    public const DEFAULT_TTL = 300;

    private const PLACEHOLDER_SECRETS = ['changeme', 'secret'];

    public static function secret(): string
    {
        $secret = Env::get('MEDIA_SIGNING_SECRET');
        if (strlen($secret) < self::MIN_SECRET_BYTES
            || in_array(strtolower($secret), self::PLACEHOLDER_SECRETS, true)
            || str_starts_with(strtolower($secret), 'change-this')
            || hash_equals(Env::get('JWT_SECRET'), $secret)
        ) {
            throw new ConfigException('MEDIA_SIGNING_SECRET is missing, shorter than 32 bytes, a placeholder or equal to JWT_SECRET.');
        }
        return $secret;
    }

    /** Link lifetime in seconds (MEDIA_LINK_TTL, clamped to 30..3600). */
    public static function ttl(): int
    {
        return max(30, min(3600, Env::int('MEDIA_LINK_TTL', self::DEFAULT_TTL)));
    }

    public static function sign(string $mediaId, string $size, int $expires): string
    {
        return hash_hmac('sha256', $mediaId . '|' . $size . '|' . $expires, self::secret());
    }

    /** Constant-time check of signature and expiry. */
    public static function verify(string $mediaId, string $size, string $expires, string $sig, int $now): bool
    {
        if (preg_match('/^\d{1,12}$/', $expires) !== 1 || preg_match('/^[0-9a-f]{64}$/', $sig) !== 1) {
            return false;
        }
        $valid = hash_equals(self::sign($mediaId, $size, (int) $expires), $sig);
        return $valid && (int) $expires >= $now;
    }

    /** Relative (to the API base) signed path. */
    public static function path(string $mediaId, string $size, int $expires): string
    {
        return '/media/files/' . $mediaId . '/' . $size
            . '?expires=' . $expires . '&sig=' . self::sign($mediaId, $size, $expires);
    }
}
