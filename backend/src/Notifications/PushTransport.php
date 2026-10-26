<?php

declare(strict_types=1);

namespace Circle\Notifications;

interface PushTransport
{
    public function isReady(): bool;

    /** @param array<string, string> $data */
    public function send(string $token, array $data): PushResult;
}
