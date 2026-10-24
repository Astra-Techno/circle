<?php

declare(strict_types=1);

namespace Circle\Middleware;

use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Core\Request;
use Circle\Core\Response;

/**
 * Fixed-window (60 s) limits stored in MySQL, keyed by client IP and bucket.
 * Buckets: `general` (RATE_LIMIT_PER_MINUTE), `auth` (RATE_LIMIT_AUTH_PER_MINUTE),
 * per-mobile failed logins (LOGIN_MAX_FAILURES_PER_MOBILE per 15 minutes) and
 * per-user hourly buckets such as `media_ticket` (MEDIA_UPLOADS_PER_HOUR).
 */
final class RateLimitMiddleware
{
    private const WINDOW_SECONDS = 60;
    private const LOGIN_FAILURE_WINDOW_SECONDS = 900;
    private const LONG_WINDOW_SECONDS = 3600;

    public static function handle(Request $request, callable $next): void
    {
        self::hit($request->ip(), 'general', Env::int('RATE_LIMIT_PER_MINUTE', 60), self::WINDOW_SECONDS);
        $next($request);
    }

    public static function authHandle(Request $request, callable $next): void
    {
        self::hit(
            $request->ip(),
            'auth',
            Env::int('RATE_LIMIT_AUTH_PER_MINUTE', 10),
            self::WINDOW_SECONDS,
            'Too many authentication attempts. Please try again later.'
        );
        $next($request);
    }

    /**
     * Per-user limit for a named bucket (e.g. upload tickets per hour). Windows
     * longer than one hour are not supported by the cleanup below.
     */
    public static function consumeForUser(int $userId, string $bucket, int $limit, int $window, string $message): void
    {
        self::hit('u:' . $userId, $bucket, $limit, min($window, self::LONG_WINDOW_SECONDS), $message);
    }

    /** Counts within the window; responds 429 when the limit is reached, else records the hit. */
    private static function hit(string $key, string $bucket, int $limit, int $window, string $message = 'Too many requests'): void
    {
        self::cleanup();

        if (self::count($key, $bucket, $window) >= $limit) {
            Response::header('Retry-After', (string) $window);
            Response::tooMany($message);
        }

        self::record($key, $bucket);
    }

    /** Key for per-mobile throttling; the raw number is never stored. */
    public static function mobileKey(string $mobile): string
    {
        return 'm:' . substr(hash('sha256', $mobile), 0, 40);
    }

    public static function tooManyLoginFailures(string $mobile): bool
    {
        return self::count(self::mobileKey($mobile), 'login_fail', self::LOGIN_FAILURE_WINDOW_SECONDS)
            >= Env::int('LOGIN_MAX_FAILURES_PER_MOBILE', 10);
    }

    public static function recordLoginFailure(string $mobile): void
    {
        self::record(self::mobileKey($mobile), 'login_fail');
    }

    private static function count(string $key, string $bucket, int $window): int
    {
        $row = Database::queryOne(
            'SELECT COUNT(*) AS cnt FROM rate_limits
             WHERE ip = :ip AND endpoint = :ep AND created_at > DATE_SUB(NOW(), INTERVAL :window SECOND)',
            ['ip' => $key, 'ep' => $bucket, 'window' => $window]
        );
        return (int) ($row['cnt'] ?? 0);
    }

    private static function record(string $key, string $bucket): void
    {
        Database::execute(
            'INSERT INTO rate_limits (ip, endpoint, created_at) VALUES (:ip, :ep, NOW())',
            ['ip' => $key, 'ep' => $bucket]
        );
    }

    private static function cleanup(): void
    {
        // Probabilistic cleanup of entries older than their bucket's longest window.
        if (random_int(1, 20) === 1) {
            Database::execute(
                'DELETE FROM rate_limits
                 WHERE created_at < DATE_SUB(NOW(), INTERVAL 20 MINUTE)
                   AND ip NOT LIKE :user_prefix',
                ['user_prefix' => 'u:%']
            );
            Database::execute(
                'DELETE FROM rate_limits WHERE created_at < DATE_SUB(NOW(), INTERVAL 61 MINUTE)'
            );
        }
    }
}
