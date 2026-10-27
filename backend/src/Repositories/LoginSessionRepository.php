<?php

declare(strict_types=1);
namespace Circle\Repositories;
use Circle\Core\Database;
use Circle\Core\Request;

final class LoginSessionRepository
{
    public static function start(int $user, string $sid, Request $request): void
    {
        $device = self::header($request, 'x-circle-device', 120);
        if ($device === '') {
            $ua = strtolower($request->header('user-agent'));
            $device = str_contains($ua, 'android') ? 'Android device' : (str_contains($ua, 'iphone') ? 'iPhone' : (str_contains($ua, 'mozilla') ? 'Web browser' : 'Unknown device'));
        }
        Database::execute('INSERT INTO login_sessions (public_id, user_id, session_id, device_label, os_version, app_version, last_ip) VALUES (:id, :uid, :sid, :device, :os, :app, :ip)',
            ['id' => bin2hex(random_bytes(16)), 'uid' => $user, 'sid' => $sid, 'device' => $device,
             'os' => self::header($request, 'x-circle-os', 80), 'app' => self::header($request, 'x-circle-app', 40), 'ip' => self::ip($request)]);
    }
    public static function touch(int $user, string $sid, Request $request): void
    {
        Database::execute('UPDATE login_sessions SET last_seen_at = NOW(), last_ip = :ip WHERE user_id = :uid AND session_id = :sid AND last_seen_at < DATE_SUB(NOW(), INTERVAL 60 SECOND)',
            ['ip' => self::ip($request), 'uid' => $user, 'sid' => $sid]);
    }
    private static function ip(Request $request): string
    {
        return filter_var($request->ip(), FILTER_VALIDATE_IP) !== false ? $request->ip() : '';
    }
    private static function header(Request $request, string $name, int $max): string
    {
        $value = trim($request->header($name));
        if (strlen($value) > $max || preg_match('//u', $value) !== 1 || preg_match('/[\x00-\x1f\x7f]/', $value) === 1) return '';
        return $value;
    }
}
