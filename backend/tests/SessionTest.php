<?php
declare(strict_types=1);
namespace Circle\Tests;
use Circle\Core\Database;
final class SessionTest extends ApiTestCase
{
    public function testDeviceMetadataAndOwnerOnlyListNeverExposeCredentials(): void
    {
        $a = $this->user(); $b = $this->user('Other');
        $login = $this->request('POST', '/api/v1/auth/login', ['mobile' => $a['mobile'], 'password' => self::PASSWORD], headers: ['X-Circle-Device' => 'Fictional phone', 'X-Circle-OS' => 'Android 16', 'X-Circle-App' => '1.0.12 (13)', 'X-Forwarded-For' => '198.51.100.19'], ip: '192.0.2.8')->data();
        $list = $this->request('GET', '/api/v1/me/sessions', [], $login['access_token']);
        self::assertSame(200, $list->status()); self::assertCount(2, $list->data());
        $current = array_values(array_filter($list->data(), static fn (array $x): bool => $x['is_current']))[0];
        self::assertSame('Fictional phone', $current['device_label']); self::assertSame('192.0.2.8', $current['ip_address']);
        self::assertSame('Android 16', $current['os_version']); self::assertNull($current['location_label']);
        foreach ($list->data() as $row) { self::assertArrayNotHasKey('session_id', $row); self::assertArrayNotHasKey('token_hash', $row); self::assertArrayNotHasKey('user_agent', $row); }
        self::assertCount(1, $this->request('GET', '/api/v1/me/sessions', [], $b['token'])->data());
        self::assertSame(401, $this->request('GET', '/api/v1/me/sessions')->status());
    }
    public function testRevokeOtherSessionStopsItsAccessRefreshAndPushOnly(): void
    {
        $a = $this->user(); $b = $this->user('Other');
        $second = $this->request('POST', '/api/v1/auth/login', ['mobile' => $a['mobile'], 'password' => self::PASSWORD])->data();
        $this->request('POST', '/api/v1/devices/register', ['fcm_token' => 'fictional-device', 'platform' => 'android'], $second['access_token']);
        $rows = $this->request('GET', '/api/v1/me/sessions', [], $a['token'])->data();
        $target = array_values(array_filter($rows, static fn (array $x): bool => !$x['is_current']))[0]['id'];
        self::assertSame(404, $this->request('DELETE', '/api/v1/me/sessions/' . $target, [], $b['token'])->status());
        $result = $this->request('DELETE', '/api/v1/me/sessions/' . $target, [], $a['token']);
        self::assertSame(['current_session_revoked' => false], $result->data());
        self::assertSame(401, $this->request('GET', '/api/v1/me', [], $second['access_token'])->status());
        self::assertSame(401, $this->request('POST', '/api/v1/auth/refresh', ['refresh_token' => $second['refresh_token']])->status());
        self::assertSame(200, $this->request('GET', '/api/v1/me', [], $a['token'])->status());
        self::assertSame(200, $this->request('GET', '/api/v1/me', [], $b['token'])->status());
        self::assertSame(0, (int) Database::queryOne('SELECT COUNT(*) AS n FROM device_tokens')['n']);
        self::assertSame(200, $this->request('DELETE', '/api/v1/me/sessions/' . $target, [], $a['token'])->status());
        self::assertCount(1, $this->request('GET', '/api/v1/me/sessions', [], $a['token'])->data());
    }
    public function testCurrentRevocationAndRefreshDoNotDuplicateOrRestoreSession(): void
    {
        $a = $this->user();
        $first = $this->request('GET', '/api/v1/me/sessions', [], $a['token'])->data()[0];
        $refresh = $this->request('POST', '/api/v1/auth/refresh', ['refresh_token' => $a['refresh']])->data();
        $after = $this->request('GET', '/api/v1/me/sessions', [], $refresh['access_token'])->data();
        self::assertCount(1, $after); self::assertSame($first['id'], $after[0]['id']);
        self::assertSame(['current_session_revoked' => true], $this->request('DELETE', '/api/v1/me/sessions/' . $first['id'], [], $refresh['access_token'])->data());
        self::assertSame(401, $this->request('GET', '/api/v1/me/sessions', [], $a['token'])->status());
        self::assertSame(401, $this->request('POST', '/api/v1/auth/refresh', ['refresh_token' => $refresh['refresh_token']])->status());
    }
    public function testLocationIsOptionalCurrentSessionOnlyAndRemovable(): void
    {
        $a = $this->user();
        $second = $this->request('POST', '/api/v1/auth/login', ['mobile' => $a['mobile'], 'password' => self::PASSWORD])->data();
        self::assertSame(200, $this->request('PATCH', '/api/v1/me/session', ['location_label' => 'Fictional City, Test Region', 'device_label' => 'Fictional tablet'], $a['token'])->status());
        $rows = $this->request('GET', '/api/v1/me/sessions', [], $a['token'])->data();
        foreach ($rows as $r) { self::assertSame($r['is_current'] ? 'Fictional City, Test Region' : null, $r['location_label']); }
        self::assertSame(200, $this->request('PATCH', '/api/v1/me/session', ['location_label' => null], $a['token'])->status());
        foreach ($this->request('GET', '/api/v1/me/sessions', [], $second['access_token'])->data() as $r) { self::assertNull($r['location_label']); self::assertNull($r['location_updated_at']); }
        foreach ([['latitude' => 12], ['location_label' => []], ['device_label' => ''], ['os_version' => "bad\nvalue"], ['location_label' => str_repeat('x', 161)], []] as $body) self::assertSame(422, $this->request('PATCH', '/api/v1/me/session', $body, $a['token'])->status());
    }
    public function testActivityTouchAndPasswordChangeRemoveActiveSessions(): void
    {
        $a = $this->user();
        Database::execute('UPDATE login_sessions SET last_seen_at = DATE_SUB(NOW(), INTERVAL 5 MINUTE)');
        $row = $this->request('GET', '/api/v1/me/sessions?limit=1&offset=0', [], $a['token'], ip: '192.0.2.30')->data()[0];
        self::assertSame('192.0.2.30', $row['ip_address']);
        self::assertSame(200, $this->request('POST', '/api/v1/auth/change-password', ['current_password' => self::PASSWORD, 'new_password' => 'a different secure password'], $a['token'])->status());
        $new = $this->request('POST', '/api/v1/auth/login', ['mobile' => $a['mobile'], 'password' => 'a different secure password'])->data();
        self::assertCount(1, $this->request('GET', '/api/v1/me/sessions', [], $new['access_token'])->data());
    }
    public function testMigrationBackfillsExistingOpenSessionsWithoutChangingCredentials(): void
    {
        $a = $this->user(); $b = $this->user('Other');
        $this->request('POST', '/api/v1/auth/logout', [], $b['token']);
        Database::execute('DELETE FROM login_sessions');
        $before = Database::query('SELECT id, token_hash, session_id, revoked_at, expires_at FROM refresh_tokens ORDER BY id');
        $migration = file_get_contents(__DIR__ . '/../database/migrations/013_login_session_details.sql');
        self::assertIsString($migration);
        $insert = strpos($migration, 'INSERT INTO login_sessions');
        self::assertNotFalse($insert);
        Database::connection()->exec(substr($migration, $insert));
        self::assertSame($before, Database::query('SELECT id, token_hash, session_id, revoked_at, expires_at FROM refresh_tokens ORDER BY id'));
        $rows = $this->request('GET', '/api/v1/me/sessions', [], $a['token'])->data();
        self::assertCount(1, $rows); self::assertSame('Unknown device', $rows[0]['device_label']);
        self::assertTrue($rows[0]['is_current']); self::assertCount(1, Database::query('SELECT public_id FROM login_sessions'));
        self::assertSame(200, $this->request('GET', '/api/v1/me', [], $a['token'])->status());
    }

}
