<?php

declare(strict_types=1);

/**
 * CIRCLE API — shared hosting front controller.
 * This file goes in the subdomain document root (circle.cloudkart24.com/).
 * Unlike the development version, vendor/ and src/ are in the same directory.
 */

require_once __DIR__ . '/vendor/autoload.php';

use Circle\App;
use Circle\Core\Env;
use Circle\Core\Request;

date_default_timezone_set('UTC');

Env::load(__DIR__);

// Never display PHP errors to clients; App::handle logs them redacted.
ini_set('display_errors', '0');
error_reporting(E_ALL);

App::handle(Request::fromGlobals());
