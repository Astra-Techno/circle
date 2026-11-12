<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Core\Validator;
use Circle\Repositories\MemberRepository;

final class CapsuleController
{
    private const MAX_ENTRIES = 100;
    private const MAX_CONTRIBUTORS = 50;

    /** List capsules in a group. */
    public static function index(Request $r): void
    {
        Response::header('Cache-Control', 'private, no-store');
        $groupId = (int) $r->param('id');
        $userId = $r->userId();
        MemberRepository::requireActiveMember($groupId, $userId);

        $limit = $r->queryInt('limit', 30, 1, 100);
        $offset = $r->queryInt('offset', 0, 0, 1000000);

        $rows = Database::query(
            'SELECT c.*, u.display_name AS creator_name,
                (SELECT COUNT(*) FROM capsule_entries WHERE capsule_id = c.id) AS entry_count
             FROM capsules c
             JOIN users u ON u.id = c.creator_id
             WHERE c.group_id = :g
             ORDER BY c.created_at DESC, c.id DESC
             LIMIT :lim OFFSET :off',
            ['g' => $groupId, 'lim' => $limit + 1, 'off' => $offset]
        );
        $more = count($rows) > $limit;
        if ($more) array_pop($rows);

        $now = gmdate('Y-m-d H:i:s');
        $items = array_map(fn(array $row) => self::format($row, $now), $rows);

        Response::ok(['items' => $items, 'has_more' => $more]);
    }

