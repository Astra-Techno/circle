<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Core\FcmSender;
use PHPUnit\Framework\TestCase;

final class FcmSenderTest extends TestCase
{
    public function testOnlyStructuredUnregisteredErrorIdentifiesAnExpiredToken(): void
    {
        $unregistered = json_encode(['error' => ['details' => [[
            '@type' => 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
            'errorCode' => 'UNREGISTERED',
        ]]]], JSON_THROW_ON_ERROR);
        self::assertTrue(FcmSender::isUnregistered(404, $unregistered));
        self::assertFalse(FcmSender::isUnregistered(400, $unregistered));
        self::assertFalse(FcmSender::isUnregistered(404, '{"error":{"message":"Project UNREGISTERED not found"}}'));
        self::assertFalse(FcmSender::isUnregistered(404, '<html>Not found</html>'));
        self::assertFalse(FcmSender::isUnregistered(404, '{"error":{"details":"UNREGISTERED"}}'));
        self::assertFalse(FcmSender::isUnregistered(404, '{"error":{"details":[{"errorCode":"UNREGISTERED"}]}}'));
        self::assertFalse(FcmSender::isUnregistered(503, $unregistered));
    }
}
