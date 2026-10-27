<?php

declare(strict_types=1);

namespace Circle\Middleware;

use Circle\Core\Database;
use Circle\Core\JWT;
use Circle\Core\Request;
use Circle\Core\Response;

final class AuthMiddleware
{
    /**
     * Requires a valid access token whose session is still open and whose user is active.
     * Attaches `user_id` and `session_id` to the request.
     */
    public static function handle(Request $request, callable $next): void
    {
        $token = $request->bearerToken();
        if ($token === null) {
            Response::unauthorized('Missing authorization token.');
        }

        $claims = JWT::validateAccess($token);
        if ($claims === null) {
            Response::unauthorized('Invalid or expired token.', 'invalid_token');
        }

        $user = Database::queryOne(
            'SELECT u.status,
                    EXISTS(SELECT 1 FROM refresh_tokens rt
                           WHERE rt.user_id = u.id AND rt.session_id = :sid
                             AND rt.revoked_at IS NULL AND rt.expires_at > NOW()) AS session_open
             FROM users u WHERE u.id = :uid',
            ['sid' => $claims['session_id'], 'uid' => $claims['user_id']]
        );

        if ($user === null || $user['status'] === 'deleted' || (int) $user['session_open'] !== 1) {
            Response::unauthorized('Invalid or expired token.', 'invalid_token');
        }

        if ($user['status'] !== 'active') {
            Response::forbidden('This account is not active.', 'account_inactive');
        }

        \Circle\Repositories\LoginSessionRepository::touch($claims['user_id'], $claims['session_id'], $request);

        $next($request
            ->withAttr('user_id', $claims['user_id'])
            ->withAttr('session_id', $claims['session_id']));
    }
}
