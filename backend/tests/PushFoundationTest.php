<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Controllers\DeviceController;
use Circle\Core\Database;
use Circle\Core\JWT;
use Circle\Core\NotificationPreferences;
use Circle\Core\Request;
use Circle\Core\ResponseSent;

final class PushFoundationTest extends ApiTestCase
{
    public function testRegistrationValidationAndAuthentication(): void
    {
        self::assertSame(401, $this->request('POST', '/api/v1/devices/register')->status());
        $user = $this->user();
        foreach ([null, 12, [], '', ' token', "x\ny", str_repeat('x', 513), 'தமிழ்'] as $token) {
            self::assertSame(422, $this->request('POST', '/api/v1/devices/register', ['fcm_token' => $token, 'platform' => 'android'], $user['token'])->status());
        }
        foreach ([null, [], 'windows', 'Android', ''] as $platform) {
            self::assertSame(422, $this->request('POST', '/api/v1/devices/register', ['fcm_token' => 'fictional-token', 'platform' => $platform], $user['token'])->status());
        }
        self::assertSame(200, $this->register($user['token'], str_repeat('A', 512))->status());
        self::assertSame(200, $this->register($user['token'], str_repeat('a', 512))->status());
        self::assertCount(2, Database::query('SELECT id FROM device_tokens'));
        self::assertSame(422, $this->request('POST', '/api/v1/devices/unregister', ['fcm_token' => []], $user['token'])->status());
    }

    public function testReassignmentAndSessionScopedCleanup(): void
    {
        $first = $this->user('Fictional One');
        $second = $this->user('Fictional Two');
        $this->register($first['token'], 'fictional-device');
        $this->register($first['token'], 'fictional-device');
        self::assertCount(1, Database::query('SELECT id FROM device_tokens'));
        $this->register($second['token'], 'fictional-device');
        $this->request('POST', '/api/v1/devices/unregister', ['fcm_token' => 'fictional-device'], $first['token']);
        $this->request('POST', '/api/v1/auth/logout', [], $first['token']);
        self::assertSame($second['id'], Database::queryOne('SELECT user_id FROM device_tokens')['user_id']);
        $this->request('POST', '/api/v1/auth/logout', [], $second['token']);
        self::assertCount(0, Database::query('SELECT id FROM device_tokens'));
    }

    public function testOtherLoginOfSameAccountCannotRemoveCurrentRegistration(): void
    {
        $user = $this->user();
        $login = $this->request('POST', '/api/v1/auth/login', ['mobile' => $user['mobile'], 'password' => self::PASSWORD])->data();
        $this->register($user['token'], 'same-account-device');
        $this->register($login['access_token'], 'same-account-device');
        $this->request('POST', '/api/v1/devices/unregister', ['fcm_token' => 'same-account-device'], $user['token']);
        $this->request('POST', '/api/v1/auth/logout', [], $user['token']);
        self::assertCount(1, Database::query('SELECT id FROM device_tokens'));
        $refresh = $this->request('POST', '/api/v1/auth/refresh', ['refresh_token' => $login['refresh_token']]);
        self::assertSame(200, $refresh->status());
        self::assertSame(200, $this->request('POST', '/api/v1/devices/unregister', ['fcm_token' => 'same-account-device'], $refresh->data()['access_token'])->status());
        self::assertCount(0, Database::query('SELECT id FROM device_tokens'));
    }

    public function testRegistrationThatPassedMiddlewareCannotReviveRevokedSession(): void
    {
        $user = $this->user();
        $claims = JWT::validateAccess($user['token']);
        self::assertNotNull($claims);
        $this->request('POST', '/api/v1/auth/logout', [], $user['token']);
        $stale = (new Request('POST', '/api/v1/devices/register', ['fcm_token' => 'fictional-late-token', 'platform' => 'ios']))
            ->withAttr('user_id', $user['id'])->withAttr('session_id', $claims['session_id']);
        try {
            DeviceController::register($stale);
            self::fail('A revoked session must not register.');
        } catch (ResponseSent $response) {
            self::assertSame(401, (new TestResponse($response))->status());
        }
        self::assertCount(0, Database::query('SELECT id FROM device_tokens'));
    }

    public function testPreferencesAreOptInPrivateAndPartialUpdatesPreserveOtherValues(): void
    {
        $user = $this->user();
        $other = $this->user();
        $path = '/api/v1/me/notification-preferences';
        self::assertSame(401, $this->request('GET', $path)->status());
        self::assertSame(401, $this->request('PATCH', $path, ['enabled' => true])->status());
        $defaults = $this->request('GET', $path, [], $user['token']);
        self::assertFalse($defaults->data()['enabled']);
        self::assertSame('private, no-store', $defaults->header('Cache-Control'));
        self::assertFalse($defaults->data()['categories']['chats']);
        $saved = $this->request('PATCH', $path, ['enabled' => true, 'categories' => ['chats' => true], 'timezone' => 'Asia/Kolkata'], $user['token']);
        self::assertSame(200, $saved->status());
        $saved = $this->request('PATCH', $path, ['categories' => ['events' => true]], $user['token']);
        self::assertTrue($saved->data()['categories']['chats']);
        self::assertTrue($saved->data()['categories']['events']);
        self::assertSame('Asia/Kolkata', $saved->data()['timezone']);
        self::assertFalse($this->request('GET', $path, [], $other['token'])->data()['enabled']);
        $saved = $this->request('PATCH', $path, ['categories' => ['chats' => false]], $user['token']);
        self::assertFalse($saved->data()['categories']['chats']);
        self::assertTrue($saved->data()['categories']['events']);
    }

