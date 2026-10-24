<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\App;
use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\ResponseSent;
use PHPUnit\Framework\TestCase;

/**
 * Dispatches requests through App::handle in-process against circle_test.
 * Every test starts from empty tables.
 */
abstract class ApiTestCase extends TestCase
{
    public const PASSWORD = 'correct horse battery staple';

    private static int $mobileSeq = 0;

    protected function setUp(): void
    {
        parent::setUp();
        $pdo = Database::connection();
        $pdo->exec('SET FOREIGN_KEY_CHECKS = 0');
        $tables = $pdo->query("SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'");
        foreach ($tables !== false ? $tables->fetchAll(\PDO::FETCH_COLUMN) : [] as $table) {
            if ($table !== 'migrations') {
                $pdo->exec('TRUNCATE TABLE `' . $table . '`');
            }
        }
        $pdo->exec('SET FOREIGN_KEY_CHECKS = 1');
    }

    /**
     * @param array<string, mixed> $body
     * @param array<string, string> $headers
     */
    protected function request(
        string $method,
        string $path,
        array $body = [],
        ?string $token = null,
        array $headers = [],
        string $ip = '127.0.0.1',
    ): TestResponse {
        $query = [];
        $parts = explode('?', $path, 2);
        if (isset($parts[1])) {
            parse_str($parts[1], $query);
        }
        if ($token !== null) {
            $headers['Authorization'] = 'Bearer ' . $token;
        }
        $headers['Content-Type'] = 'application/json';

        /** @var array<string, mixed> $query */
        $request = new Request($method, $path, $body, $query, $headers, $ip);
        try {
            App::handle($request);
        } catch (ResponseSent $sent) {
            return new TestResponse($sent);
        }
        self::fail("No response sent for {$method} {$path}");
    }

    /**
     * Sends a raw (binary) body, e.g. photo bytes for PUT /media/uploads/{id}/content.
     */
    protected function requestRaw(
        string $method,
        string $path,
        string $rawBody,
        ?string $token = null,
        string $contentType = 'application/octet-stream',
    ): TestResponse {
        $headers = ['Content-Type' => $contentType, 'Content-Length' => (string) strlen($rawBody)];
        if ($token !== null) {
            $headers['Authorization'] = 'Bearer ' . $token;
        }
        $request = new Request($method, $path, [], [], $headers, '127.0.0.1', $rawBody);
        try {
            App::handle($request);
        } catch (ResponseSent $sent) {
            return new TestResponse($sent);
        }
        self::fail("No response sent for {$method} {$path}");
    }

    protected function nextMobile(): string
    {
        self::$mobileSeq++;
        return sprintf('+9198%08d', self::$mobileSeq);
    }

    /** @return array{id: int, token: string, refresh: string, mobile: string} */
    protected function user(string $name = 'Test Person'): array
    {
        $mobile = $this->nextMobile();
        $r = $this->request('POST', '/api/v1/auth/register', [
            'mobile' => $mobile, 'password' => self::PASSWORD, 'display_name' => $name,
        ]);
        self::assertSame(202, $r->status(), json_encode($r->json()) ?: '');

        $login = $this->request('POST', '/api/v1/auth/login', ['mobile' => $mobile, 'password' => self::PASSWORD]);
        self::assertSame(200, $login->status(), json_encode($login->json()) ?: '');
        $data = $login->data();
        self::assertIsArray($data);

        return [
            'id' => (int) $data['user']['id'],
            'token' => (string) $data['access_token'],
            'refresh' => (string) $data['refresh_token'],
            'mobile' => $mobile,
        ];
    }

    /**
     * @param array{token: string} $user
     * @param array<string, mixed> $extra
     */
    protected function createGroup(array $user, string $name = 'Group', ?int $parentId = null, array $extra = []): int
    {
        $body = ['name' => $name, 'type' => 'friends', ...$extra];
        if ($parentId !== null) {
            $body['parent_id'] = $parentId;
        }
        $r = $this->request('POST', '/api/v1/groups', $body, $user['token']);
        self::assertSame(201, $r->status(), json_encode($r->json()) ?: '');
        $data = $r->data();
        self::assertIsArray($data);
        return (int) $data['id'];
    }

    /**
     * @param array{token: string} $creator
     * @param array<string, mixed> $body
     */
    protected function inviteToken(array $creator, int $groupId, array $body = []): string
    {
        $r = $this->request('POST', "/api/v1/groups/{$groupId}/invite-links", $body, $creator['token']);
        self::assertSame(201, $r->status(), json_encode($r->json()) ?: '');
        $data = $r->data();
        self::assertIsArray($data);
        return (string) $data['token'];
    }

    /**
     * Adds $user to $groupId via a fresh link created by $admin (auto approval).
     * @param array{token: string} $admin
     * @param array{token: string} $user
     */
    protected function join(array $admin, array $user, int $groupId): void
    {
        $token = $this->inviteToken($admin, $groupId);
        $r = $this->request('POST', "/api/v1/invites/{$token}/join", [], $user['token']);
        self::assertSame(200, $r->status(), json_encode($r->json()) ?: '');
        self::assertSame('joined', $r->data()['status'] ?? null);
    }

    /** @param array{token: string} $user */
    protected function createMemory(array $user, int $groupId, string $body = 'A shared moment'): int
    {
        $r = $this->request('POST', "/api/v1/groups/{$groupId}/memories", ['body' => $body], $user['token']);
        self::assertSame(201, $r->status(), json_encode($r->json()) ?: '');
        $data = $r->data();
        self::assertIsArray($data);
        return (int) $data['id'];
    }
}
