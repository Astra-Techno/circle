<?php

declare(strict_types=1);

namespace Circle\Tests;

use PHPUnit\Framework\TestCase;

/** Exercises php://input through a real HTTP request, unlike injected API bodies. */
final class RequestIngressTest extends TestCase
{
    /** @var resource|null */
    private static $server = null;
    private static string $address;

    public static function setUpBeforeClass(): void
    {
        $socket = stream_socket_server('tcp://127.0.0.1:0');
        self::assertIsResource($socket);
        $address = stream_socket_get_name($socket, false);
        self::assertIsString($address);
        fclose($socket);
        self::$address = $address;
        self::$server = proc_open(
            [PHP_BINARY, '-d', 'extension_dir=' . ini_get('extension_dir'), '-S', $address, __DIR__ . '/fixtures/request_ingress.php'],
            [0 => ['file', '/dev/null', 'r'], 1 => ['file', __DIR__ . '/../.phpunit.cache/ingress-server.log', 'a'], 2 => ['file', __DIR__ . '/../.phpunit.cache/ingress-server.log', 'a']],
            $pipes,
        );
        self::assertIsResource(self::$server);
        for ($attempt = 0; $attempt < 100; $attempt++) {
            $connection = @stream_socket_client('tcp://' . $address, timeout: 0.05);
            if (is_resource($connection)) {
                fclose($connection);
                return;
            }
            usleep(10000);
        }
        self::fail('Local ingress server did not start.');
    }

    public static function tearDownAfterClass(): void
    {
        if (is_resource(self::$server)) {
            proc_terminate(self::$server);
            proc_close(self::$server);
        }
    }

    /** @return array<string,mixed> */
    private function ingress(string $method, string $path, string $body, string $type = 'application/json'): array
    {
        $context = stream_context_create(['http' => [
            'method' => $method,
            'header' => "Content-Type: $type\r\nConnection: close\r\n",
            'content' => $body,
            'timeout' => 5,
        ]]);
        $raw = file_get_contents('http://' . self::$address . $path, false, $context);
        self::assertIsString($raw);
        self::assertJson($raw, "$method $path ($type): " . $raw);
        $data = json_decode($raw, true, flags: JSON_THROW_ON_ERROR);
        self::assertIsArray($data);
        return $data;
    }

    public function testJsonPutPreservesSelectedOptionsForVotingAndWithdrawal(): void
    {
        foreach (['/api/v1/polls/81/votes', '/polls/81/votes', '/api/v1/polls/81/votes/?from=home'] as $path) {
            foreach ([[7], [7, 9], []] as $ids) {
                $body = ['option_ids' => $ids];
                $response = $this->ingress('PUT', $path, json_encode($body, JSON_THROW_ON_ERROR), 'Application/JSON; charset=UTF-8');
                self::assertSame($body, $response['body']);
                self::assertTrue($response['object']);
            }
        }
    }

    public function testOtherJsonPutsAndPostPatchStillDecode(): void
    {
        foreach (['/api/v1/events/91/rsvp', '/api/v1/chats/5/messages/8/reaction'] as $path) {
            self::assertSame(['status' => 'going'], $this->ingress('PUT', $path, '{"status":"going"}')['body']);
        }
        foreach (['POST', 'PATCH'] as $method) {
            self::assertSame(['question' => 'Fictional?'], $this->ingress($method, '/api/v1/polls/81', '{"question":"Fictional?"}')['body']);
        }
        self::assertFalse($this->ingress('PUT', '/api/v1/polls/81/votes', '[]')['object']);
        self::assertSame([], $this->ingress('PUT', '/api/v1/polls/81/votes', '{invalid')['body']);
    }

    public function testPhotoRoutesRetainBoundedRawReadingEvenWithJsonMime(): void
    {
        foreach (['/api/v1/media/uploads/fictional/content', '/api/v1/me/photos/avatar', '/api/v1/groups/3/photos/cover', '/api/v1/chats/5/uploads/fictional', '/api/v1/events/91/cover'] as $path) {
            foreach (['application/json', 'image/png'] as $type) {
                $short = '{"fake":true}';
                self::assertSame([], $this->ingress('PUT', $path, $short, $type)['body']);
                self::assertSame($short, $this->ingress('PUT', $path, $short, $type)['raw']);
                $large = json_encode(['fake' => str_repeat('x', 1024)], JSON_THROW_ON_ERROR);
                self::assertNull($this->ingress('PUT', $path, $large, $type)['raw']);
            }
        }
    }
}
