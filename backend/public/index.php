<?php

declare(strict_types=1);

require_once __DIR__ . '/../vendor/autoload.php';

use Circle\App;
use Circle\Core\Env;
use Circle\Core\Request;

date_default_timezone_set('UTC');

Env::load(__DIR__ . '/..');

// Never display PHP errors to clients; App::handle logs them redacted.
ini_set('display_errors', '0');

App::handle(Request::fromGlobals());
