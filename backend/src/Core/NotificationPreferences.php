<?php

declare(strict_types=1);

namespace Circle\Core;

/** Persistent opt-in policy shared by future feature delivery batches. */
final class NotificationPreferences
{
    public const CATEGORIES = ['memories', 'replies_reactions', 'groups', 'chats', 'events', 'polls', 'albums', 'security'];

    /** @return array<string, mixed> */
    public static function get(int $userId): array
    {
        $row = Database::queryOne('SELECT * FROM notification_preferences WHERE user_id = :uid', ['uid' => $userId]);
        $categories = array_fill_keys(self::CATEGORIES, false);
        if ($row !== null) {
            $stored = json_decode((string) $row['categories'], true);
            foreach (self::CATEGORIES as $category) $categories[$category] = is_array($stored) && ($stored[$category] ?? false) === true;
        }
        return [
            'enabled' => (bool) ($row['enabled'] ?? false), 'categories' => $categories,
            'quiet_hours' => (bool) ($row['quiet_hours'] ?? true),
            'quiet_start' => (int) ($row['quiet_start'] ?? 1320), 'quiet_end' => (int) ($row['quiet_end'] ?? 420),
            'timezone' => (string) ($row['timezone'] ?? 'UTC'),
        ];
    }

    /** Group-based delivery is always subject to current exact membership. */
    public static function allows(int $userId, string $category, ?int $groupId, \DateTimeImmutable $at): bool
    {
        if (!in_array($category, self::CATEGORIES, true)) return false;
        $user = Database::queryOne('SELECT status FROM users WHERE id = :uid', ['uid' => $userId]);
        if (($user['status'] ?? '') !== 'active') return false;
        if ($groupId === null && $category !== 'security') return false;
        if ($groupId !== null && Database::queryOne(
            "SELECT 1 FROM group_members WHERE user_id = :uid AND group_id = :gid AND status = 'active'",
            ['uid' => $userId, 'gid' => $groupId]
        ) === null) return false;
        $preferences = self::get($userId);
        if (!$preferences['enabled'] || !$preferences['categories'][$category]) return false;
        if (!$preferences['quiet_hours']) return true;
        $local = $at->setTimezone(new \DateTimeZone($preferences['timezone']));
        $minute = (int) $local->format('G') * 60 + (int) $local->format('i');
        $start = $preferences['quiet_start'];
        $end = $preferences['quiet_end'];
        $quiet = $start < $end ? $minute >= $start && $minute < $end : $minute >= $start || $minute < $end;
        return !$quiet;
    }
}
