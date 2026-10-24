<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Media\GdImageProcessor;
use Circle\Media\ImageInspector;
use Circle\Media\LocalDiskStorage;
use Circle\Media\MediaRejected;
use Circle\Media\Uuid;
use Circle\Tests\Support\ImageFixtures;
use PHPUnit\Framework\TestCase;

/** Pure units that need neither the database nor ext-gd. */
final class MediaUnitTest extends TestCase
{
    public function testFitPreservesAspectRatioAndNeverUpscales(): void
    {
        self::assertSame([2048, 1365], GdImageProcessor::fit(4032, 2688, 2048));
        self::assertSame([1365, 2048], GdImageProcessor::fit(2688, 4032, 2048));
        self::assertSame([320, 320], GdImageProcessor::fit(5000, 5000, 320));
        self::assertSame([100, 50], GdImageProcessor::fit(100, 50, 320));
        self::assertSame([320, 1], GdImageProcessor::fit(12000, 2, 320));
    }

    public function testMagicBytes(): void
    {
        self::assertSame('image/png', ImageInspector::magicType(ImageFixtures::png()));
        self::assertSame('image/jpeg', ImageInspector::magicType(ImageFixtures::jpegHeader()));
        self::assertSame('image/webp', ImageInspector::magicType(ImageFixtures::webpHeader()));
        self::assertSame('image/heic', ImageInspector::magicType(ImageFixtures::heicHeader()));
        self::assertNull(ImageInspector::magicType('<?php echo 1;'));
        self::assertNull(ImageInspector::magicType(''));
    }

    public function testInspectReportsDimensions(): void
    {
        $info = ImageInspector::inspect(ImageFixtures::jpegHeader(640, 480), 'image/jpeg', ['image/jpeg']);
        self::assertSame(['mime' => 'image/jpeg', 'width' => 640, 'height' => 480], $info);
        self::assertSame(50, ImageInspector::inspect(ImageFixtures::webpHeader(50, 20), 'image/webp', ['image/webp'])['width']);
    }

    public function testInspectRefusesTypesOutsideTheAllowlist(): void
    {
        try {
            ImageInspector::inspect(ImageFixtures::heicHeader(), 'image/heic', ['image/jpeg', 'image/png', 'image/webp']);
            self::fail('HEIC accepted without a HEIC-capable processor');
        } catch (MediaRejected $e) {
            self::assertSame(415, $e->status);
            self::assertSame('media_type_not_allowed', $e->errorCode);
        }
    }

    public function testUuid(): void
    {
        self::assertMatchesRegularExpression('/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/', Uuid::v4());
        self::assertNotSame(Uuid::v4(), Uuid::v4());
        self::assertSame('0f8fad5b-d9cb-469f-a165-70867728950e', Uuid::normalise('0F8FAD5B-D9CB-469F-A165-70867728950E'));
        self::assertNull(Uuid::normalise('../../etc/passwd'));
        self::assertNull(Uuid::normalise(42));
    }

    public function testStorageRejectsPathTraversal(): void
    {
        $root = dirname(__DIR__) . '/.phpunit.cache/storage-unit-' . bin2hex(random_bytes(4));
        $storage = new LocalDiskStorage($root);
        try {
            foreach (['../etc/passwd', 'media/../../x', 'media/1/../../x', '/etc/passwd', 'other/1/x', 'media/.hidden', 'media'] as $key) {
                try {
                    $storage->localPath($key);
                    self::fail("accepted {$key}");
                } catch (\InvalidArgumentException) {
                    self::addToAssertionCount(1);
                }
            }
            $src = $root . '/src.bin';
            file_put_contents($src, 'bytes');
            $storage->put('media/7/abc/thumb.webp', $src);
            self::assertSame('bytes', file_get_contents((string) $storage->localPath('media/7/abc/thumb.webp')));
            self::assertSame(0700, fileperms($root . '/media/7/abc') & 0777);
            $storage->deletePrefix('media/7/abc');
            self::assertNull($storage->localPath('media/7/abc/thumb.webp'));
            $storage->deletePrefix('media/7/abc');
        } finally {
            @unlink($root . '/src.bin');
            @rmdir($root . '/media/7');
            @rmdir($root . '/media');
            @rmdir($root);
        }
    }
}
