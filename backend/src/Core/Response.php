<?php

declare(strict_types=1);

namespace Circle\Core;

final class Response
{
    /** @param array<string, mixed> $data */
    public static function json(array $data, int $status = 200): never
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
        exit;
    }

    public static function ok(mixed $data = null, string $message = 'OK'): never
    {
        self::json(['success' => true, 'message' => $message, 'data' => $data]);
    }

    public static function created(mixed $data = null, string $message = 'Created'): never
    {
        self::json(['success' => true, 'message' => $message, 'data' => $data], 201);
    }

    public static function noContent(): never
    {
        http_response_code(204);
        exit;
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

    public static function unauthorized(string $message = 'Authentication required'): never
    {
        self::error('unauthorized', $message, 401);
    }

    public static function forbidden(string $message = 'Access denied'): never
    {
        self::error('forbidden', $message, 403);
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

    /** @param array<string, mixed> $page */
    public static function paginated(array $items, array $page): never
    {
        self::json([
            'success' => true,
            'data' => $items,
            'pagination' => $page,
        ]);
    }
}
