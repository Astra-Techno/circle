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
        $message = sprintf(
            '[CIRCLE] %s: %s(%s) %s at %s:%d',
            $context,
            $e::class,
            $code,
            self::redact($e->getMessage()),
            basename($e->getFile()),
            $e->getLine()
        );
        error_log($message);
        self::record(['context' => $context, 'type' => $e::class, 'code' => $code, 'message' => self::redact($e->getMessage()), 'file' => basename($e->getFile()), 'line' => $e->getLine()]);
    }

    /** @param array<string, mixed> $details */
    public static function record(array $details): void
    {
        $directory = dirname(__DIR__, 2) . '/storage/diagnostics';
        if (!is_dir($directory) && !@mkdir($directory, 0700, true) && !is_dir($directory)) return;
        $json = json_encode(['recorded_at' => gmdate('c'), ...$details], JSON_INVALID_UTF8_SUBSTITUTE);
        if ($json === false) return;
        $temporary = @tempnam($directory, 'error-');
        if ($temporary === false) return;
        @chmod($temporary, 0600);
        // PHP guard also prevents accidental HTTP disclosure if routing is misconfigured.
        if (@file_put_contents($temporary, "<?php exit; ?>\n" . $json) !== false) {
            @rename($temporary, $directory . '/latest-error.php');
        }
        if (is_file($temporary)) @unlink($temporary);
    }

    /** @return array<string, mixed>|null */
    public static function latest(): ?array
    {
        $path = dirname(__DIR__, 2) . '/storage/diagnostics/latest-error.php';
        $content = @file_get_contents($path);
        if ($content === false) return null;
        $details = json_decode(substr($content, strlen("<?php exit; ?>\n")), true);
        return is_array($details) ? $details : null;
    }

    public static function redact(string $message): string
    {
        foreach (['DB_PASSWORD', 'JWT_SECRET', 'MEDIA_SIGNING_SECRET', 'DEPLOY_KEY', 'GITHUB_TOKEN', 'DIAGNOSTICS_TOKEN'] as $name) {
            $secret = class_exists(Env::class) ? Env::get($name) : '';
            if ($secret !== '') $message = str_replace($secret, '[redacted]', $message);
        }
        // Quoted values (SQL error echoes) and long digit runs (phone numbers).
        $message = (string) preg_replace("/'[^']*'/", "'[redacted]'", $message);
        $message = (string) preg_replace('/\+?\d{6,}/', '[redacted]', $message);
        // Anything that looks like a bearer token / JWT.
        return (string) preg_replace('/[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}(\.[A-Za-z0-9_-]+)?/', '[redacted]', $message);
    }
}
