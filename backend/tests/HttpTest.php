<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Core\Log;
use Circle\Core\Migrator;

final class HttpTest extends ApiTestCase
{
    public function testHealth(): void
    {
        $r = $this->request('GET', '/api/v1/health');
        self::assertSame(200, $r->status());
        self::assertSame('healthy', $r->data()['status']);
    }

    public function testUnknownRouteAndNonNumericIds(): void
    {
        $user = $this->user();
        self::assertSame(404, $this->request('GET', '/api/v1/nope')->status());
        self::assertSame(404, $this->request('GET', '/api/v1/groups/abc', [], $user['token'])->status());
    }

    public function testCorsPreflightForAllowedOrigin(): void
    {
        $r = $this->request('OPTIONS', '/api/v1/groups', [], null, ['Origin' => 'https://allowed.example']);
        self::assertSame(204, $r->status());
        self::assertSame('https://allowed.example', $r->header('Access-Control-Allow-Origin'));
        self::assertSame('Origin', $r->header('Vary'));
        self::assertNotNull($r->header('Access-Control-Allow-Methods'));
        self::assertNull($r->header('Access-Control-Allow-Credentials'));
    }

    public function testCorsDisallowedOriginGetsNoAllowHeader(): void
    {
        $r = $this->request('OPTIONS', '/api/v1/groups', [], null, ['Origin' => 'https://evil.example']);
        self::assertSame(204, $r->status());
        self::assertNull($r->header('Access-Control-Allow-Origin'));
        self::assertSame('Origin', $r->header('Vary'));

        $get = $this->request('GET', '/api/v1/health', [], null, ['Origin' => 'https://allowed.example']);
        self::assertSame('https://allowed.example', $get->header('Access-Control-Allow-Origin'));
    }

    public function testErrorsAreGenericEnvelope(): void
    {
        $r = $this->request('GET', '/api/v1/me');
        self::assertSame(['success' => false, 'error' => ['code' => 'unauthorized', 'message' => 'Missing authorization token.']], $r->json());
    }

    public function testLogRedaction(): void
    {
        $msg = Log::redact("SQLSTATE[23000]: Integrity constraint violation: 1062 Duplicate entry '+919876543210' for key 'mobile'");
        self::assertStringNotContainsString('9876543210', $msg);
        self::assertStringNotContainsString('eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOjF9abcdefghijkl.sig', Log::redact('token eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOjF9abcdefghijkl.sig'));
    }

    public function testMigrationSplitter(): void
    {
        self::assertSame(['CREATE TABLE a (x INT)', 'ALTER TABLE a ADD y INT'], Migrator::split("-- c;\nCREATE TABLE a (x INT);\n\nALTER TABLE a ADD y INT;\n"));
    }
}
