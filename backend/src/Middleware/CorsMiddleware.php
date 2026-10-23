<?php

declare(strict_types=1);

namespace Circle\Middleware;

use Circle\Core\Env;
use Circle\Core\Request;

final class CorsMiddleware
{
    public static function handle(Request $request, callable $next): void
    {
        $origin = Env::get('CORS_ORIGIN', '*');
        header("Access-Control-Allow-Origin: {$origin}");
        header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');
        header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Idempotency-Key');
        header('Access-Control-Max-Age: 86400');

        $next($request);
    }
}
