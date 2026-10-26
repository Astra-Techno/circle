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
        $fcmToken = self::token($request);
        $platform = $request->input('platform');
        if (!is_string($platform) || !in_array($platform, ['android', 'ios'], true)) {
            Response::validationError('Choose a supported notification platform.');
        }
        $sessionId = (string) $request->attr('session_id');
        Database::transaction(static function () use ($userId, $fcmToken, $platform, $sessionId): void {
            // Serialize registration against session revocation, including a
            // request whose middleware ran immediately before logout.
            $session = Database::queryOne(
                'SELECT id FROM refresh_tokens WHERE user_id = :uid AND session_id = :sid
                 AND revoked_at IS NULL AND expires_at > NOW() FOR UPDATE',
                ['uid' => $userId, 'sid' => $sessionId]
            );
            if ($session === null) Response::unauthorized('Please log in again.', 'invalid_token');
            Database::execute(
                'INSERT INTO device_tokens (user_id, fcm_token, platform, session_id)
                 VALUES (:uid, :token, :platform, :sid)
                 ON DUPLICATE KEY UPDATE user_id = :new_uid, platform = :new_platform,
                 session_id = :new_sid, updated_at = NOW()',
                ['uid' => $userId, 'token' => $fcmToken, 'platform' => $platform, 'sid' => $sessionId,
                 'new_uid' => $userId, 'new_platform' => $platform, 'new_sid' => $sessionId]
            );
        });

        Response::ok(['registered' => true]);
    }

    /**
     * POST /api/v1/devices/unregister
     * Removes an FCM token (on logout).
     */
    public static function unregister(Request $request): void
    {
        $userId = $request->userId();
        $fcmToken = self::token($request);
        $sessionId = (string) $request->attr('session_id');

        $db = Database::connection();
        $stmt = $db->prepare(
            'DELETE FROM device_tokens WHERE user_id = :user_id AND fcm_token = :fcm_token AND session_id = :sid'
        );
        $stmt->execute(['user_id' => $userId, 'fcm_token' => $fcmToken, 'sid' => $sessionId]);

        Response::ok(['unregistered' => true]);
    }
    private static function token(Request $request): string
    {
        $token = $request->input('fcm_token');
        if (!is_string($token) || preg_match('/\A[A-Za-z0-9:_-]{1,512}\z/D', $token) !== 1) {
            Response::validationError('Use a valid notification device token.');
        }
        return $token;
    }
}
