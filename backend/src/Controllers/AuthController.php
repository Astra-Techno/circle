<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\JWT;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Core\Validator;

final class AuthController
{
    public static function register(Request $request): void
    {
        $mobile = $request->string('mobile');
        $password = $request->string('password');
        $displayName = $request->string('display_name');

        $v = new Validator();
        $v->required('mobile', $mobile)->mobile($mobile);
        $v->required('password', $password)->password($password);
        $v->string('display_name', $displayName, 0, 100, 'Display name');
        $v->bail();

        // Check uniqueness
        $existing = Database::queryOne(
            'SELECT id FROM users WHERE mobile = :mobile',
            ['mobile' => $mobile]
        );
        if ($existing !== null) {
            Response::error('mobile_taken', 'This mobile number is already registered.', 409);
        }

        $passwordHash = password_hash($password, PASSWORD_ARGON2ID);

        Database::execute(
            'INSERT INTO users (mobile, password_hash, display_name) VALUES (:mobile, :hash, :name)',
            ['mobile' => $mobile, 'hash' => $passwordHash, 'name' => $displayName]
        );

        $userId = (int) Database::lastInsertId();
        $tokens = JWT::issueTokens($userId);

        // Store refresh token hash
        self::storeRefreshToken($userId, $tokens['refresh_token']);

        Response::created([
            'user' => [
                'id' => $userId,
                'mobile' => $mobile,
                'display_name' => $displayName,
            ],
            ...$tokens,
        ], 'Account created successfully.');
    }

    public static function login(Request $request): void
    {
        $mobile = $request->string('mobile');
        $password = $request->string('password');

        $v = new Validator();
        $v->required('mobile', $mobile);
        $v->required('password', $password);
        $v->bail();

        $user = Database::queryOne(
            'SELECT id, mobile, display_name, password_hash, status FROM users WHERE mobile = :mobile',
            ['mobile' => $mobile]
        );

        // Generic failure message to avoid user enumeration
        if ($user === null || !password_verify($password, $user['password_hash'])) {
            Response::error('invalid_credentials', 'Invalid mobile number or password.', 401);
        }

        if ($user['status'] !== 'active') {
            Response::error('account_suspended', 'This account is not active.', 403);
        }

        $tokens = JWT::issueTokens((int) $user['id']);
        self::storeRefreshToken((int) $user['id'], $tokens['refresh_token']);

        Response::ok([
            'user' => [
                'id' => (int) $user['id'],
                'mobile' => $user['mobile'],
                'display_name' => $user['display_name'],
            ],
            ...$tokens,
        ], 'Login successful.');
    }

    public static function refresh(Request $request): void
    {
        $refreshToken = $request->string('refresh_token');
        if ($refreshToken === '') {
            Response::validationError('Refresh token is required.');
        }

        $userId = JWT::validateRefresh($refreshToken);
        if ($userId === null) {
            Response::unauthorized('Invalid or expired refresh token.');
        }

        // Verify token exists in DB and not revoked
        $tokenHash = hash('sha256', $refreshToken);
        $stored = Database::queryOne(
            'SELECT id FROM refresh_tokens WHERE user_id = :uid AND token_hash = :hash AND revoked_at IS NULL AND expires_at > NOW()',
            ['uid' => $userId, 'hash' => $tokenHash]
        );

        if ($stored === null) {
            Response::unauthorized('Refresh token has been revoked.');
        }

        // Revoke old token
        Database::execute(
            'UPDATE refresh_tokens SET revoked_at = NOW() WHERE id = :id',
            ['id' => $stored['id']]
        );

        // Issue new pair
        $tokens = JWT::issueTokens($userId);
        self::storeRefreshToken($userId, $tokens['refresh_token']);

        Response::ok($tokens, 'Tokens refreshed.');
    }

    public static function logout(Request $request): void
    {
        $userId = $request->attr('user_id');
        $refreshToken = $request->string('refresh_token');

        if ($refreshToken !== '') {
            $tokenHash = hash('sha256', $refreshToken);
            Database::execute(
                'UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = :uid AND token_hash = :hash',
                ['uid' => $userId, 'hash' => $tokenHash]
            );
        }

        Response::ok(null, 'Logged out.');
    }

    public static function me(Request $request): void
    {
        $userId = $request->attr('user_id');

        $user = Database::queryOne(
            'SELECT id, mobile, display_name, about, avatar_path, created_at FROM users WHERE id = :id AND status = :s',
            ['id' => $userId, 's' => 'active']
        );

        if ($user === null) {
            Response::notFound('User not found.');
        }

        $user['id'] = (int) $user['id'];

        Response::ok($user);
    }

    public static function updateMe(Request $request): void
    {
        $userId = $request->attr('user_id');
        $displayName = $request->string('display_name');
        $about = $request->string('about');

        $sets = [];
        $params = ['id' => $userId];

        if ($displayName !== '') {
            (new Validator())->string('display_name', $displayName, 1, 100, 'Display name')->bail();
            $sets[] = 'display_name = :name';
            $params['name'] = $displayName;
        }

        if ($about !== '') {
            (new Validator())->string('about', $about, 0, 500, 'About')->bail();
            $sets[] = 'about = :about';
            $params['about'] = $about;
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

    private static function storeRefreshToken(int $userId, string $token): void
    {
        $tokenHash = hash('sha256', $token);
        $expiresAt = date('Y-m-d H:i:s', time() + (int) \Circle\Core\Env::get('JWT_REFRESH_EXPIRY', '604800'));

        Database::execute(
            'INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES (:uid, :hash, :exp)',
            ['uid' => $userId, 'hash' => $tokenHash, 'exp' => $expiresAt]
        );
    }
}
