<?php
/**
 * CIRCLE — One-Click Deployer for Shared Hosting
 *
 * Place this file at the subdomain root (circle.cloudkart24.com/deploy.php).
 * Run: curl -H "X-Deploy-Key: YOUR_DEPLOY_KEY" https://circle.cloudkart24.com/deploy.php
 * Or visit: https://circle.cloudkart24.com/deploy.php?key=YOUR_DEPLOY_KEY
 *
 * What it does:
 *   1. Downloads latest code from GitHub (main branch)
 *   2. Updates backend PHP files (src/, database/, index.php, .htaccess)
 *   3. Runs any pending DB migrations
 *   4. Regenerates the PSR-4 autoloader classmap
 *
 * NEVER overwrites: .env, storage/, vendor/composer/, deploy.php
 *
 * Required .env keys:
 *   DEPLOY_KEY      — random secret (at least 32 chars)
 *   GITHUB_REPO     — e.g. Astra-Techno/circle (default)
 *   GITHUB_BRANCH   — e.g. main (default)
 *   GITHUB_TOKEN    — only for private repos
 */

declare(strict_types=1);

ini_set('display_errors', '0');
error_reporting(E_ALL);
set_time_limit(120);

define('BASE_DIR',   __DIR__);
define('START_TIME', microtime(true));

// ── Load .env ────────────────────────────────────────────────
$envFile = BASE_DIR . '/.env';
$envVars = [];
if (file_exists($envFile)) {
    foreach (file($envFile) ?: [] as $line) {
        $line = trim($line);
        if ($line === '' || $line[0] === '#') continue;
        if (strpos($line, '=') !== false) {
            [$k, $v] = explode('=', $line, 2);
            $envVars[trim($k)] = trim($v, " \t\n\r\0\x0B\"'");
        }
    }
}

// ── Auth ─────────────────────────────────────────────────────
$deployKey = $envVars['DEPLOY_KEY'] ?? '';
$givenKey  = $_SERVER['HTTP_X_DEPLOY_KEY'] ?? $_GET['key'] ?? '';

header('Content-Type: text/html; charset=UTF-8');

if (strlen($deployKey) < 32 || $givenKey === '' || !hash_equals($deployKey, $givenKey)) {
    http_response_code(403);
    die(page('Access Denied', '<div class="err">403 — Invalid or missing deployment key.</div>'));
}

// ── Config ───────────────────────────────────────────────────
$repo   = $envVars['GITHUB_REPO']   ?? 'Astra-Techno/circle';
$branch = $envVars['GITHUB_BRANCH'] ?? 'main';
$token  = $envVars['GITHUB_TOKEN']  ?? '';

// ── Run ──────────────────────────────────────────────────────
$log = [];

function log_step(string $icon, string $msg, string $type = 'info'): void {
    global $log;
    $log[] = ['icon' => $icon, 'msg' => $msg, 'type' => $type];
}

function abort(string $msg): never {
    log_step('✗', $msg, 'err');
    echo page('Deploy Failed', render_log() . render_banner(false, $msg));
    exit;
}

// ══════════════════════════════════════════════════════════════
// STEP 1 — Download repo ZIP from GitHub
// ══════════════════════════════════════════════════════════════
log_step('⬇', "Downloading <strong>{$repo}@{$branch}</strong> from GitHub…");

$zipUrl  = "https://github.com/{$repo}/archive/refs/heads/{$branch}.zip";
$zipData = false;

if (function_exists('curl_init')) {
    $ch = curl_init($zipUrl);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 60,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_USERAGENT      => 'Circle-Deployer/1.0',
        CURLOPT_HTTPHEADER     => array_filter([
            $token !== '' ? "Authorization: Bearer {$token}" : null,
        ]),
    ]);
    $zipData  = curl_exec($ch);
    $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlErr  = curl_error($ch);
    curl_close($ch);

    if ($httpCode === 404) abort("Repo not found (404). Check GITHUB_REPO or add GITHUB_TOKEN for private repos.");
    if ($httpCode === 401 || $httpCode === 403) abort("GitHub auth failed ({$httpCode}). Check GITHUB_TOKEN in .env.");
    if ($httpCode !== 200) abort("GitHub returned HTTP {$httpCode}. cURL error: {$curlErr}");
} else {
    $ctx = stream_context_create(['http' => [
        'method'          => 'GET',
        'timeout'         => 60,
        'follow_location' => 1,
        'header'          => implode("\r\n", array_filter([
            'User-Agent: Circle-Deployer/1.0',
            $token !== '' ? "Authorization: Bearer {$token}" : '',
        ])),
    ]]);
    $zipData = @file_get_contents($zipUrl, false, $ctx);
}

