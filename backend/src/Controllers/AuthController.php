<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Core\JWT;
use Circle\Core\Passwords;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Core\Validator;
use Circle\Middleware\RateLimitMiddleware;

/**
 * Mobile number + password accounts (ADR 0005).
 *
 * - Passwords are read byte-for-byte (never trimmed) and hashed with Argon2id.
 * - Registration never reveals whether a number is already registered: every
 *   valid request gets the same 202 response, and the client then signs in.
 * - Login failures are generic and always cost one Argon2id verification.
 */
final class AuthController
{
    /** Hard cap on login input to bound hashing work; longer input simply fails. */
    private const MAX_LOGIN_PASSWORD_BYTES = 1024;

    public static function register(Request $request): void
    {
        $mobile = $request->string('mobile');
        $password = $request->raw('password');
        $displayName = $request->string('display_name');

        $v = new Validator();
        $v->required('mobile', $mobile)->mobile($mobile);
        if ($password === '') {
            Response::validationError('password is required.');
        }
        $v->password($password);
        $v->string('display_name', $displayName, 0, 100, 'Display name');
        $v->bail();

        // Hash first so the "already registered" path costs the same.
        $passwordHash = Passwords::hash($password);

        $existing = Database::queryOne(
            'SELECT id FROM users WHERE mobile = :mobile',
            ['mobile' => $mobile]
        );

        if ($existing === null) {
            try {
                Database::execute(
                    'INSERT INTO users (mobile, password_hash, display_name) VALUES (:mobile, :hash, :name)',
                    ['mobile' => $mobile, 'hash' => $passwordHash, 'name' => $displayName]
                );
            } catch (\PDOException $e) {
                if (!Database::isDuplicateKey($e)) {
                    throw $e;
                }
                // Concurrent registration of the same number: same generic answer.
            }
        }

        Response::accepted(
            ['next' => 'login'],
            'If this number can be registered, your account is ready. Sign in to continue.'
        );
    }

    public static function login(Request $request): void
    {
        $mobile = $request->string('mobile');
        $password = $request->raw('password');

        if ($mobile === '' || $password === '') {
            Response::validationError('Mobile number and password are required.');
        }

        if (RateLimitMiddleware::tooManyLoginFailures($mobile)) {
            Response::header('Retry-After', '900');
            Response::tooMany('Too many sign-in attempts. Please try again later.');
        }

        $user = null;
        if (strlen($password) <= self::MAX_LOGIN_PASSWORD_BYTES && strlen($mobile) <= 20) {
            $user = Database::queryOne(
                'SELECT id, mobile, display_name, password_hash, status FROM users WHERE mobile = :mobile',
                ['mobile' => $mobile]
            );
        }

        $hash = $user !== null && $user['status'] !== 'deleted' ? (string) $user['password_hash'] : null;
        $verified = strlen($password) <= self::MAX_LOGIN_PASSWORD_BYTES
            ? Passwords::verify($password, $hash)
            : Passwords::verify('', null);

        if (!$verified || $user === null) {
            RateLimitMiddleware::recordLoginFailure($mobile);
            Response::unauthorized('Invalid mobile number or password.', 'invalid_credentials');
        }

        // Only someone holding the correct password learns the account state.
        if ($user['status'] !== 'active') {
            Response::forbidden('This account is not active.', 'account_inactive');
        }

        $userId = (int) $user['id'];

        if ($hash !== null && Passwords::needsRehash($hash)) {
            Database::execute(
                'UPDATE users SET password_hash = :hash WHERE id = :id',
                ['hash' => Passwords::hash($password), 'id' => $userId]
            );
        }

        $sessionId = bin2hex(random_bytes(16));
        $tokens = JWT::issueTokens($userId, $sessionId);
        self::storeRefreshToken($userId, $sessionId, $tokens['refresh_token']);

        Response::ok([
            'user' => [
                'id' => $userId,
                'mobile' => $user['mobile'],
                'display_name' => $user['display_name'],
            ],
            ...$tokens,
        ], 'Login successful.');
    }

