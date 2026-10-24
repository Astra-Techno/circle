<?php

declare(strict_types=1);

namespace Circle\Core;

final class Response
{
    /** When true, responses throw ResponseSent instead of writing and exiting (tests). */
    private static bool $capture = false;

    /** @var array<string, string> */
    private static array $headers = [];

    public static function enableCapture(): void
    {
        self::$capture = true;
    }

    /** Clears headers collected for the previous request. */
    public static function reset(): void
    {
        self::$headers = [];
    }

    public static function header(string $name, string $value): void
    {
        self::$headers[$name] = $value;
        if (!self::$capture && !headers_sent()) {
            header("{$name}: {$value}");
        }
    }

    /** @param array<string, mixed>|null $data */
    private static function send(int $status, ?array $data): never
    {
        if (self::$capture) {
            throw new ResponseSent($status, $data, self::$headers);
        }

        http_response_code($status);
        if ($data !== null) {
            header('Content-Type: application/json; charset=utf-8');
            echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
        }
        exit;
    }

    /** @param array<string, mixed> $data */
    public static function json(array $data, int $status = 200): never
    {
        self::send($status, $data);
    }

    public static function ok(mixed $data = null, string $message = 'OK'): never
    {
        self::json(['success' => true, 'message' => $message, 'data' => $data]);
    }

    public static function created(mixed $data = null, string $message = 'Created'): never
    {
        self::json(['success' => true, 'message' => $message, 'data' => $data], 201);
    }

    public static function accepted(mixed $data = null, string $message = 'Accepted'): never
    {
        self::json(['success' => true, 'message' => $message, 'data' => $data], 202);
    }

    public static function noContent(): never
    {
        self::send(204, null);
    }

    /** @param array<string, mixed> $details */
    public static function error(
        string $code,
        string $message,
        int $status = 400,
        array $details = []
    ): never {
        $body = [
            'success' => false,
            'error' => [
                'code' => $code,
                'message' => $message,
            ],
        ];
        if ($details !== []) {
            $body['error']['details'] = $details;
        }
        self::json($body, $status);
    }

    public static function notFound(string $message = 'Resource not found'): never
    {
        self::error('not_found', $message, 404);
    }

    public static function unauthorized(string $message = 'Authentication required', string $code = 'unauthorized'): never
    {
        self::error($code, $message, 401);
    }

    public static function forbidden(string $message = 'Access denied', string $code = 'forbidden'): never
    {
        self::error($code, $message, 403);
    }

    public static function validationError(string $message, string $code = 'validation_error'): never
    {
        self::error($code, $message, 422);
    }

    public static function tooMany(string $message = 'Too many requests'): never
    {
        self::error('rate_limited', $message, 429);
    }

    public static function serverError(string $message = 'Internal server error'): never
    {
        self::error('server_error', $message, 500);
    }

    /** Generic 503 (`server_error`) for a dependency that is not available; no details. */
    public static function unavailable(string $message = 'This is temporarily unavailable. Please try again later.'): never
    {
        self::error('server_error', $message, 503);
    }

    /**
     * Sends a file's bytes. With $offloadHeader (e.g. ['X-Accel-Redirect', '/protected/...'])
     * the web server sends the file and PHP sends no body. In capture mode (tests)
     * the bytes are attached to ResponseSent::$rawBody.
     *
     * @param array{0: string, 1: string}|null $offloadHeader
     */
    public static function file(string $path, string $contentType, ?array $offloadHeader = null): never
    {
        $size = filesize($path);
        if ($size === false) {
            throw new \RuntimeException('File is not readable.');
        }

        self::header('Content-Type', $contentType);
        self::header('Content-Length', (string) $size);

        if ($offloadHeader !== null) {
            self::header($offloadHeader[0], $offloadHeader[1]);
            if (self::$capture) {
                throw new ResponseSent(200, null, self::$headers, '');
            }
            http_response_code(200);
            exit;
        }

        if (self::$capture) {
            $bytes = file_get_contents($path);
            if ($bytes === false) {
                throw new \RuntimeException('File is not readable.');
            }
            throw new ResponseSent(200, null, self::$headers, $bytes);
        }

        http_response_code(200);
        while (ob_get_level() > 0) {
            ob_end_clean();
        }
        readfile($path);
        exit;
    }

    /**
     * @param array<int, mixed> $items
     * @param array<string, mixed> $page
     */
    public static function paginated(array $items, array $page): never
    {
        self::json([
            'success' => true,
            'data' => $items,
            'pagination' => $page,
        ]);
    }
}
