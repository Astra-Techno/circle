<?php

declare(strict_types=1);

namespace Circle\Tests;

use PHPUnit\Framework\TestCase;

final class DiagnosticsTest extends TestCase
{
    public function testConfigurationPageRequiresTokenAndOnlyShowsSelectedSettings(): void
    {
        $script = tempnam(sys_get_temp_dir(), 'circle-config-');
        self::assertNotFalse($script);
        $token = bin2hex(random_bytes(32));
        try {
            foreach (['disabled', 'denied', 'allowed', 'deployment'] as $mode) {
                $code = '<?php require ' . var_export(__DIR__ . '/../src/Core/Env.php', true)
                    . '; (new ReflectionProperty(\Circle\Core\Env::class, "loaded"))->setValue(null, true);'
                    . '\Circle\Core\Env::set("DIAGNOSTICS_TOKEN", ' . var_export(in_array($mode, ['disabled', 'deployment'], true) ? '' : $token, true) . ');'
                    . '\Circle\Core\Env::set("DEPLOY_KEY", ' . var_export($token, true) . ');'
                    . '$_SERVER["HTTP_X_DEPLOY_KEY"] = ' . var_export($mode === 'deployment' ? $token : '', true) . ';'
                    . '$_POST["token"] = ' . var_export($mode === 'allowed' ? $token : 'incorrect', true) . ';'
                    . 'require ' . var_export(__DIR__ . '/../public/diagnostics.php', true) . ';';
                file_put_contents($script, $code);
                $output = [];
                $status = 0;
                exec(escapeshellarg(PHP_BINARY) . ' ' . escapeshellarg($script) . ' 2>&1', $output, $status);
                self::assertSame(0, $status);
                $html = implode("\n", $output);
                self::assertStringNotContainsString($token, $html);
                if (in_array($mode, ['allowed', 'deployment'], true)) {
                    self::assertStringContainsString(PHP_VERSION, $html);
                    self::assertStringContainsString('memory_limit', $html);
                    self::assertStringNotContainsString('DB_PASSWORD', $html);
                    self::assertStringNotContainsString(__DIR__, $html);
                } else {
                    self::assertStringNotContainsString('memory_limit', $html);
                    self::assertStringNotContainsString(PHP_VERSION, $html);
                }
            }
        } finally {
            unlink($script);
        }
    }
    public function testCapturedErrorRedactsSecretsAndPersonalData(): void
    {
        $previous = \Circle\Core\Env::get('DIAGNOSTICS_TOKEN');
        $secret = bin2hex(random_bytes(32));
        \Circle\Core\Env::set('DIAGNOSTICS_TOKEN', $secret);
        try {
            \Circle\Core\Log::exception('synthetic', new \RuntimeException('Failure ' . $secret . " '+19995550123'"));
            $details = \Circle\Core\Log::latest();
            self::assertNotNull($details);
            self::assertSame('synthetic', $details['context']);
            $json = json_encode($details, JSON_THROW_ON_ERROR);
            self::assertStringNotContainsString($secret, $json);
            self::assertStringNotContainsString('+19995550123', $json);
            self::assertStringNotContainsString(__DIR__, $json);
        } finally {
            \Circle\Core\Env::set('DIAGNOSTICS_TOKEN', $previous);
        }
    }

    public function testFatalBeforeAutoloadIsLoggedWithoutPublicDetails(): void
    {
        $script = tempnam(sys_get_temp_dir(), 'circle-diagnostic-');
        self::assertNotFalse($script);
        $log = $script . '.log';
        $code = '<?php require ' . var_export(__DIR__ . '/../src/Core/Log.php', true)
            . '; require ' . var_export(__DIR__ . '/../src/Core/Diagnostics.php', true)
            . '; ini_set("error_log", ' . var_export($log, true) . ');'
            . '\Circle\Core\Diagnostics::enable();'
            . 'trigger_error("Synthetic bootstrap failure", E_USER_ERROR);';
        try {
            file_put_contents($script, $code);
            $output = [];
            $status = 0;
            exec(escapeshellarg(PHP_BINARY) . ' ' . escapeshellarg($script) . ' 2>&1', $output, $status);
            self::assertNotSame(0, $status);
            self::assertSame([], $output);
            $details = file_get_contents($log);
            self::assertNotFalse($details);
            self::assertStringContainsString('[CIRCLE] fatal: PHP=' . PHP_VERSION . ' SAPI=cli', $details);
            self::assertStringContainsString('Synthetic bootstrap failure', $details);
        } finally {
            unlink($script);
            if (is_file($log)) {
                unlink($log);
            }
        }
    }
}