    /** Get capsule detail. */
    public static function show(Request $r): void
    {
        Response::header('Cache-Control', 'private, no-store');
        $capsule = self::access($r);
        $now = gmdate('Y-m-d H:i:s');
        $detail = self::format($capsule, $now);

        // Contributors list
        $detail['contributors'] = Database::query(
            'SELECT ce.author_id, u.display_name,
                    SUM(CASE WHEN ce.body != \'\' THEN 1 ELSE 0 END) AS message_count
             FROM capsule_entries ce
             JOIN users u ON u.id = ce.author_id
             WHERE ce.capsule_id = :id
             GROUP BY ce.author_id, u.display_name
             ORDER BY MIN(ce.added_at)',
            ['id' => $capsule['id']]
        );

        Response::ok($detail);
    }

    /** Create a capsule in a group. */
    public static function create(Request $r): void
    {
        Response::header('Cache-Control', 'private, no-store');
        $groupId = (int) $r->param('id');
        $userId = $r->userId();
        MemberRepository::requireActiveMember($groupId, $userId);

        $title = trim($r->string('title'));
        $message = trim($r->string('message', ''));
        $unlockDays = $r->input('unlock_days');

        $v = new Validator();
        $v->required('title', $title)->string('title', $title, 1, 60);
        if ($message !== '') $v->string('message', $message, 0, 500);

        $v->bail();

        $absolute = $r->input('unlock_at');
        if ($absolute !== null) {
            if ($unlockDays !== null || !is_string($absolute) || !preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$/D', $absolute)) {
                Response::validationError('Choose one valid UTC unlock date.');
            }
            try { $date = new \DateTimeImmutable($absolute); }
            catch (\Exception) { Response::validationError('Choose a valid unlock date.'); }
            $errors = \DateTimeImmutable::getLastErrors();
            if ($errors !== false && ($errors['warning_count'] > 0 || $errors['error_count'] > 0)) Response::validationError('Choose a valid calendar date.');
            $now = new \DateTimeImmutable('now', new \DateTimeZone('UTC'));
            if ($date < $now->modify('+1 day') || $date > $now->modify('+3650 days')) {
                Response::validationError('Choose an unlock date between 1 and 3650 days ahead.');
            }
            $unlockAt = $date->format('Y-m-d H:i:s');
        } else {
        if (!is_int($unlockDays) && !(is_string($unlockDays) && ctype_digit($unlockDays))) {
            Response::validationError('unlock_days must be an integer (1-3650).');
        }
        $unlockDays = (int) $unlockDays;
        if ($unlockDays < 1 || $unlockDays > 3650) {
            Response::validationError('unlock_days must be between 1 and 3650).');
        }

        $unlockAt = (new \DateTimeImmutable('+' . $unlockDays . ' days', new \DateTimeZone('UTC')))
            ->format('Y-m-d H:i:s');
        }

        $id = Database::transaction(static function () use ($groupId, $userId, $title, $message, $unlockAt): int {
            Database::execute(
                'INSERT INTO capsules (group_id, creator_id, title, message, unlock_at)
                 VALUES (:g, :u, :t, :m, :unlock)',
                ['g' => $groupId, 'u' => $userId, 't' => $title, 'm' => $message, 'unlock' => $unlockAt]
            );
            return Database::lastInsertId();
        });

        Response::created(['id' => $id, 'group_id' => $groupId], 'Capsule created.');
    }

    /** Add an entry (contribution) to an open capsule. */
    public static function addEntry(Request $r): void
    {
        Response::header('Cache-Control', 'private, no-store');
        $entryId = Database::transaction(static function () use ($r): int {
        $capsule = self::access($r, true);
        $userId = $r->userId();
        $now = gmdate('Y-m-d H:i:s');

        if ($capsule['sealed_at'] !== null) {
            Response::error('capsule_sealed', 'This capsule is sealed and no longer accepting contributions.', 422);
        }
        if ($capsule['unlock_at'] <= $now) {
            Response::error('capsule_unlocked', 'This capsule has already been unlocked.', 422);
        }

        // Check entry limit
        $entryCount = (int) Database::queryOne(
            'SELECT COUNT(*) AS n FROM capsule_entries WHERE capsule_id = :id',
            ['id' => $capsule['id']]
        )['n'];
        if ($entryCount >= self::MAX_ENTRIES) {
            Response::error('capsule_full', 'This capsule has reached its maximum of ' . self::MAX_ENTRIES . ' entries.', 422);
        }

        // Check contributor limit
        $contributorCount = (int) Database::queryOne(
            'SELECT COUNT(DISTINCT author_id) AS n FROM capsule_entries WHERE capsule_id = :id',
            ['id' => $capsule['id']]
        )['n'];
        $isNewContributor = Database::queryOne(
            'SELECT 1 FROM capsule_entries WHERE capsule_id = :id AND author_id = :u LIMIT 1',
            ['id' => $capsule['id'], 'u' => $userId]
        ) === null;
        if ($isNewContributor && $contributorCount >= self::MAX_CONTRIBUTORS) {
            Response::error('capsule_contributors_full', 'This capsule has reached its maximum of ' . self::MAX_CONTRIBUTORS . ' contributors.', 422);
        }

        $body = trim($r->string('body', ''));
        $v = new Validator();
        $v->required('body', $body)->string('body', $body, 1, 500);
        $v->bail();

            Database::execute(
                'INSERT INTO capsule_entries (capsule_id, author_id, body) VALUES (:c, :u, :b)',
                ['c' => $capsule['id'], 'u' => $userId, 'b' => $body]
            );
            return Database::lastInsertId();
        });

        $entry = Database::queryOne(
            'SELECT e.id, e.author_id, u.display_name AS author_name, e.body, e.added_at
             FROM capsule_entries e JOIN users u ON u.id = e.author_id WHERE e.id = :id',
            ['id' => $entryId]
        );

        Response::created($entry, 'Entry added.');
    }

    /** List entries (only if capsule is unlocked). */
    public static function entries(Request $r): void
    {
        Response::header('Cache-Control', 'private, no-store');
        $capsule = self::access($r);
        $now = gmdate('Y-m-d H:i:s');

        if ($capsule['unlock_at'] > $now) {
            Response::error('capsule_locked', 'This capsule has not been unlocked yet.', 403);
        }

        $limit = $r->queryInt('limit', 50, 1, 100);
        $offset = $r->queryInt('offset', 0, 0, 1000000);

        $rows = Database::query(
            'SELECT e.id, e.author_id, u.display_name AS author_name, e.body, e.added_at
             FROM capsule_entries e
             JOIN users u ON u.id = e.author_id
             WHERE e.capsule_id = :id
             ORDER BY e.added_at
             LIMIT :lim OFFSET :off',
            ['id' => $capsule['id'], 'lim' => $limit + 1, 'off' => $offset]
        );
        $more = count($rows) > $limit;
        if ($more) array_pop($rows);

        Response::ok(['items' => $rows, 'has_more' => $more]);
    }

    /** Seal capsule (creator only). */
    public static function seal(Request $r): void
    {
        Response::header('Cache-Control', 'private, no-store');
        $capsule = self::access($r);
        $userId = $r->userId();

        if ((int) $capsule['creator_id'] !== $userId) {
            Response::error('not_creator', 'Only the capsule creator can seal it.', 403);
        }
        if ($capsule['sealed_at'] !== null) {
            Response::error('already_sealed', 'This capsule is already sealed.', 422);
        }

        $now = gmdate('Y-m-d H:i:s');
        if ($capsule['unlock_at'] <= $now) {
            Response::error('capsule_unlocked', 'This capsule has already been unlocked.', 422);
        }

        Database::execute('UPDATE capsules SET sealed_at = UTC_TIMESTAMP() WHERE id = :id AND sealed_at IS NULL AND unlock_at>UTC_TIMESTAMP()', ['id' => $capsule['id']]);

        Response::ok(null, 'Capsule sealed.');
    }

    /** Delete capsule (creator only). */
    public static function delete(Request $r): void
    {
        Response::header('Cache-Control', 'private, no-store');
        $capsule = self::access($r);
        $userId = $r->userId();

        if ((int) $capsule['creator_id'] !== $userId) {
            Response::error('not_creator', 'Only the capsule creator can delete it.', 403);
        }

        Database::execute('DELETE FROM capsules WHERE id = :id', ['id' => $capsule['id']]);

        Response::ok(null, 'Capsule deleted.');
    }

    // ── Helpers ─────────────────────────────────────────────────

    /** @return array<string, mixed> */
    private static function access(Request $r, bool $lock = false): array
    {
        $capsuleId = (int) $r->param('capsuleId');
        $capsule = Database::queryOne('SELECT c.*, (SELECT COUNT(*) FROM capsule_entries ce WHERE ce.capsule_id=c.id) AS entry_count FROM capsules c WHERE c.id = :id' . ($lock ? ' FOR UPDATE' : ''), ['id' => $capsuleId]);
        if ($capsule === null) Response::notFound('Capsule not found.');
        MemberRepository::requireActiveMember((int) $capsule['group_id'], $r->userId());
        return $capsule;
    }

    /**
     * @param array<string, mixed> $row
     * @return array<string, mixed>
     */
    private static function format(array $row, string $now): array
    {
        $sealed = $row['sealed_at'] !== null;
        $unlocked = $row['unlock_at'] <= $now;
        return [
            'id'           => (int) $row['id'],
            'group_id'     => (int) $row['group_id'],
            'creator_id'   => (int) $row['creator_id'],
            'creator_name' => $row['creator_name'] ?? null,
            'title'        => $row['title'],
            'message'      => $sealed && !$unlocked ? '' : $row['message'],
            'unlock_at'    => $row['unlock_at'],
            'sealed_at'    => $row['sealed_at'],
            'created_at'   => $row['created_at'],
            'is_sealed'    => $sealed,
            'is_unlocked'  => $unlocked,
            'is_open'      => !$sealed && !$unlocked,
            'entry_count'  => (int) ($row['entry_count'] ?? 0),
        ];
    }
}
