<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Core\NotificationPreferences;
use Circle\Core\FcmSender;
use Circle\Notifications\NotificationOutbox;
use Circle\Notifications\NotificationWorker;
use Circle\Notifications\PushResult;
use Circle\Notifications\PushTransport;

final class FakePushTransport implements PushTransport
{
    public bool $ready = true;
    /** @var list<array{token: string, data: array<string, string>}> */
    public array $calls = [];
    public PushResult $result;
    /** @var list<PushResult> */
    public array $results = [];
    public ?\Closure $duringSend = null;
    public function __construct() { $this->result = PushResult::sent(); }
    public function isReady(): bool { return $this->ready; }
    public function send(string $token, array $data): PushResult
    {
        $this->calls[] = ['token' => $token, 'data' => $data];
        if ($this->duringSend !== null) ($this->duringSend)();
        return array_shift($this->results) ?? $this->result;
    }
}

final class NotificationWorkerTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        Env::set('PUSH_QUEUE_ENABLED', 'true');
        Env::set('PUSH_DELIVERY_ENABLED', 'true');
        Env::set('PUSH_API_BASE_URL', 'https://fictional.example/api/v1');
    }
    protected function tearDown(): void
    {
        Env::set('PUSH_QUEUE_ENABLED', 'false');
        Env::set('PUSH_DELIVERY_ENABLED', 'false');
        Env::set('PUSH_API_BASE_URL', '');
        parent::tearDown();
    }

    public function testDirectContactBlockStopsPersonalAlertsButKeepsGroupUpdates(): void
    {
        $f=$this->fixture();
        $this->request('POST',"/api/v1/memories/{$f['memory']}/comments",['body'=>'Personal reply'],$f['member']['token']);
        self::assertSame(200,$this->request('PUT',"/api/v1/me/blocks/{$f['owner']['id']}",[],$f['member']['token'])->status());
        $transport=new FakePushTransport(); $worker=new NotificationWorker($transport);$counts=$worker->run();
        self::assertSame(1,$counts['cancelled']);self::assertSame(1,$counts['sent']);self::assertSame('memory.created',$transport->calls[0]['data']['type']);
        $before=(int)Database::queryOne('SELECT COUNT(*) n FROM notification_outbox')['n'];
        $this->request('POST',"/api/v1/memories/{$f['memory']}/comments",['body'=>'Another personal reply'],$f['member']['token']);
        self::assertSame($before,(int)Database::queryOne('SELECT COUNT(*) n FROM notification_outbox')['n']);
        $this->createMemory($f['owner'],$f['group'],'Group content stays visible');
        self::assertSame($before+1,(int)Database::queryOne('SELECT COUNT(*) n FROM notification_outbox')['n']);
    }

    public function testReportAlertsAreGenericDeduplicatedAndCancelAfterAdminDemotion(): void
    {
        $owner=$this->user('Owner'); $member=$this->user('Reporter'); $gid=$this->createGroup($owner); $this->join($owner,$member,$gid);
        foreach ([$owner,$member] as $user) {
            $this->request('PATCH','/api/v1/me/notification-preferences',['enabled'=>true,'quiet_hours'=>false,'categories'=>array_replace(array_fill_keys(NotificationPreferences::CATEGORIES,false),['groups'=>true])],$user['token']);
            $this->request('POST','/api/v1/devices/register',['fcm_token'=>'fictional-safety-'.$user['id'],'platform'=>'android'],$user['token']);
        }
        $mid=$this->createMemory($owner,$gid,'Private report text');
        foreach ([1,2] as $_) self::assertSame(200,$this->request('POST',"/api/v1/groups/$gid/reports",['kind'=>'memory','target_id'=>$mid,'reason'=>'spam','note'=>'Private note'],$member['token'])->status());
        self::assertSame(1,(int)Database::queryOne("SELECT COUNT(*) n FROM notification_outbox WHERE kind='group.report'")['n']);
        $transport=new FakePushTransport(); $worker=new NotificationWorker($transport);
        self::assertSame(1,$worker->run()['sent']); self::assertCount(1,$transport->calls);
        $data=$transport->calls[0]['data']; self::assertCount(7,$data); self::assertSame('group.report',$data['type']); self::assertSame((string)$gid,$data['group_id']);
        foreach (['note','reason','reporter_id','memory_id','comment_id','invitation_id','body'] as $field) self::assertArrayNotHasKey($field,$data);
        Database::execute("UPDATE notification_outbox SET state='pending',available_at=UTC_TIMESTAMP() WHERE kind='group.report'");
        Database::execute("UPDATE group_members SET role='member' WHERE group_id=:g AND user_id=:u",['g'=>$gid,'u'=>$owner['id']]);
        self::assertSame(1,$worker->run()['cancelled']); self::assertCount(1,$transport->calls);
    }

    /** @return array<string, mixed> */
    private function fixture(): array
    {
        $owner = $this->user('Fictional Owner'); $member = $this->user('Fictional Member');
        $group = $this->createGroup($owner); $this->join($owner, $member, $group);
        foreach ([$owner, $member] as $user) {
            self::assertSame(200, $this->request('PATCH', '/api/v1/me/notification-preferences',
                ['enabled' => true, 'quiet_hours' => false, 'categories' => ['memories' => true, 'replies_reactions' => true]], $user['token'])->status());
            self::assertSame(200, $this->request('POST', '/api/v1/devices/register',
                ['fcm_token' => 'fictional-device-' . $user['id'], 'platform' => 'android'], $user['token'])->status());
        }
        $memory = $this->createMemory($owner, $group, 'Fictional private text never included in push');
        return compact('owner', 'member', 'group', 'memory');
    }

    private function at(): \DateTimeImmutable { return new \DateTimeImmutable('now', new \DateTimeZone('UTC')); }

    /** @return array<string, mixed> */
    private function invitationFixture(): array
    {
        $owner = $this->user('Fictional inviter');
        $recipient = $this->user('Fictional recipient');
        $group = $this->createGroup($owner);
        self::assertSame(200, $this->request('PATCH', '/api/v1/me/notification-preferences',
            ['enabled' => true, 'quiet_hours' => false, 'categories' => ['groups' => true]], $recipient['token'])->status());
        self::assertSame(200, $this->request('POST', '/api/v1/devices/register',
            ['fcm_token' => 'fictional-invitation-device', 'platform' => 'android'], $recipient['token'])->status());
        Database::transaction(static function () use ($owner, $recipient, $group): void {
            Database::execute("INSERT INTO group_invitations (group_id, recipient_id, inviter_id, expires_at)
                VALUES (:gid, :uid, :actor, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 7 DAY))",
                ['gid' => $group, 'uid' => $recipient['id'], 'actor' => $owner['id']]);
            NotificationOutbox::groupInvitationCreated(Database::lastInsertId());
        });
        $invitation = (int) Database::queryOne('SELECT id FROM group_invitations')['id'];
        return compact('owner', 'recipient', 'group', 'invitation');
    }

    public function testInvitationCaptureIsTransactionalOptInAndDoesNotRequireMembership(): void
    {
        $f = $this->invitationFixture();
        self::assertCount(1, Database::query('SELECT id FROM notification_outbox'));
        self::assertFalse(\Circle\Core\NotificationPreferences::eligible($f['recipient']['id'], 'groups', $f['group']));
        Database::transaction(static function () use ($f): void { NotificationOutbox::groupInvitationCreated($f['invitation']); });
        self::assertCount(1, Database::query('SELECT id FROM notification_outbox'));
        $transport = new FakePushTransport();
        self::assertSame(1, (new NotificationWorker($transport))->run()['sent']);
        $data = $transport->calls[0]['data'];
        $keys = array_keys($data); sort($keys);
        $expected = ['event_id', 'type', 'api_base_url', 'recipient_id', 'session_scope', 'group_id', 'invitation_id', 'expires_at']; sort($expected);
        self::assertSame($expected, $keys);
        self::assertSame('group.invitation', $data['type']);
        self::assertSame((string) $f['invitation'], $data['invitation_id']);
        self::assertSame((string) $f['recipient']['id'], $data['recipient_id']);
        self::assertSame((string) $f['group'], $data['group_id']);
        self::assertLessThanOrEqual(time() + 86400, (int) $data['expires_at']);
        self::assertSame(0, (new NotificationWorker($transport))->run()['processed']);
    }

    public function testInvitationCaptureRespectsGroupOptInAndRollback(): void
    {
        $f = $this->invitationFixture();
        Database::execute('DELETE FROM notification_outbox');
        self::assertSame(200, $this->request('PATCH', '/api/v1/me/notification-preferences', ['categories' => ['groups' => false]], $f['recipient']['token'])->status());
        Database::transaction(static function () use ($f): void { NotificationOutbox::groupInvitationCreated($f['invitation']); });
        self::assertCount(0, Database::query('SELECT id FROM notification_outbox'));
        self::assertSame(200, $this->request('PATCH', '/api/v1/me/notification-preferences', ['categories' => ['groups' => true]], $f['recipient']['token'])->status());
        try {
            Database::transaction(static function () use ($f): void {
                NotificationOutbox::groupInvitationCreated($f['invitation']);
                throw new \RuntimeException('Fictional rollback');
            });
        } catch (\RuntimeException) {}
        self::assertCount(0, Database::query('SELECT id FROM notification_outbox'));
    }

    /** @return array<string, array{string}> */
    public static function invitationCancellationModes(): array
    {
        $modes = ['accepted', 'declined', 'expired', 'recipient', 'group', 'opt_out', 'sender_removed', 'joined', 'logout'];
        $cases = [];
        foreach ($modes as $mode) $cases[$mode] = [$mode];
        return $cases;
    }

    #[\PHPUnit\Framework\Attributes\DataProvider('invitationCancellationModes')]
    public function testInvitationWorkerCancelsChangedConsentExpiryIdentityAndSession(string $mode): void
    {
        $f = $this->invitationFixture();
        if (in_array($mode, ['accepted', 'declined'], true)) Database::execute('UPDATE group_invitations SET status = :status', ['status' => $mode]);
        if ($mode === 'expired') Database::execute('UPDATE group_invitations SET expires_at = DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 SECOND)');
        if ($mode === 'recipient') Database::execute('UPDATE notification_outbox SET user_id = :uid', ['uid' => $f['owner']['id']]);
        if ($mode === 'group') {
            $other = $this->createGroup($f['owner'], 'Fictional wrong group');
            Database::execute('UPDATE notification_outbox SET group_id = :gid', ['gid' => $other]);
        }
        if ($mode === 'opt_out') $this->request('PATCH', '/api/v1/me/notification-preferences', ['categories' => ['groups' => false]], $f['recipient']['token']);
        if ($mode === 'sender_removed') Database::execute("UPDATE group_members SET status = 'removed' WHERE user_id = :uid", ['uid' => $f['owner']['id']]);
        if ($mode === 'joined') $this->join($f['owner'], $f['recipient'], $f['group']);
        if ($mode === 'logout') $this->request('POST', '/api/v1/auth/logout', [], $f['recipient']['token']);
        $transport = new FakePushTransport(); $counts = (new NotificationWorker($transport))->run();
        self::assertSame(1, $counts['cancelled'], $mode); self::assertSame([], $transport->calls, $mode);
    }

    public function testInvitationWorkerDefersQuietHoursAndRetriesProvider(): void
    {
        $f = $this->invitationFixture();
        $minute = (int) gmdate('G') * 60 + (int) gmdate('i');
        $this->request('PATCH', '/api/v1/me/notification-preferences', ['quiet_hours' => true, 'quiet_start' => $minute, 'quiet_end' => ($minute + 60) % 1440, 'timezone' => 'UTC'], $f['recipient']['token']);
        $transport = new FakePushTransport(); $worker = new NotificationWorker($transport);
        self::assertSame(1, $worker->run()['deferred']); self::assertSame([], $transport->calls);
        $this->request('PATCH', '/api/v1/me/notification-preferences', ['quiet_hours' => false], $f['recipient']['token']);
        Database::execute('UPDATE notification_outbox SET available_at = UTC_TIMESTAMP()');
        $transport->result = PushResult::retry();
        self::assertSame(1, $worker->run()['retried']);
        Database::execute('UPDATE notification_outbox SET available_at = UTC_TIMESTAMP()');
        $transport->result = PushResult::sent();
        self::assertSame(1, $worker->run()['sent']);
    }

    public function testTransactionalCaptureExcludesActorAndDeduplicatesCommittedEvent(): void
    {
        $f = $this->fixture();
        self::assertCount(1, Database::query('SELECT * FROM notification_outbox'));
        Database::transaction(static function () use ($f): void { NotificationOutbox::memoryCreated($f['memory']); });
        $rows = Database::query('SELECT * FROM notification_outbox');
        self::assertCount(1, $rows); self::assertSame($f['member']['id'], $rows[0]['user_id']);
        self::assertStringNotContainsString('Fictional private text', json_encode($rows, JSON_THROW_ON_ERROR));
        Database::execute('DELETE FROM notification_outbox');
        try {
            Database::transaction(static function () use ($f): void {
                Database::execute('INSERT INTO memories (group_id, author_id, body) VALUES (:gid, :uid, :body)',
                    ['gid' => $f['group'], 'uid' => $f['owner']['id'], 'body' => 'Fictional rolled back']);
                NotificationOutbox::memoryCreated(Database::lastInsertId());
                throw new \RuntimeException('Intentional test rollback');
            });
        } catch (\RuntimeException) {}
        self::assertCount(1, Database::query('SELECT id FROM memories'));
        self::assertCount(0, Database::query('SELECT id FROM notification_outbox'));
    }

    public function testSuccessfulDeliveryHasScopedMinimalEnvelopeAndDoesNotRepeat(): void
    {
        $f = $this->fixture(); $transport = new FakePushTransport();
        $worker = new NotificationWorker($transport);
        self::assertSame(1, $worker->run()['sent']);
        self::assertSame(0, $worker->run()['processed']);
        self::assertCount(1, $transport->calls);
        $data = $transport->calls[0]['data'];
        self::assertSame((string) $f['memory'], $data['memory_id']);
        self::assertSame((string) $f['member']['id'], $data['recipient_id']);
        self::assertSame('https://fictional.example/api/v1', $data['api_base_url']);
        self::assertMatchesRegularExpression('/^[a-f0-9]{64}$/', $data['event_id']);
        self::assertMatchesRegularExpression('/^[a-f0-9]{64}$/', $data['session_scope']);
        self::assertGreaterThan(time(), (int) $data['expires_at']);
        self::assertArrayNotHasKey('body', $data); self::assertArrayNotHasKey('title', $data);
    }

    public function testCommentsAndRepliesNotifyOnlyOwnerAndParentAuthorWithoutSelfPush(): void
    {
        $f = $this->fixture(); Database::execute('DELETE FROM notification_outbox');
        $comment = $this->request('POST', '/api/v1/memories/' . $f['memory'] . '/comments', ['body' => 'Fictional comment'], $f['member']['token']);
        self::assertSame(201, $comment->status());
        $row = Database::queryOne('SELECT * FROM notification_outbox');
        self::assertSame($f['owner']['id'], $row['user_id']); self::assertSame('comment.created', $row['kind']);
        $reply = $this->request('POST', '/api/v1/memories/' . $f['memory'] . '/comments',
            ['body' => 'Fictional reply', 'parent_id' => $comment->data()['id']], $f['owner']['token']);
        self::assertSame(201, $reply->status());
        $rows = Database::query("SELECT * FROM notification_outbox WHERE kind = 'comment.reply'");
        self::assertCount(1, $rows); self::assertSame($f['member']['id'], $rows[0]['user_id']);
        self::assertSame(2, (new NotificationWorker(new FakePushTransport()))->run()['sent']);
    }

    public function testQuietHoursDeferWithoutAttemptAndDeliverAtFirstPermittedMinute(): void
    {
        $f = $this->fixture(); $at = $this->at(); $minute = (int) $at->format('G') * 60 + (int) $at->format('i');
        $this->request('PATCH', '/api/v1/me/notification-preferences',
            ['quiet_hours' => true, 'quiet_start' => $minute, 'quiet_end' => ($minute + 60) % 1440], $f['member']['token']);
        $transport = new FakePushTransport(); $worker = new NotificationWorker($transport, static function () use (&$at) { return $at; });
        self::assertSame(1, $worker->run()['deferred']); self::assertCount(0, $transport->calls);
        $row = Database::queryOne('SELECT * FROM notification_outbox'); self::assertSame(0, $row['attempts']);
        self::assertSame('quiet_hours', $row['last_error']);
        $at = new \DateTimeImmutable($row['available_at'], new \DateTimeZone('UTC'));
        self::assertSame(1, $worker->run()['sent']);
    }

    public function testTransientRetryHonorsDelayKeepsEventIdAndStopsAfterSuccess(): void
    {
        $this->fixture(); $at = $this->at(); $transport = new FakePushTransport(); $transport->result = PushResult::retry(120);
        $worker = new NotificationWorker($transport, static function () use (&$at) { return $at; });
        self::assertSame(1, $worker->run()['retried']);
        self::assertSame(0, $worker->run()['processed']);
        $row = Database::queryOne('SELECT * FROM notification_outbox'); self::assertSame(1, $row['attempts']);
        $retry = new \DateTimeImmutable($row['available_at'], new \DateTimeZone('UTC'));
        self::assertGreaterThanOrEqual(120, $retry->getTimestamp() - $at->getTimestamp());
        $at = $retry; $transport->result = PushResult::sent();
        self::assertSame(1, $worker->run()['sent']); self::assertCount(2, $transport->calls);
        self::assertSame($transport->calls[0]['data']['event_id'], $transport->calls[1]['data']['event_id']);
    }

    public function testRemovedMembershipDisabledPreferencesAndDeletedContentCancel(): void
    {
        foreach (['membership', 'preferences', 'content'] as $case) {
            parent::setUp(); $f = $this->fixture();
            if ($case === 'membership') $this->request('POST', '/api/v1/groups/' . $f['group'] . '/leave', [], $f['member']['token']);
            if ($case === 'preferences') $this->request('PATCH', '/api/v1/me/notification-preferences', ['enabled' => false], $f['member']['token']);
            if ($case === 'content') $this->request('DELETE', '/api/v1/memories/' . $f['memory'], [], $f['owner']['token']);
            $transport = new FakePushTransport(); self::assertSame(1, (new NotificationWorker($transport))->run()['cancelled'], $case);
            self::assertCount(0, $transport->calls);
        }
    }

    public function testLogoutAndDeviceReassignmentDoNotDeliverToTheWrongSession(): void
    {
        foreach (['logout', 'reassign'] as $case) {
            parent::setUp(); $f = $this->fixture();
            if ($case === 'logout') $this->request('POST', '/api/v1/auth/logout', [], $f['member']['token']);
            else $this->request('POST', '/api/v1/devices/register', ['fcm_token' => 'fictional-device-' . $f['member']['id'], 'platform' => 'android'], $f['owner']['token']);
            $transport = new FakePushTransport(); self::assertSame(1, (new NotificationWorker($transport))->run()['cancelled']);
            self::assertCount(0, $transport->calls);
        }
    }

    public function testInvalidTokenCleanupDoesNotDeleteConcurrentReassignment(): void
    {
        $f = $this->fixture(); $transport = new FakePushTransport(); $transport->result = PushResult::invalid();
        $transport->duringSend = function () use ($f): void {
            $this->request('POST', '/api/v1/devices/register', ['fcm_token' => 'fictional-device-' . $f['member']['id'], 'platform' => 'android'], $f['owner']['token']);
        };
        self::assertSame(1, (new NotificationWorker($transport))->run()['cancelled']);
        $device = Database::queryOne('SELECT user_id FROM device_tokens WHERE fcm_token = :token', ['token' => 'fictional-device-' . $f['member']['id']]);
        self::assertSame($f['owner']['id'], $device['user_id']);
    }

    public function testCrashLeaseRecoveryAndRetryCeiling(): void
    {
        $this->fixture(); $at = $this->at(); $transport = new FakePushTransport();
        Database::execute("UPDATE notification_outbox SET state = 'sending', attempts = 1, available_at = :at", ['at' => $at->modify('+5 minutes')->format('Y-m-d H:i:s')]);
        $worker = new NotificationWorker($transport, static function () use (&$at) { return $at; });
        self::assertSame(0, $worker->run()['processed']);
        $at = $at->modify('+6 minutes'); self::assertSame(1, $worker->run()['sent']);
        Database::execute("UPDATE notification_outbox SET state = 'pending', completed_at = NULL, attempts = 5, available_at = :at", ['at' => $at->format('Y-m-d H:i:s')]);
        $transport->result = PushResult::retry(); self::assertSame(1, $worker->run()['dead']);
        self::assertSame(6, Database::queryOne('SELECT attempts FROM notification_outbox')['attempts']);
        self::assertSame(0, $worker->run()['processed']);
    }

    public function testExpiredEventsAndFeatureSwitchesNeverCallProvider(): void
    {
        $this->fixture(); $transport = new FakePushTransport(); $worker = new NotificationWorker($transport);
        Env::set('PUSH_DELIVERY_ENABLED', 'false'); self::assertSame(1, $worker->run()['disabled']);
        Env::set('PUSH_DELIVERY_ENABLED', 'true'); $transport->ready = false; self::assertSame(1, $worker->run()['unconfigured']);
        $transport->ready = true; Env::set('PUSH_API_BASE_URL', 'http://fictional.example/api/v1'); self::assertSame(1, $worker->run()['unconfigured']);
        Env::set('PUSH_API_BASE_URL', 'https://fictional.example/api/v1');
        Database::execute('UPDATE notification_outbox SET expires_at = :at', ['at' => $this->at()->modify('-1 minute')->format('Y-m-d H:i:s')]);
        self::assertSame(1, $worker->run()['cancelled']); self::assertCount(0, $transport->calls);
    }

    public function testBatchLimitAndPerDeviceProgressDoNotResendSuccessfulDevice(): void
    {
        $f = $this->fixture(); Database::execute('DELETE FROM notification_outbox');
        $this->request('POST', '/api/v1/devices/register', ['fcm_token' => 'fictional-second-device', 'platform' => 'android'], $f['member']['token']);
        $this->createMemory($f['owner'], $f['group']);
        $at = $this->at(); $transport = new FakePushTransport();
        $transport->results = [PushResult::sent(), PushResult::retry(60)];
        $worker = new NotificationWorker($transport, static function () use (&$at) { return $at; });
        self::assertSame(1, $worker->run(1)['sent']);
        self::assertCount(1, $transport->calls);
        self::assertSame(1, $worker->run(1)['retried']);
        $at = $at->modify('+61 seconds');
        self::assertSame(1, $worker->run()['sent']);
        self::assertCount(3, $transport->calls);
        self::assertSame($transport->calls[1]['token'], $transport->calls[2]['token']);
        self::assertNotSame($transport->calls[0]['token'], $transport->calls[2]['token']);
        self::assertSame($transport->calls[0]['data']['event_id'], $transport->calls[2]['data']['event_id']);
    }

    public function testConfirmedInvalidDeletesOnlyItsTokenAndPermanentFailurePreservesToken(): void
    {
        foreach (['invalid', 'permanent'] as $case) {
            parent::setUp(); $this->fixture(); $transport = new FakePushTransport();
            $transport->result = $case === 'invalid' ? PushResult::invalid() : PushResult::permanent();
            $counts = (new NotificationWorker($transport))->run();
            self::assertSame(1, $counts[$case === 'invalid' ? 'cancelled' : 'dead']);
            self::assertCount($case === 'invalid' ? 1 : 2, Database::query('SELECT id FROM device_tokens'));
        }
    }

    public function testAnotherProcessHoldingWorkerLockPreventsDelivery(): void
    {
        $this->fixture(); self::assertSame('circle_test', Env::get('DB_DATABASE'));
        $holder = new \PDO('mysql:host=' . Env::get('DB_HOST') . ';port=' . Env::get('DB_PORT') . ';dbname=circle_test',
            Env::get('DB_USERNAME'), Env::get('DB_PASSWORD'), [\PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION]);
        $lock = 'circle_push_' . substr(hash('sha256', 'circle_test'), 0, 32);
        $acquire = $holder->prepare('SELECT GET_LOCK(:name, 0)'); $acquire->execute(['name' => $lock]);
        self::assertSame(1, (int) $acquire->fetchColumn());
        try {
            $transport = new FakePushTransport(); self::assertSame(1, (new NotificationWorker($transport))->run()['busy']);
            self::assertCount(0, $transport->calls);
        } finally {
            $release = $holder->prepare('SELECT RELEASE_LOCK(:name)'); $release->execute(['name' => $lock]);
        }
    }

    public function testTransportExceptionSchedulesRetryWithoutStoringExceptionContent(): void
    {
        $this->fixture(); $transport = new FakePushTransport();
        $transport->duringSend = static function (): void { throw new \RuntimeException('Fictional secret provider payload'); };
        self::assertSame(1, (new NotificationWorker($transport))->run()['retried']);
        $row = Database::queryOne('SELECT * FROM notification_outbox');
        self::assertSame('provider_retry', $row['last_error']); self::assertSame(1, $row['attempts']);
        self::assertStringNotContainsString('secret provider', json_encode($row, JSON_THROW_ON_ERROR));
    }

    public function testUnconfiguredIosPlatformIsExcludedFromCaptureAndDelivery(): void
    {
        $f = $this->fixture();
        $this->request('POST', '/api/v1/devices/register', ['fcm_token' => 'fictional-device-' . $f['member']['id'], 'platform' => 'ios'], $f['member']['token']);
        $this->createMemory($f['owner'], $f['group']);
        self::assertCount(1, Database::query('SELECT id FROM notification_outbox'));
        $transport = new FakePushTransport(); self::assertSame(1, (new NotificationWorker($transport))->run()['cancelled']);
        self::assertCount(0, $transport->calls);
    }

    public function testProviderResponseClassificationDoesNotTreatProject404AsInvalidToken(): void
    {
        foreach ([0, 401, 403, 408, 429, 500, 503] as $status) {
            $result = FcmSender::classify($status, '{}', '300'); self::assertSame('retry', $result->status); self::assertSame(300, $result->retryAfter);
        }
        self::assertSame('sent', FcmSender::classify(200, '{"name":"projects/fictional/messages/fixture"}')->status);
        self::assertSame('retry', FcmSender::classify(200, '{}')->status);
        self::assertSame('permanent', FcmSender::classify(404, '{"error":{"message":"Project missing"}}')->status);
        self::assertSame('permanent', FcmSender::classify(400, '{}')->status);
        self::assertSame('invalid', FcmSender::classify(404, '{"error":{"details":[{"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"UNREGISTERED"}]}}')->status);
    }
}
