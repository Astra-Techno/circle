<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\NotificationPreferences;
use Circle\Core\Request;
use Circle\Core\Response;

final class NotificationPreferenceController
{
    public static function show(Request $request): void
    {
        Response::header('Cache-Control', 'private, no-store');
        Response::ok(NotificationPreferences::get($request->userId()));
    }

    public static function update(Request $request): void
    {
        if (strtolower(trim(explode(';', $request->contentType)[0])) !== 'application/json') Response::validationError('Send notification preferences as JSON.');
        if (!$request->jsonIsObject()) Response::validationError('Send a JSON object for notification preferences.');
        $fields = $request->all();
        $allowed = ['enabled', 'categories', 'quiet_hours', 'quiet_start', 'quiet_end', 'timezone'];
        if (array_diff(array_keys($fields), $allowed) !== []) Response::validationError('Unknown notification preference.');
        foreach (['enabled', 'quiet_hours'] as $field) {
            if ($request->has($field) && !is_bool($fields[$field])) Response::validationError('Use true or false for notification switches.');
        }
        foreach (['quiet_start', 'quiet_end'] as $field) {
            if ($request->has($field) && (!is_int($fields[$field]) || $fields[$field] < 0 || $fields[$field] > 1439)) Response::validationError('Use a minute between 0 and 1439.');
        }
        if ($request->has('timezone') && (!is_string($fields['timezone']) || !in_array($fields['timezone'], \DateTimeZone::listIdentifiers(\DateTimeZone::ALL_WITH_BC), true))) Response::validationError('Choose a valid time zone.');
        if ($request->has('categories')) {
            if (!$request->jsonFieldIsObject('categories') || !is_array($fields['categories']) || array_diff(array_keys($fields['categories']), NotificationPreferences::CATEGORIES) !== []) Response::validationError('Choose valid notification categories.');
            foreach ($fields['categories'] as $value) {
                if (!is_bool($value)) Response::validationError('Use true or false for notification categories.');
            }
        }
        $userId = $request->userId();
        $result = Database::transaction(static function () use ($userId, $fields): array {
            $defaults = NotificationPreferences::defaults();
            Database::execute('INSERT IGNORE INTO notification_preferences
                (user_id, enabled, categories, quiet_hours, quiet_start, quiet_end, timezone)
                VALUES (:uid, :enabled, :categories, :quiet, :start, :end, :timezone)',
                ['uid' => $userId, 'enabled' => $defaults['enabled'],
                 'categories' => json_encode($defaults['categories'], JSON_THROW_ON_ERROR),
                 'quiet' => $defaults['quiet_hours'], 'start' => $defaults['quiet_start'],
                 'end' => $defaults['quiet_end'], 'timezone' => $defaults['timezone']]);
            Database::queryOne('SELECT user_id FROM notification_preferences WHERE user_id = :uid FOR UPDATE', ['uid' => $userId]);
            $current = NotificationPreferences::get($userId);
            foreach ($fields as $key => $value) {
                $current[$key] = $key === 'categories' ? array_replace($current['categories'], $value) : $value;
            }
            if ($current['quiet_start'] === $current['quiet_end']) Response::validationError('Choose different quiet-hours start and end times.');
            Database::execute('UPDATE notification_preferences SET enabled = :enabled, categories = :categories,
                quiet_hours = :quiet, quiet_start = :start, quiet_end = :end, timezone = :tz WHERE user_id = :uid',
                ['enabled' => $current['enabled'], 'categories' => json_encode($current['categories'], JSON_THROW_ON_ERROR),
                 'quiet' => $current['quiet_hours'], 'start' => $current['quiet_start'], 'end' => $current['quiet_end'],
                 'tz' => $current['timezone'], 'uid' => $userId]);
            return $current;
        });
        Response::header('Cache-Control', 'private, no-store');
        Response::ok($result);
    }
}
