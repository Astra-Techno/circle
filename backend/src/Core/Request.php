<?php

declare(strict_types=1);

namespace Circle\Core;

final class Request
{
    public readonly string $method;
    public readonly string $path;
    public readonly string $contentType;

    /** @var array<string, string> */
    public readonly array $query;

    /** @var array<string, mixed> */
    private array $body;

    /** @var array<string, string> */
    private array $params = [];

    /** @var array<string, mixed> */
    private array $attributes = [];

    public function __construct()
    {
        $this->method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
        $this->path = $this->parsePath();
        $this->contentType = $_SERVER['CONTENT_TYPE'] ?? '';
        $this->query = $_GET;
        $this->body = $this->parseBody();
    }

    private function parsePath(): string
    {
        $uri = $_SERVER['REQUEST_URI'] ?? '/';
        $path = parse_url($uri, PHP_URL_PATH);
        return $path !== null && $path !== false ? rtrim($path, '/') ?: '/' : '/';
    }

    /** @return array<string, mixed> */
    private function parseBody(): array
    {
        if ($this->method === 'GET' || $this->method === 'HEAD') {
            return [];
        }

        if (str_contains($this->contentType, 'application/json')) {
            $raw = file_get_contents('php://input');
            if ($raw !== false && $raw !== '') {
                $decoded = json_decode($raw, true);
                return is_array($decoded) ? $decoded : [];
            }
        }

        return $_POST;
    }

    public function input(string $key, mixed $default = null): mixed
    {
        return $this->body[$key] ?? $default;
    }

    public function string(string $key, string $default = ''): string
    {
        $val = $this->input($key, $default);
        return is_string($val) ? trim($val) : $default;
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
        return $this->query[$key] ?? $default;
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

    public function bearerToken(): ?string
    {
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        if (str_starts_with($header, 'Bearer ')) {
            return substr($header, 7);
        }
        return null;
    }

    public function ip(): string
    {
        return $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
    }
}
