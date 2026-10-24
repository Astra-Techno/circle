<?php

declare(strict_types=1);

namespace Circle\Core;

/**
 * Thrown instead of exiting when Response capture mode is enabled (tests only).
 * Carries the full HTTP response so it can be asserted in-process.
 */
final class ResponseSent extends \RuntimeException
{
    /**
     * @param array<string, mixed>|null $body
     * @param array<string, string> $headers
     * @param string|null $rawBody binary body of a file response (null for JSON responses)
     */
    public function __construct(
        public readonly int $status,
        public readonly ?array $body,
        public readonly array $headers,
        public readonly ?string $rawBody = null,
    ) {
        parent::__construct('HTTP response sent with status ' . $status);
    }
}
