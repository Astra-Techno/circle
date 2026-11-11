<?php

/**
 * CIRCLE AI Agent Test Harness
 *
 * Simulates 25 realistic personas across 5 groups performing real API
 * interactions: register, login, create groups, post memories, comment,
 * react, vote on polls, RSVP events, and chat.
 *
 * Usage:
 *   php run.php                          # Against local dev (default)
 *   php run.php --api=https://circle.cloudkart24.com/api/v1
 *   php run.php --phase=setup            # Only register + create groups
 *   php run.php --phase=simulate         # Only run activity (accounts must exist)
 *   php run.php --phase=all              # Full run (default)
 *   php run.php --speed=fast             # Minimal delays
 *   php run.php --speed=realistic        # Human-like delays (default)
 *   php run.php --cleanup                # Delete all test accounts
 */

declare(strict_types=1);

error_reporting(E_ALL);
set_time_limit(0);

// ─── Configuration ──────────────────────────────────────────────────

$opts = getopt('', ['api:', 'phase:', 'speed:', 'cleanup', 'verbose', 'dry-run']);
$API_BASE    = rtrim($opts['api'] ?? 'http://127.0.0.1:8089/api/v1', '/');
$PHASE       = $opts['phase'] ?? 'all';
$SPEED       = $opts['speed'] ?? 'realistic';
$CLEANUP     = isset($opts['cleanup']);
$VERBOSE     = isset($opts['verbose']);
$DRY_RUN     = isset($opts['dry-run']);
$PASSWORD    = 'circle_test_agent_2026!';
$STATE_FILE  = __DIR__ . '/state.json';
$LOG_FILE    = __DIR__ . '/report.log';
$PERSONAS    = json_decode(file_get_contents(__DIR__ . '/personas.json'), true);

// Rate-limit budgets (requests remaining in current window)
$rateBudget = ['auth' => 8, 'general' => 50]; // Leave headroom
$rateWindowStart = time();

// ─── HTTP Client ────────────────────────────────────────────────────

class ApiClient
{
    private string $base;
    private bool $verbose;
    private array $log = [];
    private array $errors = [];
    private array $timings = [];
    private int $requestCount = 0;

    public function __construct(string $base, bool $verbose = false)
    {
        $this->base = $base;
        $this->verbose = $verbose;
    }

    /**
     * @param array<string, mixed> $body
     * @param array<string, string> $headers
     * @return array{status: int, body: array<string, mixed>, time_ms: float}
     */
    public function request(
        string $method,
        string $path,
        array $body = [],
        ?string $token = null,
        array $headers = [],
    ): array {
        $url = $this->base . $path;
        $ch = curl_init();

        $curlHeaders = ['Content-Type: application/json', 'Accept: application/json'];
        if ($token !== null) {
            $curlHeaders[] = 'Authorization: Bearer ' . $token;
        }
        foreach ($headers as $k => $v) {
            $curlHeaders[] = "$k: $v";
        }

        curl_setopt_array($ch, [
            CURLOPT_URL            => $url,
            CURLOPT_CUSTOMREQUEST  => strtoupper($method),
            CURLOPT_HTTPHEADER     => $curlHeaders,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 30,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_SSL_VERIFYHOST => 0,
        ]);

        if (!empty($body) && in_array(strtoupper($method), ['POST', 'PUT', 'PATCH'])) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
        }

        $start = microtime(true);
        $raw = curl_exec($ch);
        $elapsed = (microtime(true) - $start) * 1000;
        $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);

        $this->requestCount++;
        $this->timings[] = $elapsed;

        $decoded = $raw !== false ? json_decode($raw, true) ?? [] : [];

        $entry = [
            'method'  => $method,
            'path'    => $path,
            'status'  => $status,
            'time_ms' => round($elapsed, 1),
        ];

        if ($status === 0) {
            $entry['curl_error'] = $error;
            $this->errors[] = $entry;
        } elseif ($status >= 400) {
            $entry['error_code'] = $decoded['code'] ?? ($decoded['message'] ?? 'unknown');
            $entry['body'] = $decoded;
            $this->errors[] = $entry;
        }

        if ($this->verbose) {
            $emoji = $status >= 200 && $status < 300 ? '[OK]' : '[!!]';
            fprintf(STDERR, "  %s %s %s -> %d (%.0fms)\n", $emoji, $method, $path, $status, $elapsed);
        }

        $this->log[] = $entry;

        return ['status' => $status, 'body' => $decoded, 'time_ms' => $elapsed];
    }

    public function get(string $path, ?string $token = null): array
    {
        return $this->request('GET', $path, [], $token);
    }

    public function post(string $path, array $body = [], ?string $token = null): array
    {
        return $this->request('POST', $path, $body, $token);
    }

    public function patch(string $path, array $body, ?string $token = null): array
    {
        return $this->request('PATCH', $path, $body, $token);
    }

    public function put(string $path, array $body = [], ?string $token = null): array
    {
        return $this->request('PUT', $path, $body, $token);
    }

    public function getLog(): array { return $this->log; }
    public function getErrors(): array { return $this->errors; }
    public function getTimings(): array { return $this->timings; }
    public function getRequestCount(): int { return $this->requestCount; }
}