if ($zipData === false || $zipData === '') {
    abort('Failed to download ZIP. Enable cURL or allow_url_fopen on this server.');
}
log_step('✓', 'Download complete (' . round(strlen($zipData) / 1024) . ' KB)', 'ok');

// ══════════════════════════════════════════════════════════════
// STEP 2 — Extract to temp dir
// ══════════════════════════════════════════════════════════════
log_step('📦', 'Extracting ZIP…');

$tmpZip = sys_get_temp_dir() . '/circle_deploy_' . time() . '.zip';
$tmpDir = sys_get_temp_dir() . '/circle_extract_' . time();

file_put_contents($tmpZip, $zipData);
unset($zipData);

$zip = new ZipArchive();
if ($zip->open($tmpZip) !== true) {
    @unlink($tmpZip);
    abort('Failed to open ZIP. ZipArchive extension may be missing.');
}
$zip->extractTo($tmpDir);
$zip->close();
@unlink($tmpZip);

// GitHub ZIP root: circle-main/ or Astra-Techno-circle-abc1234/
$extractedDirs = glob($tmpDir . '/*', GLOB_ONLYDIR);
if (empty($extractedDirs)) {
    rrmdir($tmpDir);
    abort('ZIP extraction failed — no directories found.');
}
$repoRoot = $extractedDirs[0];

log_step('✓', 'Extracted to temp directory', 'ok');

// ══════════════════════════════════════════════════════════════
// STEP 3 — Update backend files
// ══════════════════════════════════════════════════════════════
log_step('🔧', 'Updating backend files…');

$srcBackend = $repoRoot . '/backend';
if (!is_dir($srcBackend)) {
    cleanup($tmpDir);
    abort('backend/ folder not found in repo. Check GITHUB_REPO.');
}

// Files/dirs in the REPO backend/ to deploy:
//   src/         → src/          (application code)
//   database/    → database/     (migration SQL files)
//   public/index.php → index.php (front controller, adapted path)
//   public/.htaccess  → skipped  (we use our own root .htaccess)
//   composer.json     → composer.json

$copied = [];

// 3a. Copy src/ (all application PHP)
if (is_dir($srcBackend . '/src')) {
    rcopy($srcBackend . '/src', BASE_DIR . '/src', [], $copied);
}

// 3b. Copy database/migrations/
if (is_dir($srcBackend . '/database')) {
    rcopy($srcBackend . '/database', BASE_DIR . '/database', [], $copied);
}

// 3c. Copy composer.json (for reference, not executed)
if (file_exists($srcBackend . '/composer.json')) {
    copy($srcBackend . '/composer.json', BASE_DIR . '/composer.json');
    $copied[] = BASE_DIR . '/composer.json';
}

log_step('✓', 'Backend updated — ' . count($copied) . ' file(s)', 'ok');
log_step('📋', render_file_list($copied, BASE_DIR), 'muted');

// ══════════════════════════════════════════════════════════════
// STEP 3b — Update landing page & downloads (APK)
// ══════════════════════════════════════════════════════════════

// Copy website/ assets → site root (landing page + logo)
$srcWebsiteDir = $repoRoot . '/website';
if (is_dir($srcWebsiteDir)) {
    $websiteCopied = [];
    // index.html → home.html (landing page at site root)
    if (file_exists($srcWebsiteDir . '/index.html')) {
        copy($srcWebsiteDir . '/index.html', BASE_DIR . '/home.html');
        $websiteCopied[] = BASE_DIR . '/home.html';
    }
    // Copy all other website files (logo, images, etc.) to site root
    foreach (glob($srcWebsiteDir . '/*') as $wf) {
        $name = basename($wf);
        if ($name === 'index.html') continue; // already handled
        if (is_file($wf)) {
            copy($wf, BASE_DIR . '/' . $name);
            $websiteCopied[] = BASE_DIR . '/' . $name;
        }
    }
    log_step('✓', 'Landing page updated — ' . count($websiteCopied) . ' file(s)', 'ok');
    log_step('📋', render_file_list($websiteCopied, BASE_DIR), 'muted');
} else {
    log_step('·', 'No website/ folder in repo — skipping landing page', 'muted');
}

