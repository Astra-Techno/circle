<?php

declare(strict_types=1);

namespace Circle\Core;

/** Thrown when the server configuration is unsafe; the API refuses to serve requests. */
final class ConfigException extends \RuntimeException
{
}
