<?php

declare(strict_types=1);

namespace Circle\Media;

/** An upload was refused; carries the HTTP status and stable error code. */
final class MediaRejected extends \RuntimeException
{
    public function __construct(
        public readonly int $status,
        public readonly string $errorCode,
        string $message,
    ) {
        parent::__construct($message);
    }
}