// Copy downloads/ folder (APK + download page)
$srcDownloads = $repoRoot . '/downloads';
if (is_dir($srcDownloads)) {
    log_step('📱', 'Updating downloads (APK)…');
    $dlCopied = [];
    rcopy($srcDownloads, BASE_DIR . '/downloads', [], $dlCopied);
    log_step('✓', 'Downloads updated — ' . count($dlCopied) . ' file(s)', 'ok');
    log_step('📋', render_file_list($dlCopied, BASE_DIR), 'muted');
} else {
    log_step('·', 'No downloads/ folder in repo — skipping', 'muted');
}

// Copy .htaccess from deploy template (keeps routing rules up to date)
$srcHtaccess = $repoRoot . '/backend/deploy/.htaccess';
if (file_exists($srcHtaccess)) {
    copy($srcHtaccess, BASE_DIR . '/.htaccess');
    log_step('✓', '.htaccess updated', 'ok');
}

// ══════════════════════════════════════════════════════════════
// STEP 4 — Regenerate PSR-4 autoloader classmap
// ══════════════════════════════════════════════════════════════
log_step('🔄', 'Regenerating autoloader…');

$classmapCount = regenerateAutoloader();
log_step('✓', "Autoloader rebuilt — {$classmapCount} classes mapped", 'ok');

// ══════════════════════════════════════════════════════════════
// STEP 5 — Run DB migrations
// ══════════════════════════════════════════════════════════════
log_step('🗂', 'Running database migrations…');

$migrationLog = runMigrations();
$migrationErrors = false;
foreach ($migrationLog as $m) {
    $icon = match ($m['status']) { 'done' => '✓', 'skip' => '·', default => '✗' };
    $type = match ($m['status']) { 'done' => 'ok', 'fail' => 'err', default => 'muted' };
    log_step($icon, $m['name'] . ($m['error'] ?? ''), $type);
    if ($m['status'] === 'fail') $migrationErrors = true;
}

// ══════════════════════════════════════════════════════════════
// Cleanup & report
// ══════════════════════════════════════════════════════════════
cleanup($tmpDir);

$elapsed = round(microtime(true) - START_TIME, 1);
$hasError = $migrationErrors || count(array_filter($log, fn($l) => $l['type'] === 'err')) > 0;
log_step('🏁', "Deployment completed in {$elapsed}s", $hasError ? 'warn' : 'ok');

echo page('Deploy', render_log() . render_banner(
    !$hasError,
    $hasError ? 'Deployment finished with errors.' : 'Deployment successful!'
));


// ═══════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════

/**
 * Runs migrations using Circle's schema: database/migrations/*.sql
 * Uses its own PDO (not Circle\Core\Database) to avoid bootstrap issues.
 */
