<?php

declare(strict_types=1);

namespace Circle\Middleware;

use Circle\Core\Env;
use Circle\Core\Request;
use Circle\Core\Response;

/**
 * Applied to every request (including OPTIONS preflight) by App::handle.
 * CORS_ORIGIN is a comma-separated allowlist of exact origins; the request
 * Origin is echoed back only when it is listed. Unset means no cross-origin
 * browser access (the Flutter mobile app does not need CORS). Credentials are
 * never allowed: the API uses bearer tokens, not cookies.
 */
final class CorsMiddleware
{
    public static function apply(Request $request): void
    {
        Response::header('Vary', 'Origin');

        $origin = $request->header('origin');
        if ($origin === '') {
            return;
        }

        $allowed = array_values(array_filter(array_map('trim', explode(',', Env::get('CORS_ORIGIN')))));
        if (in_array('*', $allowed, true)) {
            Response::header('Access-Control-Allow-Origin', '*');
        } elseif (in_array($origin, $allowed, true)) {
            Response::header('Access-Control-Allow-Origin', $origin);
        } else {
            return;
        }

        Response::header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
        Response::header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Idempotency-Key');
        Response::header('Access-Control-Max-Age', '600');
    }
}