    /**
     * Rotates the refresh token. The presented token is revoked atomically, so
     * a token can be redeemed exactly once.
     */
    public static function refresh(Request $request): void
    {
        $refreshToken = $request->raw('refresh_token');
        if ($refreshToken === '') {
            Response::validationError('Refresh token is required.');
        }

        $claims = JWT::validateRefresh($refreshToken);
        if ($claims === null) {
            Response::unauthorized('Invalid or expired refresh token.', 'invalid_token');
        }
        $userId = $claims['user_id'];
        $sessionId = $claims['session_id'];

        $tokens = Database::transaction(static function () use ($refreshToken, $userId, $sessionId): ?array {
            $stored = Database::queryOne(
                'SELECT rt.id, u.status
                 FROM refresh_tokens rt JOIN users u ON u.id = rt.user_id
                 WHERE rt.user_id = :uid AND rt.session_id = :sid AND rt.token_hash = :hash
                   AND rt.revoked_at IS NULL AND rt.expires_at > NOW()
                 FOR UPDATE',
                ['uid' => $userId, 'sid' => $sessionId, 'hash' => hash('sha256', $refreshToken)]
            );

            if ($stored === null) {
                Response::unauthorized('Invalid or expired refresh token.', 'invalid_token');
            }

            $revoked = Database::execute(
                'UPDATE refresh_tokens SET revoked_at = NOW() WHERE id = :id AND revoked_at IS NULL',
                ['id' => (int) $stored['id']]
            );
            if ($revoked !== 1) {
                Response::unauthorized('Invalid or expired refresh token.', 'invalid_token');
            }

            if ($stored['status'] !== 'active') {
                self::revokeSession($userId, $sessionId);
                return null;
            }

            $tokens = JWT::issueTokens($userId, $sessionId);
            self::storeRefreshToken($userId, $sessionId, $tokens['refresh_token']);
            return $tokens;
        });

        if ($tokens === null) {
            Response::forbidden('This account is not active.', 'account_inactive');
        }

        Response::ok($tokens, 'Tokens refreshed.');
    }

    /** Ends the current session: its refresh tokens and access tokens stop working. */
    public static function logout(Request $request): void
    {
        $sessionId = $request->attr('session_id');
        Database::transaction(static function () use ($request, $sessionId): void {
            self::revokeSession($request->userId(), is_string($sessionId) ? $sessionId : '');
        });

        Response::ok(null, 'Logged out.');
    }

    public static function me(Request $request): void
    {
        $user = Database::queryOne(
            "SELECT u.id, u.mobile, u.display_name, u.about, u.current_city, u.hometown, u.work, u.education, u.created_at,
                a.version AS avatar_version, c.version AS cover_version
             FROM users u LEFT JOIN profile_photos a ON a.user_id = u.id AND a.kind = 'avatar'
             LEFT JOIN profile_photos c ON c.user_id = u.id AND c.kind = 'cover'
             WHERE u.id = :id AND u.status = :s",
            ['id' => $request->userId(), 's' => 'active']
        );

        if ($user === null) {
            Response::notFound('User not found.');
        }

        $user['id'] = (int) $user['id'];
        $user['avatar_path'] = null; // Legacy field: private storage paths never leave the server.

        Response::ok($user);
    }

    public static function updateMe(Request $request): void
    {
        $sets = [];
        $params = ['id' => $request->userId()];

        foreach (['display_name' => 100, 'about' => 500, 'current_city' => 100,
            'hometown' => 100, 'work' => 100, 'education' => 150] as $field => $max) {
            if (!$request->has($field)) {
                continue;
            }
            if (!is_string($request->input($field))) {
                Response::validationError($field . ' must be text.');
            }
            $value = $request->string($field);
            (new Validator())->string($field, $value, $field === 'display_name' ? 1 : 0, $max, $field)->bail();
            // Field names come only from the fixed allowlist above.
            $sets[] = $field . ' = :' . $field;
            $params[$field] = $value;
        }

        if ($sets === []) {
            Response::validationError('No fields to update.');
        }

        Database::execute(
            'UPDATE users SET ' . implode(', ', $sets) . ' WHERE id = :id',
            $params
        );

        self::me($request);
    }

    private static function storeRefreshToken(int $userId, string $sessionId, string $token): void
    {
        Database::execute(
            'INSERT INTO refresh_tokens (user_id, session_id, token_hash, expires_at)
             VALUES (:uid, :sid, :hash, DATE_ADD(NOW(), INTERVAL :ttl SECOND))',
            [
                'uid' => $userId,
                'sid' => $sessionId,
                'hash' => hash('sha256', $token),
                'ttl' => Env::int('JWT_REFRESH_EXPIRY', 604800),
            ]
        );
    }

    private static function revokeSession(int $userId, string $sessionId): void
    {
        Database::execute(
            'UPDATE refresh_tokens SET revoked_at = NOW()
             WHERE user_id = :uid AND session_id = :sid AND revoked_at IS NULL',
            ['uid' => $userId, 'sid' => $sessionId]
        );
        Database::execute(
            'DELETE FROM device_tokens WHERE user_id = :uid AND session_id = :sid',
            ['uid' => $userId, 'sid' => $sessionId]
        );
    }
}