    public function testInvalidPreferencesNeverOverwriteSavedValues(): void
    {
        $user = $this->user();
        $path = '/api/v1/me/notification-preferences';
        $this->request('PATCH', $path, ['enabled' => true], $user['token']);
        foreach ([['enabled' => 'true'], ['quiet_hours' => null], ['quiet_start' => '600'], ['quiet_end' => 1440],
            ['quiet_start' => -1], ['quiet_start' => 420], ['timezone' => '+05:30'], ['timezone' => []],
            ['categories' => ['chats' => 1]], ['categories' => ['unknown' => true]], ['categories' => null],
            ['user_id' => 9], ['quiet_end' => 2.5]] as $body) {
            self::assertSame(422, $this->request('PATCH', $path, $body, $user['token'])->status(), json_encode($body) ?: '');
            self::assertTrue($this->request('GET', $path, [], $user['token'])->data()['enabled']);
        }
    }

    public function testDeliveryPolicyUsesTimezoneBoundariesMembershipAndActiveAccount(): void
    {
        $user = $this->user();
        $group = $this->createGroup($user);
        $at = static fn (string $time): \DateTimeImmutable => new \DateTimeImmutable($time, new \DateTimeZone('UTC'));
        self::assertFalse(NotificationPreferences::allows($user['id'], 'memories', $group, $at('2026-10-26 10:00')));
        $this->request('PATCH', '/api/v1/me/notification-preferences', [
            'enabled' => true, 'categories' => ['memories' => true], 'timezone' => 'Asia/Kolkata',
        ], $user['token']);
        foreach (['2026-10-26 16:29' => true, '2026-10-26 16:30' => false, '2026-10-27 01:29' => false, '2026-10-27 01:30' => true] as $time => $allowed) {
            self::assertSame($allowed, NotificationPreferences::allows($user['id'], 'memories', $group, $at($time)), $time);
        }
        self::assertFalse(NotificationPreferences::allows($user['id'], 'unknown', $group, $at('2026-10-26 10:00')));
        self::assertFalse(NotificationPreferences::allows($user['id'], 'chats', $group, $at('2026-10-26 10:00')));
        self::assertFalse(NotificationPreferences::allows($user['id'], 'memories', null, $at('2026-10-26 10:00')));
        $this->request('PATCH', '/api/v1/me/notification-preferences', ['quiet_start' => 600, 'quiet_end' => 660], $user['token']);
        self::assertFalse(NotificationPreferences::allows($user['id'], 'memories', $group, $at('2026-10-26 04:30')));
        self::assertTrue(NotificationPreferences::allows($user['id'], 'memories', $group, $at('2026-10-26 05:30')));
        $this->request('PATCH', '/api/v1/me/notification-preferences',
            ['quiet_start' => 60, 'quiet_end' => 120, 'timezone' => 'America/New_York'], $user['token']);
        // Both repeated 01:30 instants during the autumn DST transition are quiet.
        self::assertFalse(NotificationPreferences::allows($user['id'], 'memories', $group, $at('2026-11-01 05:30')));
        self::assertFalse(NotificationPreferences::allows($user['id'], 'memories', $group, $at('2026-11-01 06:30')));
        self::assertTrue(NotificationPreferences::allows($user['id'], 'memories', $group, $at('2026-11-01 07:00')));
        Database::execute("UPDATE group_members SET status = 'left' WHERE user_id = :uid", ['uid' => $user['id']]);
        self::assertFalse(NotificationPreferences::allows($user['id'], 'memories', $group, $at('2026-10-26 10:00')));
        Database::execute("UPDATE group_members SET status = 'active' WHERE user_id = :uid", ['uid' => $user['id']]);
        Database::execute("UPDATE users SET status = 'suspended' WHERE id = :uid", ['uid' => $user['id']]);
        self::assertFalse(NotificationPreferences::allows($user['id'], 'memories', $group, $at('2026-10-26 10:00')));
    }

    public function testRawJsonObjectsAreRequiredWithoutCoercingListsOrMalformedBodies(): void
    {
        $user = $this->user();
        foreach (['null', '[]', 'true', '12', '"text"', '{', '', '{"categories":[]}', '{"categories":[true]}'] as $raw) {
            $decoded = json_decode($raw, true);
            $request = (new Request('PATCH', '/api/v1/me/notification-preferences',
                is_array($decoded) ? $decoded : [], [],
                ['Content-Type' => 'application/json', 'Authorization' => 'Bearer ' . $user['token']],
                rawBody: $raw));
            try {
                \Circle\App::handle($request);
                self::fail('Invalid JSON shape must fail.');
            } catch (ResponseSent $response) {
                self::assertSame(422, (new TestResponse($response))->status(), $raw);
            }
        }
        self::assertCount(0, Database::query('SELECT user_id FROM notification_preferences'));
        foreach (['{}', '{"categories":{}}'] as $raw) {
            $request = new Request('PATCH', '/api/v1/me/notification-preferences',
                json_decode($raw, true, flags: JSON_THROW_ON_ERROR), [],
                ['Content-Type' => 'application/json', 'Authorization' => 'Bearer ' . $user['token']], rawBody: $raw);
            try {
                \Circle\App::handle($request);
            } catch (ResponseSent $response) {
                self::assertSame(200, (new TestResponse($response))->status());
            }
        }
    }

    private function register(string $token, string $device): TestResponse
    {
        return $this->request('POST', '/api/v1/devices/register', ['fcm_token' => $device, 'platform' => 'android'], $token);
    }
}
