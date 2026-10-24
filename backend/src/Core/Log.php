<?php

declare(strict_types=1);

namespace Circle\Core;

/**
 * Minimal redacting logger. Never log request bodies, passwords, tokens or
 * mobile numbers; exception messages are scrubbed because database errors can
 * echo user-supplied values (for example "Duplicate entry '+91...'").
 */
final class Log
{
    public static function exception(string $context, \Throwable $e): void
    {
        $code = $e instanceof \PDOException ? (string) ($e->errorInfo[1] ?? $e->getCode()) : (string) $e->getCode();
        error_log(sprintf(
            '[CIRCLE] %s: %s(%s) %s at %s:%d',
            $context,
            $e::class,
            $code,
            self::redact($e->getMessage()),
            basename($e->getFile()),
            $e->getLine()
        ));
    }

    public static function redact(string $message): string
    {
        // Quoted values (SQL error echoes) and long digit runs (phone numbers).
        $message = (string) preg_replace("/'[^']*'/", "'[redacted]'", $message);
        $message = (string) preg_replace('/\+?\d{6,}/', '[redacted]', $message);
        // Anything that looks like a bearer token / JWT.
        return (string) preg_replace('/[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}(\.[A-Za-z0-9_-]+)?/', '[redacted]', $message);
    }
}
