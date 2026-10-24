<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Media\GdImageProcessor;
use Circle\Media\MediaServices;
use Circle\Tests\Support\ImageFixtures;

/**
 * Real image processing. Needs ext-gd (Ubuntu: sudo apt install php8.3-gd);
 * every test is skipped when GD is not installed.
 */
final class GdImageProcessorTest extends MediaTestCase
{
    private string $work;

    protected function setUp(): void
    {
        if (!GdImageProcessor::isAvailable()) {
            self::markTestSkipped('ext-gd not installed: real decode/re-encode, EXIF/GPS stripping and resize sizes cannot be verified here (install php8.3-gd).');
        }
        parent::setUp();
        $this->work = sys_get_temp_dir() . '/circle-gd-' . bin2hex(random_bytes(4));
        mkdir($this->work, 0700);
    }

    protected function tearDown(): void
    {
        if (isset($this->work) && is_dir($this->work)) {
            array_map('unlink', glob($this->work . '/*') ?: []);
            rmdir($this->work);
        }
        parent::tearDown();
    }

    private function realJpeg(int $w, int $h): string
    {
        $img = imagecreatetruecolor($w, $h);
        self::assertNotFalse($img);
        $red = imagecolorallocate($img, 200, 30, 30);
        self::assertNotFalse($red);
        imagefilledrectangle($img, 0, 0, intdiv($w, 2), $h, $red);
        ob_start();
        imagejpeg($img, null, 90);
        imagedestroy($img);
        return (string) ob_get_clean();
    }

    public function testStripsExifGpsAppliesOrientationAndResizes(): void
    {
        // Landscape pixels with EXIF orientation 6 (rotate 90° clockwise to view).
        $jpeg = ImageFixtures::withExif($this->realJpeg(3000, 2000), 6);
        self::assertStringContainsString(ImageFixtures::GPS_MARKER, $jpeg);
        $src = $this->work . '/in.jpg';
        file_put_contents($src, $jpeg);

        $out = (new GdImageProcessor())->process($src, 'image/jpeg', ['thumb' => 320, 'medium' => 1080, 'full' => 2048], $this->work);

        self::assertSame([2000, 3000], [$out->width, $out->height]);
        self::assertSame([1365, 2048], [$out->variants['full']['width'], $out->variants['full']['height']]);
        self::assertSame([720, 1080], [$out->variants['medium']['width'], $out->variants['medium']['height']]);
        self::assertSame([213, 320], [$out->variants['thumb']['width'], $out->variants['thumb']['height']]);

        $finfo = new \finfo(FILEINFO_MIME_TYPE);
        foreach ($out->variants as $variant) {
            $bytes = (string) file_get_contents($variant['path']);
            self::assertStringNotContainsString(ImageFixtures::GPS_MARKER, $bytes);
            self::assertStringNotContainsString('Exif', $bytes);
            self::assertSame($out->mimeType, $finfo->buffer($bytes));
            $size = getimagesizefromstring($bytes);
            self::assertNotFalse($size);
            self::assertSame([$variant['width'], $variant['height']], [$size[0], $size[1]]);
        }
    }

    public function testSmallPngIsNotUpscaledAndTextChunksDropped(): void
    {
        $src = $this->work . '/in.png';
        file_put_contents($src, ImageFixtures::png(40, 30));
        $out = (new GdImageProcessor())->process($src, 'image/png', ['thumb' => 320, 'full' => 2048], $this->work);
        self::assertSame([40, 30], [$out->variants['full']['width'], $out->variants['full']['height']]);
        self::assertStringNotContainsString(ImageFixtures::GPS_MARKER, (string) file_get_contents($out->variants['thumb']['path']));
    }

    public function testEndToEndUploadWithRealProcessor(): void
    {
        MediaServices::setProcessor(new GdImageProcessor());
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $jpeg = ImageFixtures::withExif($this->realJpeg(1600, 1200), 1);

        $id = $this->ticketId($owner, $gid, $jpeg, 'image/jpeg');
        $r = $this->putContent($owner, $id, $jpeg, 'image/jpeg');
        self::assertSame(200, $r->status(), json_encode($r->json()) ?: '');
        self::assertSame([1600, 1200], [$r->data()['width'], $r->data()['height']]);
        foreach ($this->storedFiles(true) as $path) {
            self::assertStringNotContainsString(ImageFixtures::GPS_MARKER, (string) file_get_contents($path));
        }
        self::assertCount(3, $this->storedFiles(true));
    }

    public function testCorruptImageIsRejected(): void
    {
        MediaServices::setProcessor(new GdImageProcessor());
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $png = ImageFixtures::pngBomb(100, 100); // valid header, truncated pixel data

        $id = $this->ticketId($owner, $gid, $png);
        $r = $this->putContent($owner, $id, $png);
        self::assertSame(422, $r->status());
        self::assertSame('media_invalid', $r->errorCode());
        self::assertSame([], $this->storedFiles(true));
    }
}
