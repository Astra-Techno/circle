<?php

declare(strict_types=1);

namespace Circle\Core;

/** Diagnostics must start before Composer's platform check can terminate PHP. */
final class Diagnostics
{
    public static function enable(): void
    {
        error_reporting(E_ALL);
        ini_set('display_errors', '0');
        ini_set('display_startup_errors', '0');
        ini_set('log_errors', '1');

        register_shutdown_function(static function (): void {
            $error = error_get_last();
            if ($error === null || !in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR, E_USER_ERROR], true)) {
                return;
            }

            Log::record(['context' => 'fatal', 'type' => 'PHP fatal ' . $error['type'], 'message' => Log::redact($error['message']), 'file' => basename($error['file']), 'line' => $error['line']]);
            error_log(sprintf(
                '[CIRCLE] fatal: PHP=%s SAPI=%s type=%d %s at %s:%d',
                PHP_VERSION,
                PHP_SAPI,
                $error['type'],
                Log::redact($error['message']),
                basename($error['file']),
                $error['line']
            ));
        });
    }
}
