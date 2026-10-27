<?php

declare(strict_types=1);
namespace Circle\Controllers;
use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;

final class SessionController
{
    public static function index(Request $request): void
    {
        $rows = Database::query('SELECT s.* FROM login_sessions s WHERE s.user_id = :uid AND EXISTS (SELECT 1 FROM refresh_tokens rt WHERE rt.user_id = s.user_id AND rt.session_id = s.session_id AND rt.revoked_at IS NULL AND rt.expires_at > NOW()) ORDER BY s.last_seen_at DESC, s.public_id LIMIT :lim OFFSET :off',
            ['uid' => $request->userId(), 'lim' => $request->queryInt('limit', 30, 1, 100), 'off' => $request->queryInt('offset', 0, 0, 1000000)]);
        $total = Database::queryOne('SELECT COUNT(*) AS n FROM login_sessions s WHERE s.user_id = :uid AND EXISTS (SELECT 1 FROM refresh_tokens rt WHERE rt.user_id = s.user_id AND rt.session_id = s.session_id AND rt.revoked_at IS NULL AND rt.expires_at > NOW())', ['uid' => $request->userId()]);
        $data = array_map(static fn (array $row): array => [
            'id' => $row['public_id'], 'is_current' => $row['session_id'] === $request->attr('session_id'),
            'device_label' => $row['device_label'], 'os_version' => $row['os_version'], 'app_version' => $row['app_version'],
            'ip_address' => $row['last_ip'], 'location_label' => $row['location_label'], 'location_updated_at' => $row['location_updated_at'],
            'created_at' => $row['created_at'], 'last_seen_at' => $row['last_seen_at'],
        ], $rows);
        Response::paginated($data, ['total' => (int) ($total['n'] ?? 0), 'limit' => $request->queryInt('limit', 30, 1, 100), 'offset' => $request->queryInt('offset', 0, 0, 1000000)]);
    }
    public static function revoke(Request $request): void
    {
        $current = Database::transaction(static function () use ($request): bool {
            self::lockCurrent($request);
            $target = Database::queryOne('SELECT session_id FROM login_sessions WHERE user_id = :uid AND public_id = :id FOR UPDATE', ['uid' => $request->userId(), 'id' => $request->param('sessionId')]);
            if ($target === null) Response::notFound('Session not found.');
            Database::execute('UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = :uid AND session_id = :sid AND revoked_at IS NULL', ['uid' => $request->userId(), 'sid' => $target['session_id']]);
            Database::execute('DELETE FROM device_tokens WHERE user_id = :uid AND session_id = :sid', ['uid' => $request->userId(), 'sid' => $target['session_id']]);
            return $target['session_id'] === $request->attr('session_id');
        });
        Response::ok(['current_session_revoked' => $current], 'Session logged out.');
    }
    public static function update(Request $request): void
    {
        $allowed = ['device_label' => 120, 'os_version' => 80, 'app_version' => 40, 'location_label' => 160];
        if (!$request->jsonIsObject() || $request->all() === [] || array_diff(array_keys($request->all()), array_keys($allowed)) !== []) Response::validationError('Send only device details or an approximate location label.');
        $sets = []; $params = ['uid' => $request->userId(), 'sid' => $request->attr('session_id')];
        foreach ($allowed as $key => $max) {
            if (!$request->has($key)) continue;
            $value = $request->input($key);
            if ($key === 'location_label' && $value === null) {
                $sets[] = 'location_label = NULL'; $sets[] = 'location_updated_at = NULL'; continue;
            }
            if (!is_string($value) || strlen($value) > $max || preg_match('//u', $value) !== 1 || preg_match('/[\x00-\x1f\x7f]/', $value) === 1 || ($key === 'device_label' && trim($value) === '')) Response::validationError('Device details are invalid.');
            $sets[] = $key . ' = :' . $key; $params[$key] = trim($value);
            if ($key === 'location_label') $sets[] = 'location_updated_at = NOW()';
        }
        Database::transaction(static function () use ($request, $sets, $params): void {
            self::lockCurrent($request);
            Database::execute('UPDATE login_sessions SET ' . implode(', ', $sets) . ' WHERE user_id = :uid AND session_id = :sid', $params);
        });
        Response::ok(null, 'Session details updated.');
    }
    private static function lockCurrent(Request $request): void
    {
        $user = Database::queryOne('SELECT status FROM users WHERE id = :uid FOR UPDATE', ['uid' => $request->userId()]);
        if ($user === null || $user['status'] !== 'active') Response::forbidden('This account is not active.', 'account_inactive');
        $open = Database::queryOne('SELECT id FROM refresh_tokens WHERE user_id = :uid AND session_id = :sid AND revoked_at IS NULL AND expires_at > NOW() FOR UPDATE', ['uid' => $request->userId(), 'sid' => $request->attr('session_id')]);
        if ($open === null) Response::unauthorized('This session ended.', 'invalid_token');
    }
}