// ─── State Management ───────────────────────────────────────────────

function loadState(string $file): array
{
    if (file_exists($file)) {
        return json_decode(file_get_contents($file), true) ?? [];
    }
    return ['accounts' => [], 'groups' => [], 'memories' => [], 'polls' => [], 'events' => []];
}

function saveState(string $file, array $state): void
{
    file_put_contents($file, json_encode($state, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
}

// ─── Rate-limit pacer ───────────────────────────────────────────────

function pace(string $bucket, string $speed): void
{
    global $rateBudget, $rateWindowStart;

    $now = time();
    if ($now - $rateWindowStart >= 60) {
        $rateBudget = ['auth' => 8, 'general' => 50];
        $rateWindowStart = $now;
    }

    $rateBudget[$bucket]--;
    if ($rateBudget[$bucket] <= 0) {
        $wait = 60 - ($now - $rateWindowStart) + 2;
        fprintf(STDERR, "  [PACE] Rate limit approaching on '%s', waiting %ds...\n", $bucket, $wait);
        sleep($wait);
        $rateBudget = ['auth' => 8, 'general' => 50];
        $rateWindowStart = time();
    }

    // Human-like delay
    if ($speed === 'realistic') {
        usleep(random_int(200_000, 800_000)); // 0.2-0.8s
    } elseif ($speed !== 'fast') {
        usleep(100_000); // 0.1s minimum
    }
}

// ─── Unique client_id generator ─────────────────────────────────────

function clientId(): string
{
    return 'agent_' . bin2hex(random_bytes(12));
}

// ─── Phase 1: Setup ─────────────────────────────────────────────────

function phaseSetup(ApiClient $api, array $personas, string $password, string $speed): array
{
    $state = ['accounts' => [], 'groups' => [], 'memories' => [], 'polls' => [], 'events' => []];

    fprintf(STDERR, "\n=== PHASE 1: REGISTERING %d PERSONAS ===\n", count($personas['personas']));

    foreach ($personas['personas'] as $p) {
        pace('auth', $speed);
        $res = $api->post('/auth/register', [
            'mobile'       => $p['mobile'],
            'password'     => $password,
            'display_name' => $p['display_name'],
        ]);

        if ($res['status'] === 202 || ($res['status'] === 409)) {
            // 409 = already registered, which is fine
            fprintf(STDERR, "  Registered: %s (%s) %s\n", $p['display_name'], $p['mobile'],
                $res['status'] === 409 ? '(already exists)' : '');
        } else {
            fprintf(STDERR, "  FAILED to register %s: %d %s\n", $p['display_name'],
                $res['status'], json_encode($res['body']));
            continue;
        }

        // Login
        pace('auth', $speed);
        $login = $api->post('/auth/login', [
            'mobile'   => $p['mobile'],
            'password' => $password,
        ], null, ['X-Circle-Device' => 'AgentBot/1.0', 'X-Circle-App' => '1.0.37']);

        if ($login['status'] !== 200) {
            fprintf(STDERR, "  FAILED to login %s: %d\n", $p['display_name'], $login['status']);
            continue;
        }

        $token = $login['body']['data']['access_token'] ?? null;
        $userId = $login['body']['data']['user']['id'] ?? null;

        if (!$token || !$userId) {
            fprintf(STDERR, "  FAILED: no token for %s\n", $p['display_name']);
            continue;
        }

        $state['accounts'][$p['key']] = [
            'user_id' => $userId,
            'token'   => $token,
            'mobile'  => $p['mobile'],
            'name'    => $p['display_name'],
        ];

        // Update profile
        $profile = [];
        foreach (['about', 'current_city', 'hometown', 'work', 'education'] as $field) {
            if (!empty($p[$field])) {
                $profile[$field] = $p[$field];
            }
        }
        if (!empty($profile)) {
            pace('general', $speed);
            $api->patch('/me', $profile, $token);
        }

        fprintf(STDERR, "  Logged in: %s (id=%d)\n", $p['display_name'], $userId);
    }

    // ── Create groups ───────────────────────────────────────────────
    fprintf(STDERR, "\n=== PHASE 1: CREATING %d GROUPS ===\n", count($personas['groups']));

    foreach ($personas['groups'] as $g) {
        // Find the owner persona for this group
        $ownerKey = null;
        foreach ($personas['personas'] as $p) {
            if (in_array($g['key'], $p['owns'] ?? [])) {
                $ownerKey = $p['key'];
                break;
            }
        }
        if (!$ownerKey || !isset($state['accounts'][$ownerKey])) {
            fprintf(STDERR, "  SKIP group %s: no owner account\n", $g['key']);
            continue;
        }
        $ownerToken = $state['accounts'][$ownerKey]['token'];

        pace('general', $speed);
        $res = $api->post('/groups', [
            'name'        => $g['name'],
            'type'        => $g['type'],
            'description' => $g['description'],
        ], $ownerToken);

        if ($res['status'] === 201) {
            $groupId = $res['body']['data']['id'];
            $state['groups'][$g['key']] = ['id' => $groupId, 'owner' => $ownerKey];
            fprintf(STDERR, "  Created group: %s (id=%d, owner=%s)\n", $g['name'], $groupId, $ownerKey);

            // Create subgroups
            foreach ($g['subgroups'] as $sub) {
                $subOwnerKey = null;
                foreach ($personas['personas'] as $p) {
                    if (in_array($sub['key'], $p['owns'] ?? [])) {
                        $subOwnerKey = $p['key'];
                        break;
                    }
                }
                // If no explicit owner, use parent owner
                $subToken = isset($state['accounts'][$subOwnerKey])
                    ? $state['accounts'][$subOwnerKey]['token']
                    : $ownerToken;

                pace('general', $speed);
                $subRes = $api->post('/groups', [
                    'name'        => $sub['name'],
                    'type'        => $sub['type'],
                    'description' => $sub['description'],
                    'parent_id'   => $groupId,
                ], $subToken);

                if ($subRes['status'] === 201) {
                    $subId = $subRes['body']['data']['id'];
                    $state['groups'][$sub['key']] = ['id' => $subId, 'owner' => $subOwnerKey ?? $ownerKey];
                    fprintf(STDERR, "    Subgroup: %s (id=%d)\n", $sub['name'], $subId);
                } else {
                    fprintf(STDERR, "    FAILED subgroup %s: %d\n", $sub['name'], $subRes['status']);
                }
            }
        } else {
            fprintf(STDERR, "  FAILED group %s: %d %s\n", $g['name'], $res['status'], json_encode($res['body']));
        }
    }

    // ── Invite members to groups via invite links ───────────────────
    fprintf(STDERR, "\n=== PHASE 1: INVITING MEMBERS TO GROUPS ===\n");

    foreach ($personas['groups'] as $g) {
        $allSubKeys = array_merge([$g['key']], array_column($g['subgroups'], 'key'));

        foreach ($allSubKeys as $groupKey) {
            if (!isset($state['groups'][$groupKey])) continue;

            $groupId = $state['groups'][$groupKey]['id'];
            $ownerKey = $state['groups'][$groupKey]['owner'];
            if (!isset($state['accounts'][$ownerKey])) continue;
            $ownerToken = $state['accounts'][$ownerKey]['token'];

            // Create an invite link
            pace('general', $speed);
            $linkRes = $api->post("/groups/{$groupId}/invite-links", [
                'expires_in_hours' => 168,
            ], $ownerToken);

            if ($linkRes['status'] !== 201) {
                fprintf(STDERR, "  FAILED invite link for %s: %d\n", $groupKey, $linkRes['status']);
                continue;
            }

            $inviteToken = $linkRes['body']['data']['token'] ?? null;
            if (!$inviteToken) continue;

            // Each persona who should be in this group joins
            foreach ($personas['personas'] as $p) {
                if (!in_array($groupKey, $p['groups'])) continue;
                if ($p['key'] === $ownerKey) continue; // Already a member
                if (!isset($state['accounts'][$p['key']])) continue;

                $memberToken = $state['accounts'][$p['key']]['token'];
                pace('general', $speed);
                $joinRes = $api->post("/invites/{$inviteToken}/join", [], $memberToken);
                $status = $joinRes['body']['data']['status'] ?? 'unknown';
                fprintf(STDERR, "  %s joined %s: %s\n", $p['display_name'], $groupKey, $status);
            }
        }
    }

    return $state;
}

// ─── Phase 2: Simulate Activity ─────────────────────────────────────

function phaseSimulate(ApiClient $api, array $personas, array &$state, string $speed): void
{
    // ── Post Memories ───────────────────────────────────────────────
    fprintf(STDERR, "\n=== PHASE 2: POSTING MEMORIES ===\n");

    $memTemplates = $personas['content_templates']['memories'];
    foreach ($personas['personas'] as $p) {
        if (!isset($state['accounts'][$p['key']])) continue;
        $token = $state['accounts'][$p['key']]['token'];

        // Active posters post 3-4, moderate 1-2, lurkers 0, organizers 2
        $postCount = match ($p['behavior']) {
            'active_poster' => random_int(3, 4),
            'moderate'      => random_int(1, 2),
            'organizer'     => 2,
            'lurker'        => random_int(0, 1),
            default         => 1,
        };

        // Pick groups this persona belongs to and post memories
        $memberGroups = array_filter($p['groups'], fn($gk) => isset($state['groups'][$gk]));
        if (empty($memberGroups)) continue;

        for ($i = 0; $i < $postCount; $i++) {
            $groupKey = $memberGroups[array_rand($memberGroups)];
            $groupId = $state['groups'][$groupKey]['id'];

            // Find root group key for templates
            $templateKey = $groupKey;
            if (!isset($memTemplates[$templateKey])) {
                // Try parent group
                foreach ($personas['groups'] as $g) {
                    foreach ($g['subgroups'] as $sub) {
                        if ($sub['key'] === $groupKey) {
                            $templateKey = $g['key'];
                            break 2;
                        }
                    }
                }
            }

            $texts = $memTemplates[$templateKey] ?? $memTemplates['techcorp_office'];
            $body = $texts[array_rand($texts)];

            pace('general', $speed);
            $res = $api->post("/groups/{$groupId}/memories", [
                'body' => $body,
            ], $token);

            if ($res['status'] === 201) {
                $memId = $res['body']['data']['id'];
                $state['memories'][] = ['id' => $memId, 'group_key' => $groupKey, 'author' => $p['key']];
                fprintf(STDERR, "  %s posted in %s: \"%s\" (id=%d)\n",
                    $p['display_name'], $groupKey, mb_substr($body, 0, 40) . '...', $memId);
            } else {
                fprintf(STDERR, "  FAILED: %s post in %s: %d %s\n",
                    $p['display_name'], $groupKey, $res['status'],
                    $res['body']['code'] ?? $res['body']['message'] ?? '');
            }
        }
    }

    // ── React to Memories ───────────────────────────────────────────
    fprintf(STDERR, "\n=== PHASE 2: REACTING TO MEMORIES ===\n");

    $emojis = ['❤️', '👍', '😂', '😮', '🙏', '🎉', '👏'];
    foreach ($state['memories'] as $mem) {
        // 3-8 people react to each memory
        $reactCount = random_int(3, min(8, count($personas['personas'])));
        $reactors = array_rand(array_flip(array_keys($state['accounts'])), $reactCount);
        if (!is_array($reactors)) $reactors = [$reactors];

        foreach ($reactors as $reactorKey) {
            // Only react if the person is in the same group
            $persona = null;
            foreach ($personas['personas'] as $pp) {
                if ($pp['key'] === $reactorKey) { $persona = $pp; break; }
            }
            if (!$persona || !in_array($mem['group_key'], $persona['groups'])) continue;

            $token = $state['accounts'][$reactorKey]['token'];
            pace('general', $speed);
            $api->post("/memories/{$mem['id']}/reactions", [
                'emoji' => $emojis[array_rand($emojis)],
            ], $token);
        }
        fprintf(STDERR, "  Memory %d got reactions\n", $mem['id']);
    }

    // ── Comment on Memories ─────────────────────────────────────────
    fprintf(STDERR, "\n=== PHASE 2: COMMENTING ON MEMORIES ===\n");

    $commentTexts = $personas['content_templates']['comments'];
    foreach ($state['memories'] as $mem) {
        $commentCount = random_int(1, 4);
        $commenters = array_rand(array_flip(array_keys($state['accounts'])),
            min($commentCount, count($state['accounts'])));
        if (!is_array($commenters)) $commenters = [$commenters];

        foreach ($commenters as $commenterKey) {
            $persona = null;
            foreach ($personas['personas'] as $pp) {
                if ($pp['key'] === $commenterKey) { $persona = $pp; break; }
            }
            if (!$persona || !in_array($mem['group_key'], $persona['groups'])) continue;

            $token = $state['accounts'][$commenterKey]['token'];
            pace('general', $speed);
            $res = $api->post("/memories/{$mem['id']}/comments", [
                'body' => $commentTexts[array_rand($commentTexts)],
            ], $token);

            if ($res['status'] === 201) {
                fprintf(STDERR, "  %s commented on memory %d\n", $persona['display_name'], $mem['id']);
            }
        }
    }

    // ── Save some Memories ──────────────────────────────────────────
    fprintf(STDERR, "\n=== PHASE 2: SAVING MEMORIES ===\n");

    foreach ($state['memories'] as $mem) {
        if (random_int(1, 3) !== 1) continue; // ~33% chance
        $saverKeys = array_keys($state['accounts']);
        $saverKey = $saverKeys[array_rand($saverKeys)];
        $persona = null;
        foreach ($personas['personas'] as $pp) {
            if ($pp['key'] === $saverKey) { $persona = $pp; break; }
        }
        if (!$persona || !in_array($mem['group_key'], $persona['groups'])) continue;

        pace('general', $speed);
        $api->post("/memories/{$mem['id']}/save", [], $state['accounts'][$saverKey]['token']);
        fprintf(STDERR, "  %s saved memory %d\n", $persona['display_name'], $mem['id']);
    }

    // ── Create Polls ────────────────────────────────────────────────
    fprintf(STDERR, "\n=== PHASE 2: CREATING POLLS ===\n");

    foreach ($personas['content_templates']['polls'] as $pollTpl) {
        // Pick a group this poll belongs to
        $targetGroupKey = null;
        foreach ($pollTpl['group_keys'] as $gk) {
            if (isset($state['groups'][$gk])) { $targetGroupKey = $gk; break; }
        }
        if (!$targetGroupKey) continue;

        // Find an organizer or active poster in that group
        $creatorKey = null;
        foreach ($personas['personas'] as $p) {
            if (in_array($targetGroupKey, $p['groups']) && isset($state['accounts'][$p['key']])
                && in_array($p['behavior'], ['organizer', 'active_poster', 'moderate'])) {
                $creatorKey = $p['key'];
                break;
            }
        }
        if (!$creatorKey) continue;

        $groupId = $state['groups'][$targetGroupKey]['id'];
        $token = $state['accounts'][$creatorKey]['token'];

        pace('general', $speed);
        $res = $api->post("/groups/{$groupId}/polls", [
            'client_id' => clientId(),
            'question'  => $pollTpl['question'],
            'options'   => $pollTpl['options'],
            'poll_type' => 'single',
        ], $token);

        if ($res['status'] === 200 || $res['status'] === 201) {
            $pollId = $res['body']['data']['id'];
            $state['polls'][] = ['id' => $pollId, 'group_key' => $targetGroupKey, 'creator' => $creatorKey];
            fprintf(STDERR, "  Poll created: \"%s\" (id=%d) in %s\n",
                mb_substr($pollTpl['question'], 0, 40), $pollId, $targetGroupKey);
        } else {
            fprintf(STDERR, "  FAILED poll: %d %s\n", $res['status'], json_encode($res['body']));
        }
    }

    // ── Vote on Polls ───────────────────────────────────────────────
    fprintf(STDERR, "\n=== PHASE 2: VOTING ON POLLS ===\n");

    foreach ($state['polls'] as $poll) {
        // First get poll details to know option IDs
        $anyMember = null;
        foreach ($personas['personas'] as $p) {
            if (in_array($poll['group_key'], $p['groups']) && isset($state['accounts'][$p['key']])) {
                $anyMember = $p['key'];
                break;
            }
        }
        if (!$anyMember) continue;

        pace('general', $speed);
        $detail = $api->get("/polls/{$poll['id']}", $state['accounts'][$anyMember]['token']);
        if ($detail['status'] !== 200) continue;

        $options = $detail['body']['data']['options'] ?? [];
        if (empty($options)) continue;
        $optionIds = array_column($options, 'id');

        // Each member in the group votes
        foreach ($personas['personas'] as $p) {
            if (!in_array($poll['group_key'], $p['groups'])) continue;
            if (!isset($state['accounts'][$p['key']])) continue;
            if ($p['behavior'] === 'lurker' && random_int(1, 3) !== 1) continue; // lurkers rarely vote

            $token = $state['accounts'][$p['key']]['token'];
            $chosenOption = $optionIds[array_rand($optionIds)];

            pace('general', $speed);
            $voteRes = $api->put("/polls/{$poll['id']}/votes", [
                'option_ids' => [$chosenOption],
            ], $token);

            if ($voteRes['status'] === 200) {
                fprintf(STDERR, "  %s voted on poll %d\n", $p['display_name'], $poll['id']);
            }
        }
    }

    // ── Create Events ───────────────────────────────────────────────
    fprintf(STDERR, "\n=== PHASE 2: CREATING EVENTS ===\n");

    foreach ($personas['content_templates']['events'] as $evtTpl) {
        $targetGroupKey = null;
        foreach ($evtTpl['group_keys'] as $gk) {
            if (isset($state['groups'][$gk])) { $targetGroupKey = $gk; break; }
        }
        if (!$targetGroupKey) continue;

        // Find an organizer or active member
        $creatorKey = null;
        foreach ($personas['personas'] as $p) {
            if (in_array($targetGroupKey, $p['groups']) && isset($state['accounts'][$p['key']])
                && in_array($p['behavior'], ['organizer', 'active_poster', 'moderate'])) {
                $creatorKey = $p['key'];
                break;
            }
        }
        if (!$creatorKey) continue;

        $groupId = $state['groups'][$targetGroupKey]['id'];
        $token = $state['accounts'][$creatorKey]['token'];
        $startAt = (new DateTimeImmutable('+' . $evtTpl['hours_from_now'] . ' hours'))
            ->format('Y-m-d\TH:i:sP');

        pace('general', $speed);
        $res = $api->post("/groups/{$groupId}/events", [
            'client_id'   => clientId(),
            'title'       => $evtTpl['title'],
            'description' => $evtTpl['description'],
            'event_type'  => $evtTpl['event_type'],
            'venue'       => $evtTpl['venue'],
            'start_at'    => $startAt,
            'timezone'    => 'Asia/Kolkata',
        ], $token);

        if ($res['status'] === 200 || $res['status'] === 201) {
            $eventId = $res['body']['data']['id'];
            $state['events'][] = ['id' => $eventId, 'group_key' => $targetGroupKey, 'creator' => $creatorKey];
            fprintf(STDERR, "  Event created: \"%s\" (id=%d)\n", $evtTpl['title'], $eventId);
        } else {
            fprintf(STDERR, "  FAILED event: %d %s\n", $res['status'], json_encode($res['body']));
        }
    }

    // ── RSVP to Events ──────────────────────────────────────────────
    fprintf(STDERR, "\n=== PHASE 2: RSVP TO EVENTS ===\n");

    $rsvpStatuses = ['going', 'going', 'going', 'maybe', 'not_going']; // Weighted towards going
    foreach ($state['events'] as $evt) {
        foreach ($personas['personas'] as $p) {
            if (!in_array($evt['group_key'], $p['groups'])) continue;
            if (!isset($state['accounts'][$p['key']])) continue;
            if ($p['behavior'] === 'lurker' && random_int(1, 2) !== 1) continue;

            $token = $state['accounts'][$p['key']]['token'];
            $rsvp = $rsvpStatuses[array_rand($rsvpStatuses)];

            pace('general', $speed);
            $res = $api->put("/events/{$evt['id']}/rsvp", [
                'status' => $rsvp,
            ], $token);

            if ($res['status'] === 200) {
                fprintf(STDERR, "  %s RSVP %s to event %d\n", $p['display_name'], $rsvp, $evt['id']);
            }
        }
    }

    // ── Group Chat Messages ─────────────────────────────────────────
    fprintf(STDERR, "\n=== PHASE 2: GROUP CHAT MESSAGES ===\n");

    $chatTemplates = $personas['content_templates']['chat_messages'];
    foreach ($chatTemplates as $groupKey => $messages) {
        if (!isset($state['groups'][$groupKey])) continue;
        $groupId = $state['groups'][$groupKey]['id'];

        // Get group chat conversation ID
        $firstMember = null;
        foreach ($personas['personas'] as $p) {
            if (in_array($groupKey, $p['groups']) && isset($state['accounts'][$p['key']])) {
                $firstMember = $p['key'];
                break;
            }
        }
        if (!$firstMember) continue;

        pace('general', $speed);
        $chatRes = $api->get("/groups/{$groupId}/chat", $state['accounts'][$firstMember]['token']);
        if ($chatRes['status'] !== 200) {
            fprintf(STDERR, "  SKIP chat for %s: %d\n", $groupKey, $chatRes['status']);
            continue;
        }
        $conversationId = $chatRes['body']['data']['id'] ?? null;
        if (!$conversationId) continue;

        // Multiple people send messages
        $groupMembers = [];
        foreach ($personas['personas'] as $p) {
            if (in_array($groupKey, $p['groups']) && isset($state['accounts'][$p['key']])) {
                $groupMembers[] = $p;
            }
        }

        $msgCount = min(count($messages), random_int(4, 8));
        for ($i = 0; $i < $msgCount; $i++) {
            $sender = $groupMembers[array_rand($groupMembers)];
            $token = $state['accounts'][$sender['key']]['token'];
            $msg = $messages[array_rand($messages)];

            pace('general', $speed);
            $res = $api->post("/chats/{$conversationId}/messages", [
                'body'      => $msg,
                'client_id' => clientId(),
            ], $token);

            if ($res['status'] === 200) {
                fprintf(STDERR, "  %s in %s: \"%s\"\n", $sender['display_name'], $groupKey, $msg);
            } else {
                fprintf(STDERR, "  FAILED chat %s: %d %s\n", $groupKey, $res['status'],
                    $res['body']['code'] ?? '');
            }
        }
    }

    // ── Browse: list memories, check profiles ───────────────────────
    fprintf(STDERR, "\n=== PHASE 2: BROWSE & READ VALIDATION ===\n");

    // Random personas browse the home feed
    $browsers = array_rand(array_flip(array_keys($state['accounts'])), min(5, count($state['accounts'])));
    if (!is_array($browsers)) $browsers = [$browsers];

    foreach ($browsers as $browserKey) {
        $token = $state['accounts'][$browserKey]['token'];

        pace('general', $speed);
        $feed = $api->get('/memories?limit=20', $token);
        $count = count($feed['body']['data'] ?? []);
        fprintf(STDERR, "  %s browsed home: %d memories\n", $state['accounts'][$browserKey]['name'], $count);

        // Check own profile
        pace('general', $speed);
        $me = $api->get('/me', $token);
        if ($me['status'] === 200) {
            fprintf(STDERR, "  %s profile OK\n", $me['body']['data']['display_name'] ?? 'unknown');
        }

        // List groups
        pace('general', $speed);
        $groups = $api->get('/groups', $token);
        $gCount = count($groups['body']['data'] ?? []);
        fprintf(STDERR, "  %s sees %d groups\n", $state['accounts'][$browserKey]['name'], $gCount);
    }
}

// ─── Report ─────────────────────────────────────────────────────────

function generateReport(ApiClient $api, array $state, float $totalTime): string
{
    $errors = $api->getErrors();
    $timings = $api->getTimings();
    $total = $api->getRequestCount();

    $avgMs = $total > 0 ? array_sum($timings) / $total : 0;
    $maxMs = $total > 0 ? max($timings) : 0;
    $p95idx = (int) floor(0.95 * count($timings));
    sort($timings);
    $p95Ms = $timings[$p95idx] ?? 0;

    $report = [];
    $report[] = '==========================================================';
    $report[] = '  CIRCLE AI Agent Test Report';
    $report[] = '  ' . date('Y-m-d H:i:s');
    $report[] = '==========================================================';
    $report[] = '';
    $report[] = sprintf('Total requests:    %d', $total);
    $report[] = sprintf('Total time:        %.1fs', $totalTime);
    $report[] = sprintf('Errors (4xx/5xx):  %d', count($errors));
    $report[] = sprintf('Avg response:      %.0fms', $avgMs);
    $report[] = sprintf('P95 response:      %.0fms', $p95Ms);
    $report[] = sprintf('Max response:      %.0fms', $maxMs);
    $report[] = '';
    $report[] = sprintf('Accounts created:  %d', count($state['accounts']));
    $report[] = sprintf('Groups created:    %d', count($state['groups']));
    $report[] = sprintf('Memories posted:   %d', count($state['memories']));
    $report[] = sprintf('Polls created:     %d', count($state['polls']));
    $report[] = sprintf('Events created:    %d', count($state['events']));
    $report[] = '';

    if (count($errors) > 0) {
        $report[] = '── ERRORS & ISSUES ──────────────────────────────────';
        $grouped = [];
        foreach ($errors as $e) {
            $key = $e['status'] . ' ' . ($e['error_code'] ?? $e['curl_error'] ?? 'unknown');
            $grouped[$key][] = $e;
        }
        foreach ($grouped as $key => $items) {
            $report[] = sprintf('  [%s] x%d', $key, count($items));
            // Show first 3 examples
            foreach (array_slice($items, 0, 3) as $item) {
                $report[] = sprintf('    %s %s (%.0fms)', $item['method'], $item['path'], $item['time_ms']);
            }
        }
        $report[] = '';
    }

    // Performance warnings
    $slow = array_filter($api->getLog(), fn($e) => $e['time_ms'] > 2000);
    if (!empty($slow)) {
        $report[] = '── SLOW REQUESTS (>2s) ─────────────────────────────';
        foreach (array_slice($slow, 0, 10) as $s) {
            $report[] = sprintf('  %s %s -> %d (%.0fms)', $s['method'], $s['path'], $s['status'], $s['time_ms']);
        }
        $report[] = '';
    }

    $report[] = '── SUMMARY ─────────────────────────────────────────';
    if (count($errors) === 0) {
        $report[] = '  All requests succeeded. No API errors detected.';
    } else {
        $report[] = sprintf('  %d errors found. Review the error details above.', count($errors));
        // Categorize
        $serverErrors = array_filter($errors, fn($e) => $e['status'] >= 500);
        $clientErrors = array_filter($errors, fn($e) => $e['status'] >= 400 && $e['status'] < 500);
        $connErrors = array_filter($errors, fn($e) => $e['status'] === 0);
        if (!empty($serverErrors)) {
            $report[] = sprintf('  SERVER BUGS (5xx): %d - These are real backend bugs!', count($serverErrors));
        }
        if (!empty($connErrors)) {
            $report[] = sprintf('  CONNECTION FAILURES: %d - Backend may be down or unreachable.', count($connErrors));
        }
        if (!empty($clientErrors)) {
            $report[] = sprintf('  CLIENT ERRORS (4xx): %d - May be expected (rate limits, auth) or contract issues.', count($clientErrors));
        }
    }
    $report[] = '';
    $report[] = '==========================================================';

    return implode("\n", $report);
}

// ─── Main ───────────────────────────────────────────────────────────

fprintf(STDERR, "\nCIRCLE AI Agent Test Harness\n");
fprintf(STDERR, "API: %s\n", $API_BASE);
fprintf(STDERR, "Phase: %s | Speed: %s\n\n", $PHASE, $SPEED);

// Health check
$api = new ApiClient($API_BASE, $VERBOSE);
$health = $api->get('/health');
if ($health['status'] !== 200) {
    fprintf(STDERR, "FATAL: API health check failed (%d). Is the backend running at %s?\n",
        $health['status'], $API_BASE);
    if ($health['status'] === 0) {
        fprintf(STDERR, "  curl error — check that the server is reachable.\n");
    }
    exit(1);
}
fprintf(STDERR, "Health check OK: %s\n", $health['body']['data']['status'] ?? 'unknown');

$startTime = microtime(true);
$state = loadState($STATE_FILE);

if ($PHASE === 'all' || $PHASE === 'setup') {
    $state = phaseSetup($api, $PERSONAS, $PASSWORD, $SPEED);
    saveState($STATE_FILE, $state);
    fprintf(STDERR, "\nSetup complete. State saved to %s\n", $STATE_FILE);
}

if ($PHASE === 'all' || $PHASE === 'simulate') {
    if (empty($state['accounts'])) {
        fprintf(STDERR, "No accounts in state. Run --phase=setup first.\n");
        exit(1);
    }
    phaseSimulate($api, $PERSONAS, $state, $SPEED);
    saveState($STATE_FILE, $state);
}

$totalTime = microtime(true) - $startTime;

// Generate report
$report = generateReport($api, $state, $totalTime);
echo $report . "\n";

// Save report
file_put_contents($LOG_FILE, $report . "\n\n" . json_encode($api->getErrors(), JSON_PRETTY_PRINT));
fprintf(STDERR, "\nReport saved to %s\n", $LOG_FILE);
fprintf(STDERR, "State saved to %s\n", $STATE_FILE);
fprintf(STDERR, "Done in %.1fs\n", $totalTime);
