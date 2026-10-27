<?php

declare(strict_types=1);

namespace Circle\Notifications;

use Circle\Controllers\GroupInvitationController;
use Circle\Controllers\MemoryController;
use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Core\NotificationPreferences;

final class NotificationWorker
{
    private const MAX_ATTEMPTS = 6;
    private readonly \Closure $clock;

    public function __construct(private readonly PushTransport $transport, ?\Closure $clock = null)
    {
        $this->clock = $clock ?? static fn (): \DateTimeImmutable => new \DateTimeImmutable('now', new \DateTimeZone('UTC'));
    }

    /**
     * Counts only: never tokens, account ids or payloads.
     * @return array<string, int>
     * @phpstan-impure
     */
    public function run(int $limit = 50): array
    {
        $counts = array_fill_keys(['processed', 'sent', 'retried', 'deferred', 'cancelled', 'dead', 'busy', 'disabled', 'unconfigured'], 0);
        if (Env::get('PUSH_DELIVERY_ENABLED', 'false') !== 'true') { $counts['disabled'] = 1; return $counts; }
        $origin = rtrim(Env::get('PUSH_API_BASE_URL'), '/');
        $url = parse_url($origin);
        if (strlen($origin) > 512 || filter_var($origin, FILTER_VALIDATE_URL) === false || !$this->transport->isReady() || !is_array($url) || ($url['scheme'] ?? '') !== 'https'
            || empty($url['host']) || isset($url['user']) || isset($url['pass']) || isset($url['query']) || isset($url['fragment'])
            || !str_ends_with($url['path'] ?? '', '/api/v1')) { $counts['unconfigured'] = 1; return $counts; }
        $database = Database::queryOne('SELECT DATABASE() AS name');
        $lock = 'circle_push_' . substr(hash('sha256', (string) ($database['name'] ?? '')), 0, 32);
        if ((int) (Database::queryOne('SELECT GET_LOCK(:name, 0) AS acquired', ['name' => $lock])['acquired'] ?? 0) !== 1) {
            $counts['busy'] = 1; return $counts;
        }
        $started = microtime(true);
        try {
            $now = $this->now();
            // A crashed process releases the advisory lock. Its five-minute
            // lease bounds recovery; acceptance may have preceded the crash.
            Database::execute("UPDATE notification_outbox SET state = 'pending' WHERE state = 'sending' AND available_at <= :now LIMIT 1000", ['now' => $now]);
            $counts['cancelled'] += Database::execute("UPDATE notification_outbox SET state = 'cancelled', last_error = 'expired', completed_at = :done
                WHERE state = 'pending' AND expires_at <= :now LIMIT 1000", ['done' => $now, 'now' => $now]);
            $rows = Database::query("SELECT * FROM notification_outbox WHERE state = 'pending' AND available_at <= :now
                ORDER BY available_at, id LIMIT :lim", ['now' => $now, 'lim' => max(1, min(100, $limit))]);
            foreach ($rows as $row) {
                if (microtime(true) - $started >= 45) break;
                $now = $this->now();
                if (Database::execute("UPDATE notification_outbox SET state = 'sending', available_at = :lease
                    WHERE id = :id AND state = 'pending'", ['lease' => $this->clockAt()->modify('+5 minutes')->format('Y-m-d H:i:s'), 'id' => $row['id']]) !== 1) continue;
                $counts['processed']++;
                $invitation = $row['kind'] === 'group.invitation';
                $report = $row['kind'] === 'group.report';
                $category = $row['kind'] === 'memory.created' ? 'memories' : 'replies_reactions';
                $device = Database::queryOne("SELECT dt.fcm_token FROM device_tokens dt
                    WHERE dt.id = :did AND dt.user_id = :uid AND dt.session_id = :sid AND dt.platform = 'android'
                    AND EXISTS (SELECT 1 FROM refresh_tokens rt WHERE rt.user_id = dt.user_id AND rt.session_id = dt.session_id
                        AND rt.revoked_at IS NULL AND rt.expires_at > :now)",
                    ['did' => $row['device_id'], 'uid' => $row['user_id'], 'sid' => $row['session_id'], 'now' => $now]);
                if ($report) {
                    $content = Database::queryOne("SELECT t.id FROM moderation_targets t JOIN group_members gm ON gm.group_id=t.group_id AND gm.user_id=:uid AND gm.role='admin' AND gm.status='active' JOIN users u ON u.id=gm.user_id AND u.status='active'
                        WHERE t.id=:target AND t.group_id=:gid AND EXISTS(SELECT 1 FROM reports r WHERE r.target_id=t.id AND r.dismissed=0)", ['uid'=>$row['user_id'],'target'=>$row['moderation_target_id'],'gid'=>$row['group_id']]);
                    $eligible = $content !== null && $row['memory_id'] === null && $row['comment_id'] === null && $row['invitation_id'] === null && NotificationPreferences::eligible((int)$row['user_id'],'groups',(int)$row['group_id']);
                } elseif ($invitation) {
                    $content = Database::queryOne('SELECT id FROM group_invitations WHERE id = :id AND recipient_id = :uid AND group_id = :gid',
                        ['id' => $row['invitation_id'], 'uid' => $row['user_id'], 'gid' => $row['group_id']]);
                    $eligible = $content !== null && $row['memory_id'] === null && $row['comment_id'] === null
                        && GroupInvitationController::eligible((int) $row['invitation_id'], (int) $row['user_id'])
                        && NotificationPreferences::invitationEligible((int) $row['user_id']);
                } else {
                    $content = Database::queryOne("SELECT m.id FROM memories m WHERE m.id = :mid AND m.group_id = :gid AND m.status = 'active'",
                        ['mid' => $row['memory_id'], 'gid' => $row['group_id']]);
                    if ($row['comment_id'] !== null && Database::queryOne("SELECT id FROM comments WHERE id = :cid AND memory_id = :mid AND status = 'active'",
                        ['cid' => $row['comment_id'], 'mid' => $row['memory_id']]) === null) $content = null;
                    if ($row['comment_id'] !== null && !MemoryController::commentIsVisible((int)$row['comment_id'],(int)$row['user_id'])) $content = null;
                    $eligible = $content !== null && NotificationPreferences::eligible((int) $row['user_id'], $category, (int) $row['group_id']);
                }
                if ($row['expires_at'] <= $now || $device === null || !$eligible) {
                    $this->finish((int) $row['id'], 'cancelled', 'ineligible'); $counts['cancelled']++; continue;
                }
                $quietUntil = NotificationPreferences::quietUntil((int) $row['user_id'], $this->clockAt());
                if ($quietUntil !== null) {
                    $this->pending((int) $row['id'], $quietUntil, 'quiet_hours'); $counts['deferred']++; continue;
                }
                if ((int) $row['attempts'] >= self::MAX_ATTEMPTS) {
                    $this->finish((int) $row['id'], 'dead', 'retry_exhausted'); $counts['dead']++; continue;
                }
                // Persist the attempt before network I/O. Never hold a DB
                // transaction open during the provider request.
                Database::execute('UPDATE notification_outbox SET attempts = attempts + 1 WHERE id = :id', ['id' => $row['id']]);
                try {
                    $data = [
                        'event_id' => hash('sha256', (string) $row['event_key']), 'type' => (string) $row['kind'],
                        'api_base_url' => $origin, 'recipient_id' => (string) $row['user_id'],
                        'session_scope' => hash('sha256', (string) $row['session_id']),
                        'group_id' => (string) $row['group_id'],
                        'expires_at' => (string) (new \DateTimeImmutable((string) $row['expires_at'], new \DateTimeZone('UTC')))->getTimestamp(),
                    ];
                    if ($invitation) $data['invitation_id'] = (string) $row['invitation_id'];
                    elseif (!$report) {
                        $data['memory_id'] = (string) $row['memory_id'];
                        $data['comment_id'] = $row['comment_id'] === null ? '' : (string) $row['comment_id'];
                    }
                    $result = $this->transport->send((string) $device['fcm_token'], $data);
                } catch (\Throwable) { $result = PushResult::retry(); }
                if ($result->status === 'sent') {
                    $this->finish((int) $row['id'], 'sent', null); $counts['sent']++;
                } elseif ($result->status === 'invalid') {
                    // Do not erase a token reassigned while the HTTP request ran.
                    Database::execute('DELETE FROM device_tokens WHERE id = :id AND user_id = :uid AND session_id = :sid AND fcm_token = :token',
                        ['id' => $row['device_id'], 'uid' => $row['user_id'], 'sid' => $row['session_id'], 'token' => $device['fcm_token']]);
                    $this->finish((int) $row['id'], 'cancelled', 'unregistered'); $counts['cancelled']++;
                } elseif ($result->status === 'permanent' || (int) $row['attempts'] + 1 >= self::MAX_ATTEMPTS) {
                    $this->finish((int) $row['id'], 'dead', $result->status === 'permanent' ? 'provider_rejected' : 'retry_exhausted'); $counts['dead']++;
                } else {
                    $delay = max($result->retryAfter, min(3600, 60 * (2 ** (int) $row['attempts'])));
                    $this->pending((int) $row['id'], $this->clockAt()->modify('+' . $delay . ' seconds'), 'provider_retry'); $counts['retried']++;
                }
            }
        } finally {
            Database::queryOne('SELECT RELEASE_LOCK(:name)', ['name' => $lock]);
        }
        return $counts;
    }

    private function clockAt(): \DateTimeImmutable { return ($this->clock)()->setTimezone(new \DateTimeZone('UTC')); }
    private function now(): string { return $this->clockAt()->format('Y-m-d H:i:s'); }
    private function finish(int $id, string $state, ?string $reason): void
    {
        Database::execute('UPDATE notification_outbox SET state = :state, completed_at = :now, last_error = :reason WHERE id = :id',
            ['state' => $state, 'now' => $this->now(), 'reason' => $reason, 'id' => $id]);
    }
    private function pending(int $id, \DateTimeImmutable $at, string $reason): void
    {
        Database::execute("UPDATE notification_outbox SET state = 'pending', available_at = :at, last_error = :reason WHERE id = :id",
            ['at' => $at->format('Y-m-d H:i:s'), 'reason' => $reason, 'id' => $id]);
    }
}
