<?php
declare(strict_types=1);
namespace Circle\Tests;
use Circle\Core\Database;
use Circle\Core\Env;
final class PasswordChangeTest extends ApiTestCase
{
    private const NEXT_PASSWORD = '  a new secure password  ';
    public function testChangeRevokesEverySessionAndDeviceOnlyForItsAccount(): void
    {
        $user = $this->user(); $other = $this->user('Other');
        $second = $this->request('POST', '/api/v1/auth/login', ['mobile' => $user['mobile'], 'password' => self::PASSWORD])->data();
        foreach ([$user['token'], $second['access_token'], $other['token']] as $i => $token) {
            self::assertSame(200, $this->request('POST', '/api/v1/devices/register', ['fcm_token' => 'fictional-device-token-' . $i, 'platform' => 'android'], $token)->status());
        }
        $changed = $this->request('POST', '/api/v1/auth/change-password', ['current_password' => self::PASSWORD, 'new_password' => self::NEXT_PASSWORD], $user['token']);
        self::assertSame(200, $changed->status()); self::assertSame(['sign_in_required' => true], $changed->data());
        foreach ([$user['token'], $second['access_token']] as $token) self::assertSame(401, $this->request('GET', '/api/v1/me', [], $token)->status());
        foreach ([$user['refresh'], $second['refresh_token']] as $refresh) self::assertSame(401, $this->request('POST', '/api/v1/auth/refresh', ['refresh_token' => $refresh])->status());
        self::assertSame(200, $this->request('GET', '/api/v1/me', [], $other['token'])->status());
        self::assertSame(0, (int) Database::queryOne('SELECT COUNT(*) AS n FROM device_tokens WHERE user_id = :id', ['id' => $user['id']])['n']);
        self::assertSame(1, (int) Database::queryOne('SELECT COUNT(*) AS n FROM device_tokens WHERE user_id = :id', ['id' => $other['id']])['n']);
        foreach ([self::PASSWORD, trim(self::NEXT_PASSWORD)] as $password) self::assertSame(401, $this->request('POST', '/api/v1/auth/login', ['mobile' => $user['mobile'], 'password' => $password])->status());
        self::assertSame(200, $this->request('POST', '/api/v1/auth/login', ['mobile' => $user['mobile'], 'password' => self::NEXT_PASSWORD])->status());
    }
    public function testWrongCurrentCommitsRateBudgetWithoutRevokingSession(): void
    {
        $user = $this->user(); Env::set('LOGIN_MAX_FAILURES_PER_MOBILE', '2');
        try {
            for ($i = 0; $i < 2; $i++) {
                $r = $this->request('POST', '/api/v1/auth/change-password', ['current_password' => 'wrong current secret', 'new_password' => self::NEXT_PASSWORD], $user['token'], ip: '127.0.0.' . ($i + 1));
                self::assertSame(422, $r->status()); self::assertSame('invalid_current_password', $r->errorCode());
            }
            $r = $this->request('POST', '/api/v1/auth/change-password', ['current_password' => self::PASSWORD, 'new_password' => self::NEXT_PASSWORD], $user['token']);
            self::assertSame(429, $r->status()); self::assertSame('900', $r->header('Retry-After'));
            self::assertSame(200, $this->request('GET', '/api/v1/me', [], $user['token'])->status());
        } finally { Env::set('LOGIN_MAX_FAILURES_PER_MOBILE', '10'); }
    }
    public function testInvalidInputsAndMissingAuthDoNotChangePassword(): void
    {
        $user = $this->user();
        self::assertSame(401, $this->request('POST', '/api/v1/auth/change-password')->status());
        self::assertSame(422, $this->request('POST', '/api/v1/auth/change-password', ['current_password' => self::PASSWORD, 'new_password' => self::NEXT_PASSWORD, 'user_id' => 99], $user['token'])->status());
        foreach ([null, [], 7, '', 'short', str_repeat('a', 14), str_repeat('a', 129), self::PASSWORD] as $next) self::assertSame(422, $this->request('POST', '/api/v1/auth/change-password', ['current_password' => self::PASSWORD, 'new_password' => $next], $user['token'])->status());
        foreach ([null, [], '', str_repeat('a', 1025)] as $current) self::assertSame(422, $this->request('POST', '/api/v1/auth/change-password', ['current_password' => $current, 'new_password' => self::NEXT_PASSWORD], $user['token'])->status());
        self::assertSame(200, $this->request('POST', '/api/v1/auth/login', ['mobile' => $user['mobile'], 'password' => self::PASSWORD])->status());
    }
    public function testUnicodePasswordAndInactiveOrClosedSessions(): void
    {
        $user = $this->user(); $next = str_repeat('界', 15);
        self::assertSame(200, $this->request('POST', '/api/v1/auth/change-password', ['current_password' => self::PASSWORD, 'new_password' => $next], $user['token'])->status());
        $login = $this->request('POST', '/api/v1/auth/login', ['mobile' => $user['mobile'], 'password' => $next]); self::assertSame(200, $login->status());
        $token = $login->data()['access_token'];
        Database::execute("UPDATE users SET status = 'suspended' WHERE id = :id", ['id' => $user['id']]);
        self::assertSame(403, $this->request('POST', '/api/v1/auth/change-password', ['current_password' => $next, 'new_password' => self::NEXT_PASSWORD], $token)->status());
        Database::execute("UPDATE users SET status = 'active' WHERE id = :id", ['id' => $user['id']]);
        self::assertSame(200, $this->request('POST', '/api/v1/auth/logout', [], $token)->status());
        self::assertSame(401, $this->request('POST', '/api/v1/auth/change-password', ['current_password' => $next, 'new_password' => self::NEXT_PASSWORD], $token)->status());
    }
}
