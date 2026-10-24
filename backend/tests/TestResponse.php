<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Core\ResponseSent;

final class TestResponse
{
    public function __construct(private readonly ResponseSent $sent)
    {
    }

    public function status(): int
    {
        return $this->sent->status;
    }

    /** @return array<string, mixed> */
    public function json(): array
    {
        return $this->sent->body ?? [];
    }

    public function data(): mixed
    {
        return $this->json()['data'] ?? null;
    }

    public function errorCode(): ?string
    {
        $error = $this->json()['error'] ?? null;
        return is_array($error) ? ($error['code'] ?? null) : null;
    }

    /** Binary body of a file response (null for JSON responses). */
    public function rawBody(): ?string
    {
        return $this->sent->rawBody;
    }

    public function header(string $name): ?string
    {
        return $this->sent->headers[$name] ?? null;
    }
}
