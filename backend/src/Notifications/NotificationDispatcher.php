<?php

declare(strict_types=1);

namespace Circle\Notifications;

use Circle\Core\FcmSender;

/**
 * Sends queued push notifications inline after the HTTP response,
 * removing the need for a cron job.
 *
 * Call scheduleFlush() whenever a notification is enqueued. A shutdown
 * function drains the outbox after exit — the client already has the
 * response, so there is no added latency.
 */
final class NotificationDispatcher
{
    private static bool $registered = false;

    /** Register a one-time shutdown flush. Safe to call many times per request. */
    public static function scheduleFlush(): void
    {
        if (self::$registered) {
            return;
        }
        self::$registered = true;
        register_shutdown_function([self::class, 'flush']);
    }

    /** Drain the notification outbox. Called automatically on shutdown. */
    public static function flush(): void
    {
        // Finish the response first if running under PHP-FPM.
        if (function_exists('fastcgi_finish_request')) {
            fastcgi_finish_request();
        }

        try {
            (new NotificationWorker(new FcmSender()))->run(50);
        } catch (\Throwable) {
            // Silent — same as the cron script's error handling.
            // No secrets, tokens or exception text.
        }
    }

    /** Reset for test isolation. */
    public static function reset(): void
    {
        self::$registered = false;
    }
}