function runMigrations(): array {
    global $envVars;
    $log = [];

    try {
        $dsn  = sprintf('mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
            $envVars['DB_HOST'] ?? 'localhost',
            $envVars['DB_PORT'] ?? '3306',
            $envVars['DB_DATABASE'] ?? 'circle'
        );
        $db = new PDO($dsn, $envVars['DB_USERNAME'] ?? '', $envVars['DB_PASSWORD'] ?? '', [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
        $db->exec("SET time_zone = '+00:00'");

        $db->exec("CREATE TABLE IF NOT EXISTS migrations (
            id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(255) NOT NULL UNIQUE,
            executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

        $stmt    = $db->query("SELECT name FROM migrations ORDER BY id");
        $applied = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_COLUMN) : [];

        $files = glob(BASE_DIR . '/database/migrations/*.sql') ?: [];
        sort($files);

        foreach ($files as $file) {
            $name = basename($file);
            if (in_array($name, $applied, true)) {
                $log[] = ['status' => 'skip', 'name' => $name];
                continue;
            }

            $sql = file_get_contents($file);
            if ($sql === false || trim($sql) === '') {
                $log[] = ['status' => 'skip', 'name' => $name . ' (empty)'];
                continue;
            }

            // Split on semicolons at end of line (same as Circle\Core\Migrator::split)
            $lines = array_filter(
                preg_split('/\R/', $sql) ?: [],
                static fn(string $l): bool => !str_starts_with(ltrim($l), '--')
            );
            $parts = preg_split('/;\s*$/m', implode("\n", $lines)) ?: [];
            $statements = array_values(array_filter(array_map('trim', $parts), fn($s) => $s !== ''));

            try {
                foreach ($statements as $stmt) {
                    $db->exec($stmt);
                }
                $ins = $db->prepare("INSERT INTO migrations (name) VALUES (:name)");
                $ins->execute(['name' => $name]);
                $log[] = ['status' => 'done', 'name' => $name];
            } catch (PDOException $e) {
                $log[] = ['status' => 'fail', 'name' => $name, 'error' => ' — ' . $e->getMessage()];
                break; // stop on first failure
            }
        }

        if (empty($files)) {
            $log[] = ['status' => 'skip', 'name' => 'No migration files found'];
        }
    } catch (Throwable $e) {
        $log[] = ['status' => 'fail', 'name' => 'DB connection', 'error' => ' — ' . $e->getMessage()];
    }

    return $log;
}

/**
 * Rebuilds vendor/composer/autoload_classmap.php by scanning src/ for classes.
 * This replaces `composer dump-autoload` for shared hosting without SSH.
 */
function regenerateAutoloader(): int {
    $srcDir      = BASE_DIR . '/src';
    $composerDir = BASE_DIR . '/vendor/composer';

    if (!is_dir($composerDir)) {
        log_step('⚠', 'vendor/composer/ missing — autoloader not rebuilt. Upload vendor/ first.', 'warn');
        return 0;
    }

    // Scan all PHP files in src/ and extract their fully-qualified class names
    $classmap = [];
    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($srcDir, RecursiveDirectoryIterator::SKIP_DOTS)
    );

    foreach ($iterator as $file) {
        /** @var SplFileInfo $file */
        if ($file->getExtension() !== 'php') continue;

        $content = file_get_contents($file->getPathname());
        if ($content === false) continue;

        // Extract namespace
        $namespace = '';
        if (preg_match('/^\s*namespace\s+([^;\s]+)/m', $content, $nsMatch)) {
            $namespace = $nsMatch[1];
        }

        // Extract class/interface/enum/trait names
        if (preg_match('/^\s*(?:final\s+|abstract\s+|readonly\s+)*(?:class|interface|enum|trait)\s+(\w+)/m', $content, $classMatch)) {
            $fqcn = $namespace !== '' ? $namespace . '\\' . $classMatch[1] : $classMatch[1];
            $relativePath = str_replace('\\', '/', str_replace(realpath(BASE_DIR) ?: BASE_DIR, '', realpath($file->getPathname()) ?: $file->getPathname()));
            $classmap[$fqcn] = '$baseDir . ' . var_export($relativePath, true);
        }
    }

    // Write the classmap
    ksort($classmap);
    $entries = '';
    foreach ($classmap as $class => $path) {
        $entries .= "    " . var_export($class, true) . " => {$path},\n";
    }

    $classmapContent = "<?php\n\n// autoload_classmap.php @generated by CIRCLE deploy.php\n\n"
        . "\$baseDir = dirname(__DIR__, 2);\n\n"
        . "return array(\n{$entries});\n";

    file_put_contents($composerDir . '/autoload_classmap.php', $classmapContent);

    // Also update autoload_psr4.php to ensure Circle\\ maps to src/
    $psr4Content = "<?php\n\n// autoload_psr4.php @generated by CIRCLE deploy.php\n\n"
        . "\$vendorDir = dirname(__DIR__);\n"
        . "\$baseDir = dirname(\$vendorDir);\n\n"
        . "return array(\n"
        . "    'Circle\\\\' => array(\$baseDir . '/src'),\n"
        . ");\n";

    file_put_contents($composerDir . '/autoload_psr4.php', $psr4Content);

    return count($classmap);
}

/** Recursive copy, skipping listed names. Returns list of copied file paths. */
function rcopy(string $src, string $dst, array $skip = [], array &$copied = []): array {
    if (!is_dir($dst) && !@mkdir($dst, 0755, true) && !is_dir($dst)) {
        log_step('⚠', "Could not create directory: {$dst}", 'warn');
        return $copied;
    }
    foreach (new DirectoryIterator($src) as $item) {
        if ($item->isDot()) continue;
        if (in_array($item->getFilename(), $skip, true)) continue;
        $srcPath = $item->getPathname();
        $dstPath = $dst . '/' . $item->getFilename();
        if ($item->isDir()) {
            rcopy($srcPath, $dstPath, [], $copied);
        } else {
            copy($srcPath, $dstPath);
            $copied[] = $dstPath;
        }
    }
    return $copied;
}

function render_file_list(array $files, string $baseDir): string {
    if (empty($files)) return 'No files copied.';
    $base  = rtrim($baseDir, '/');
    $items = '';
    foreach ($files as $f) {
        $rel = ltrim(str_replace([$base, '\\'], ['', '/'], $f), '/');
        $items .= '<li style="font-family:monospace;font-size:.78rem;color:#475569">' . htmlspecialchars($rel) . '</li>';
    }
    return '<details style="cursor:pointer"><summary style="font-size:.82rem;color:#64748b">'
         . count($files) . ' files — click to expand</summary>'
         . '<ul style="margin:6px 0 0 16px;padding:0;list-style:disc">' . $items . '</ul>'
         . '</details>';
}

function rrmdir(string $dir): void {
    if (!is_dir($dir)) return;
    foreach (new DirectoryIterator($dir) as $item) {
        if ($item->isDot()) continue;
        $item->isDir() && !$item->isLink() ? rrmdir($item->getPathname()) : @unlink($item->getPathname());
    }
    @rmdir($dir);
}

function cleanup(string $tmpDir): void {
    rrmdir($tmpDir);
}

function render_log(): string {
    global $log;
    $rows = '';
    foreach ($log as $l) {
        $cls = match ($l['type']) { 'ok' => 'ok', 'err' => 'err', 'warn' => 'warn', 'muted' => 'muted', default => '' };
        $rows .= "<div class=\"row {$cls}\"><span class=\"ic\">{$l['icon']}</span><span>{$l['msg']}</span></div>";
    }
    return $rows;
}

function render_banner(bool $ok, string $msg): string {
    $cls = $ok ? 'ok' : 'err';
    $icon = $ok ? '✓' : '✗';
    return "<div class=\"banner {$cls}\">{$icon} {$msg}</div>";
}

function page(string $title, string $body): string {
    $host = htmlspecialchars($_SERVER['HTTP_HOST'] ?? 'localhost');
    $now  = gmdate('Y-m-d H:i:s') . ' UTC';
    return <<<HTML
<!DOCTYPE html><html lang="en"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CIRCLE Deploy — {$title}</title>
<style>
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;max-width:680px;margin:36px auto;padding:0 20px;background:#f8fafc;color:#1e293b}
  h1{font-size:1.3rem;margin:0 0 4px;color:#312e81}
  .sub{color:#64748b;font-size:.85rem;margin-bottom:24px}
  .row{display:flex;align-items:flex-start;gap:10px;padding:9px 14px;border-radius:9px;margin-bottom:4px;font-size:.88rem;background:white;border:1px solid #e2e8f0}
  .row.ok{border-color:#bbf7d0;background:#f0fdf4}
  .row.err{border-color:#fecaca;background:#fff5f5}
  .row.warn{border-color:#fde68a;background:#fffbeb}
  .row.muted{opacity:.55}
  .ic{flex-shrink:0;width:18px;text-align:center}
  .banner{padding:14px 18px;border-radius:10px;margin-top:20px;font-weight:600;font-size:.95rem}
  .banner.ok{background:#dcfce7;color:#166534;border:1px solid #bbf7d0}
  .banner.err{background:#fee2e2;color:#991b1b;border:1px solid #fecaca}
  details summary{cursor:pointer}
</style></head><body>
<h1>⊙ CIRCLE Deployer</h1>
<p class="sub">{$host} &nbsp;·&nbsp; {$now}</p>
{$body}
</body></html>
HTML;
}
