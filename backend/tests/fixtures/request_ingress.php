<?php

declare(strict_types=1);

// Local HTTP test router only. No database, authentication or production data.
require __DIR__ . '/../../vendor/autoload.php';

$request = \Circle\Core\Request::fromGlobals();
header('Content-Type: application/json');
echo json_encode([
    'body' => $request->all(),
    'object' => $request->jsonIsObject(),
    'raw' => $request->readRawBody(32),
], JSON_THROW_ON_ERROR);
