<?php

declare(strict_types=1);

namespace Circle\Middleware;

use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Core\Request;
use Circle\Core\Response;

final class RateLimitMiddleware
{
    public static function handle(Request $request, callable $next): void
    {
        $ip = $request->ip();
        $limit = Env::int('RATE_LIMIT_PER_MINUTE', 60);
        $window = 60;

        self::cleanup();

        $count = Database::queryOne(
            'SELECT COUNT(*) AS cnt FROM rate_limits WHERE ip = :ip AND created_at > DATE_SUB(NOW(), INTERVAL :window SECOND)',
            ['ip' => $ip, 'window' => $window]
        );

        if ($count !== null && (int) $count['cnt'] >= $limit) {
            header("Retry-After: {$window}");
            Response::tooMany();
        }

        Database::execute(
            'INSERT INTO rate_limits (ip, created_at) VALUES (:ip, NOW())',
            ['ip' => $ip]
        );

        $next($request);
    }

    public static function authHandle(Request $request, callable $next): void
    {
        $ip = $request->ip();
        $limit = Env::int('RATE_LIMIT_AUTH_PER_MINUTE', 10);
        $window = 60;

        $count = Database::queryOne(
            'SELECT COUNT(*) AS cnt FROM rate_limits WHERE ip = :ip AND endpoint = :ep AND created_at > DATE_SUB(NOW(), INTERVAL :window SECOND)',
            ['ip' => $ip, 'ep' => 'auth', 'window' => $window]
        );

        if ($count !== null && (int) $count['cnt'] >= $limit) {
            header("Retry-After: {$window}");
            Response::tooMany('Too many authentication attempts. Please try again later.');
        }

        Database::execute(
            'INSERT INTO rate_limits (ip, endpoint, created_at) VALUES (:ip, :ep, NOW())',
            ['ip' => $ip, 'ep' => 'auth']
        );

        $next($request);
    }

    private static function cleanup(): void
    {
        // Cleanup old entries older than 5 minutes (runs probabilistically)
        if (random_int(1, 20) === 1) {
            Database::execute('DELETE FROM rate_limits WHERE created_at < DATE_SUB(NOW(), INTERVAL 5 MINUTE)');
        }
    }
}
