<?php

declare(strict_types=1);

namespace Circle\Core;

final class Request
{
    public readonly string $method;
    public readonly string $path;
    public readonly string $contentType;

    /** @var array<string, mixed> */
    public readonly array $query;

    /** @var array<string, mixed> */
    private array $body;

    /** @var array<string, string> lower-cased header names */
    private array $headers;

    private string $ip;

    /** @var array<string, string> */
    private array $params = [];

    /** @var array<string, mixed> */
    private array $attributes = [];

    /** Raw request body when given directly (tests); otherwise read lazily from php://input. */
    private ?string $rawBody;

    /**
     * @param array<string, mixed> $body
     * @param array<string, mixed> $query
     * @param array<string, string> $headers
     */
    public function __construct(
        string $method = 'GET',
        string $path = '/',
        array $body = [],
        array $query = [],
        array $headers = [],
        string $ip = '0.0.0.0',
        ?string $rawBody = null,
    ) {
        $this->method = strtoupper($method);
        $this->path = self::normalisePath($path);
        $this->body = $body;
        $this->query = $query;
        $this->headers = array_change_key_case($headers, CASE_LOWER);
        $this->contentType = $this->headers['content-type'] ?? '';
        $this->ip = $ip;
        $this->rawBody = $rawBody;
    }

    public static function fromGlobals(): self
    {
        $method = strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? 'GET'));
        $contentType = (string) ($_SERVER['CONTENT_TYPE'] ?? '');

        $headers = ['content-type' => $contentType];
        if (is_string($_SERVER['CONTENT_LENGTH'] ?? null)) {
            $headers['content-length'] = $_SERVER['CONTENT_LENGTH'];
        }
        foreach ($_SERVER as $key => $value) {
            if (is_string($key) && is_string($value) && str_starts_with($key, 'HTTP_')) {
                $headers[strtolower(str_replace('_', '-', substr($key, 5)))] = $value;
            }
        }
        // Apache/CGI may move Authorization to REDIRECT_HTTP_AUTHORIZATION (see .htaccess).
        if (!isset($headers['authorization']) && is_string($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? null)) {
            $headers['authorization'] = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
        }

        $body = [];
        if ($method !== 'GET' && $method !== 'HEAD') {
            // Every implemented PUT is a raw image upload. Do not eagerly buffer
            // a MIME-mismatched JSON body before the controller's bounded reader.
            if ($method !== 'PUT' && str_contains($contentType, 'application/json')) {
                $raw = file_get_contents('php://input');
                if ($raw !== false && $raw !== '') {
                    $decoded = json_decode($raw, true);
                    $body = is_array($decoded) ? $decoded : [];
                }
            } else {
                $body = $_POST;
            }
        }

        return new self(
            $method,
            (string) ($_SERVER['REQUEST_URI'] ?? '/'),
            $body,
            $_GET,
            $headers,
            (string) ($_SERVER['REMOTE_ADDR'] ?? '0.0.0.0'),
        );
    }

    private static function normalisePath(string $uri): string
    {
        $path = parse_url($uri, PHP_URL_PATH);
        if (!is_string($path)) {
            return '/';
        }
        return rtrim($path, '/') ?: '/';
    }

    public function input(string $key, mixed $default = null): mixed
    {
        return $this->body[$key] ?? $default;
    }

    public function has(string $key): bool
    {
        return array_key_exists($key, $this->body);
    }

    /** Trimmed string input. Never use for passwords. */
    public function string(string $key, string $default = ''): string
    {
        $val = $this->input($key, $default);
        return is_string($val) ? trim($val) : $default;
    }

    /** Exact string input, byte for byte (passwords, tokens). */
    public function raw(string $key): string
    {
        $val = $this->input($key);
        return is_string($val) ? $val : '';
    }

    public function int(string $key, int $default = 0): int
    {
        $val = $this->input($key, $default);
        return is_numeric($val) ? (int) $val : $default;
    }

    public function bool(string $key, bool $default = false): bool
    {
        $val = $this->input($key);
        if ($val === null) {
            return $default;
        }
        return filter_var($val, FILTER_VALIDATE_BOOLEAN);
    }

    /** @return array<string, mixed> */
    public function all(): array
    {
        return $this->body;
    }

    public function query(string $key, string $default = ''): string
    {
        $val = $this->query[$key] ?? $default;
        return is_string($val) ? $val : $default;
    }

    /** Integer query parameter clamped to [$min, $max]. */
    public function queryInt(string $key, int $default, int $min, int $max): int
    {
        $raw = $this->query($key);
        $val = preg_match('/^-?\d{1,9}$/', $raw) === 1 ? (int) $raw : $default;
        return max($min, min($max, $val));
    }

    public function header(string $name): string
    {
        return $this->headers[strtolower($name)] ?? '';
    }

    public function param(string $key, string $default = ''): string
    {
        return $this->params[$key] ?? $default;
    }

    /** @param array<string, string> $params */
    public function withParams(array $params): self
    {
        $clone = clone $this;
        $clone->params = $params;
        return $clone;
    }

    public function attr(string $key, mixed $default = null): mixed
    {
        return $this->attributes[$key] ?? $default;
    }

    public function withAttr(string $key, mixed $value): self
    {
        $clone = clone $this;
        $clone->attributes[$key] = $value;
        return $clone;
    }

    public function userId(): int
    {
        $id = $this->attr('user_id');
        return is_int($id) ? $id : 0;
    }

    public function bearerToken(): ?string
    {
        $header = $this->header('authorization');
        if (preg_match('/^Bearer\s+(\S+)$/', $header, $m) === 1) {
            return $m[1];
        }
        return null;
    }

    public function ip(): string
    {
        return $this->ip;
    }

    /**
     * Raw request body (binary uploads), reading at most $maxBytes + 1 bytes so
     * an oversized body is never fully buffered. Returns null when the body is
     * larger than $maxBytes.
     */
    public function readRawBody(int $maxBytes): ?string
    {
        if ($this->rawBody !== null) {
            return strlen($this->rawBody) > $maxBytes ? null : $this->rawBody;
        }

        $length = $this->header('content-length');
        if ($length !== '' && ctype_digit($length) && (int) $length > $maxBytes) {
            return null;
        }

        $in = fopen('php://input', 'rb');
        if ($in === false) {
            return '';
        }
        try {
            $data = stream_get_contents($in, $maxBytes + 1);
        } finally {
            fclose($in);
        }
        if ($data === false) {
            return '';
        }
        return strlen($data) > $maxBytes ? null : $data;
    }
}
