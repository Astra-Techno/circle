<?php
/** Public APK fallback for hosts that deploy pages/metadata without binaries. */
declare(strict_types=1);
header('Cache-Control: no-store, max-age=0');
header('X-Content-Type-Options: nosniff');
$release = json_decode((string) @file_get_contents(__DIR__ . '/release.json'), true);
$file = $_GET['file'] ?? '';
if (!is_array($release) || !is_string($file)
    || !preg_match('/^circle-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.apk$/D', $file)
    || $file !== 'circle-' . ($release['version'] ?? '') . '-' . ($release['build'] ?? '') . '.apk') {
    http_response_code(404);
    exit('Release not found.');
}
// An immutable filename selects a single release; no arbitrary URL or path input.
// The APK remains public in the repository; private application data never passes here.
header('Location: https://raw.githubusercontent.com/Astra-Techno/circle/main/downloads/' . rawurlencode($file), true, 302);
exit;
