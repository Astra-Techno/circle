<?php

declare(strict_types=1);

namespace Circle\Notifications;

final readonly class PushResult
{
    private function __construct(public string $status, public int $retryAfter = 0) {}

    public static function sent(): self { return new self('sent'); }
    public static function retry(int $after = 0): self { return new self('retry', max(0, min(604800, $after))); }
    public static function invalid(): self { return new self('invalid'); }
    public static function permanent(): self { return new self('permanent'); }
}
