<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;

/**
 * Manages FCM device tokens for push notifications.
 */
final class DeviceController
{
    /**
     * POST /api/v1/devices/register
     * Registers or updates an FCM token for the authenticated user.
     */
    public static function register(Request $request): void
    {
        $userId = $request->userId();
        $fcmToken = $request->string('fcm_token');
        $platform = $request->string('platform') ?: 'android';

        if ($fcmToken === '') {
            Response::validationError('fcm_token is required.');
        }

        $db = Database::connection();

        // Upsert: if this token exists (maybe for another user), reassign it.
        $stmt = $db->prepare(
            'INSERT INTO device_tokens (user_id, fcm_token, platform)
             VALUES (:user_id, :fcm_token, :platform)
             ON DUPLICATE KEY UPDATE user_id = :user_id2, platform = :platform2, updated_at = NOW()'
        );
        $stmt->execute([
            'user_id'   => $userId,
            'fcm_token' => $fcmToken,
            'platform'  => $platform,
            'user_id2'  => $userId,
            'platform2' => $platform,
        ]);

        Response::ok(['registered' => true]);
    }

    /**
     * POST /api/v1/devices/unregister
     * Removes an FCM token (on logout).
     */
    public static function unregister(Request $request): void
    {
        $userId = $request->userId();
        $fcmToken = $request->string('fcm_token');

        if ($fcmToken === '') {
            Response::validationError('fcm_token is required.');
        }

        $db = Database::connection();
        $stmt = $db->prepare(
            'DELETE FROM device_tokens WHERE user_id = :user_id AND fcm_token = :fcm_token'
        );
        $stmt->execute(['user_id' => $userId, 'fcm_token' => $fcmToken]);

        Response::ok(['unregistered' => true]);
    }
}
