<?php

declare(strict_types=1);

namespace Circle\Middleware;

use Circle\Core\JWT;
use Circle\Core\Request;
use Circle\Core\Response;

final class AuthMiddleware
{
    public static function handle(Request $request, callable $next): void
    {
        $token = $request->bearerToken();
        if ($token === null) {
            Response::unauthorized('Missing authorization token.');
        }

        $userId = JWT::validateAccess($token);
        if ($userId === null) {
            Response::unauthorized('Invalid or expired token.');
        }

        $request = $request->withAttr('user_id', $userId);
        $next($request);
    }
}
