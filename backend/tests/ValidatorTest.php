<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Core\Validator;
use PHPUnit\Framework\TestCase;

final class ValidatorTest extends TestCase
{
    public function testUtf8CharacterLimitsAndInvalidInput(): void
    {
        self::assertFalse((new Validator())->password(str_repeat('அ', 6))->fails());
        self::assertFalse((new Validator())->password(str_repeat('🙂', 128))->fails());
        self::assertTrue((new Validator())->password(str_repeat('🙂', 129))->fails());
        self::assertTrue((new Validator())->password("bad\xfftext")->fails());
        self::assertTrue((new Validator())->string('name', "bad\xfftext")->fails());
        self::assertFalse((new Validator())->string('name', "அ\n🙂", 3, 3)->fails());
        self::assertFalse((new Validator())->password('      ')->fails());
    }

    public function testValidationWorksWithoutMbstring(): void
    {
        $code = 'require ' . var_export(__DIR__ . '/../src/Core/Validator.php', true) . ';'
            . 'if (function_exists("mb_strlen")) exit(2);'
            . '$valid = new \Circle\Core\Validator(); $valid->password(str_repeat("🙂", 6))->string("name", "தமிழ்", 1, 100);'
            . '$invalid = new \Circle\Core\Validator(); $invalid->password("bad\xfftext");'
            . 'echo json_encode([$valid->fails(), $invalid->fails()]);';
        $output = [];
        $status = 0;
        exec(escapeshellarg(PHP_BINARY) . ' -n -r ' . escapeshellarg($code), $output, $status);
        self::assertSame(0, $status);
        self::assertSame('[false,true]', implode('', $output));
    }
}
