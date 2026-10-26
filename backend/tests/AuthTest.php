<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Core\Database;
use Circle\Core\Env;
use Circle\Core\JWT;
use Circle\Core\Passwords;

final class AuthTest extends ApiTestCase
{
    public function testRegisterThenLoginReturnsTokens(): void
    {
        $user = $this->user('Asha');
        self::assertGreaterThan(0, $user['id']);

        $me = $this->request('GET', '/api/v1/me', [], $user['token']);
        self::assertSame(200, $me->status());
        self::assertSame('Asha', $me->data()['display_name']);
    }

    public function testRegisterDoesNotRevealExistingNumber(): void
    {
        $mobile = $this->nextMobile();
        $first = $this->request('POST', '/api/v1/auth/register', ['mobile' => $mobile, 'password' => self::PASSWORD]);
        $second = $this->request('POST', '/api/v1/auth/register', ['mobile' => $mobile, 'password' => 'a different long password']);

        self::assertSame(202, $first->status());
        self::assertSame(202, $second->status());
        self::assertSame($first->json(), $second->json());

        // The original password still works; the second registration changed nothing.
        $login = $this->request('POST', '/api/v1/auth/login', ['mobile' => $mobile, 'password' => self::PASSWORD]);
        self::assertSame(200, $login->status());
    }

    public function testRegisterValidatesPasswordLengthWithoutTrimming(): void
    {
        $short = $this->request('POST', '/api/v1/auth/register', ['mobile' => $this->nextMobile(), 'password' => '  x  ']);
        self::assertSame(422, $short->status());

        // Leading/trailing spaces are part of the password.
        $mobile = $this->nextMobile();
        $spaced = '  spaced password here  ';
        self::assertSame(202, $this->request('POST', '/api/v1/auth/register', ['mobile' => $mobile, 'password' => $spaced])->status());
        self::assertSame(200, $this->request('POST', '/api/v1/auth/login', ['mobile' => $mobile, 'password' => $spaced])->status());
        self::assertSame(401, $this->request('POST', '/api/v1/auth/login', ['mobile' => $mobile, 'password' => trim($spaced)])->status());
    }

    public function testInvalidMobileRejected(): void
    {
        $r = $this->request('POST', '/api/v1/auth/register', ['mobile' => '98765', 'password' => self::PASSWORD]);
        self::assertSame(422, $r->status());
    }

    public function testLoginFailuresAreGeneric(): void
    {
        $user = $this->user();
        $wrongPassword = $this->request('POST', '/api/v1/auth/login', ['mobile' => $user['mobile'], 'password' => 'wrong password value']);
        $unknownNumber = $this->request('POST', '/api/v1/auth/login', ['mobile' => '+15550001111', 'password' => self::PASSWORD]);

        self::assertSame(401, $wrongPassword->status());
        self::assertSame(401, $unknownNumber->status());
        self::assertSame($wrongPassword->json(), $unknownNumber->json());
        self::assertSame('invalid_credentials', $wrongPassword->errorCode());
    }

    public function testPasswordStoredWithReviewedArgon2idParameters(): void
    {
        $user = $this->user();
        $row = Database::queryOne('SELECT password_hash FROM users WHERE id = :id', ['id' => $user['id']]);
        self::assertNotNull($row);
        self::assertStringStartsWith('$argon2id$v=19$m=65536,t=3,p=1$', (string) $row['password_hash']);
        self::assertFalse(Passwords::needsRehash(Passwords::DUMMY_HASH), 'Dummy hash must match current parameters');
    }

    public function testLegacyHashIsUpgradedOnLogin(): void
    {
        $user = $this->user();
        Database::execute('UPDATE users SET password_hash = :h WHERE id = :id', [
            'h' => password_hash(self::PASSWORD, PASSWORD_BCRYPT), 'id' => $user['id'],
        ]);
        self::assertSame(200, $this->request('POST', '/api/v1/auth/login', ['mobile' => $user['mobile'], 'password' => self::PASSWORD])->status());
        $row = Database::queryOne('SELECT password_hash FROM users WHERE id = :id', ['id' => $user['id']]);
        self::assertNotNull($row);
        self::assertStringStartsWith('$argon2id$', (string) $row['password_hash']);
    }

    public function testRefreshRotatesAndOldRefreshTokenIsSingleUse(): void
    {
        $user = $this->user();
        $r1 = $this->request('POST', '/api/v1/auth/refresh', ['refresh_token' => $user['refresh']]);
        self::assertSame(200, $r1->status());
        self::assertNotSame($user['refresh'], $r1->data()['refresh_token']);

        $reuse = $this->request('POST', '/api/v1/auth/refresh', ['refresh_token' => $user['refresh']]);
        self::assertSame(401, $reuse->status());

        // Tokens issued within the same second are still distinct (jti).
        $r2 = $this->request('POST', '/api/v1/auth/refresh', ['refresh_token' => $r1->data()['refresh_token']]);
        self::assertSame(200, $r2->status());
        self::assertNotSame($r1->data()['access_token'], $r2->data()['access_token']);

        // The access token from before the rotation keeps working within the same session.
        self::assertSame(200, $this->request('GET', '/api/v1/me', [], $user['token'])->status());
    }

    public function testTwoLoginsInSameSecondCreateSeparateSessions(): void
    {
        $user = $this->user();
        $a = $this->request('POST', '/api/v1/auth/login', ['mobile' => $user['mobile'], 'password' => self::PASSWORD]);
        $b = $this->request('POST', '/api/v1/auth/login', ['mobile' => $user['mobile'], 'password' => self::PASSWORD]);
        self::assertSame(200, $a->status());
        self::assertSame(200, $b->status());
        self::assertNotSame($a->data()['refresh_token'], $b->data()['refresh_token']);
    }

    public function testLogoutRevokesSessionAccessAndRefresh(): void
    {
        $user = $this->user();
        self::assertSame(200, $this->request('POST', '/api/v1/auth/logout', [], $user['token'])->status());

        self::assertSame(401, $this->request('GET', '/api/v1/me', [], $user['token'])->status());
        self::assertSame(401, $this->request('POST', '/api/v1/auth/refresh', ['refresh_token' => $user['refresh']])->status());
    }

    public function testSuspendedUserRejectedEverywhere(): void
    {
        $user = $this->user();
        Database::execute("UPDATE users SET status = 'suspended' WHERE id = :id", ['id' => $user['id']]);

        $me = $this->request('GET', '/api/v1/me', [], $user['token']);
        self::assertSame(403, $me->status());
        self::assertSame('account_inactive', $me->errorCode());

        self::assertSame(403, $this->request('POST', '/api/v1/auth/refresh', ['refresh_token' => $user['refresh']])->status());
        self::assertSame(403, $this->request('POST', '/api/v1/auth/login', ['mobile' => $user['mobile'], 'password' => self::PASSWORD])->status());
        // Wrong password for a suspended account stays generic.
        self::assertSame(401, $this->request('POST', '/api/v1/auth/login', ['mobile' => $user['mobile'], 'password' => 'not the password!!'])->status());
    }

    public function testDeletedUserTokensRejected(): void
    {
        $user = $this->user();
        Database::execute("UPDATE users SET status = 'deleted' WHERE id = :id", ['id' => $user['id']]);
        self::assertSame(401, $this->request('GET', '/api/v1/me', [], $user['token'])->status());
        self::assertSame(401, $this->request('POST', '/api/v1/auth/login', ['mobile' => $user['mobile'], 'password' => self::PASSWORD])->status());
    }

    public function testTamperedTokenRejected(): void
    {
        $user = $this->user();
        [$h, $p, $s] = explode('.', $user['token']);
        $payload = json_decode((string) base64_decode(strtr($p, '-_', '+/')), true);
        self::assertIsArray($payload);
        $payload['sub'] = $payload['sub'] + 1;
        $forged = $h . '.' . rtrim(strtr(base64_encode((string) json_encode($payload)), '+/', '-_'), '=') . '.' . $s;

        self::assertSame(401, $this->request('GET', '/api/v1/me', [], $forged)->status());
    }

    public function testExpiredTokenRejected(): void
    {
        $user = $this->user();
        $sid = $this->sessionId($user['token']);
        $expired = JWT::encode(['sub' => $user['id'], 'sid' => $sid, 'jti' => 'x', 'iat' => time() - 100, 'exp' => time() - 10, 'type' => 'access'], JWT::secret());
        self::assertSame(401, $this->request('GET', '/api/v1/me', [], $expired)->status());
    }

    public function testTokenWithoutExpRejected(): void
    {
        $user = $this->user();
        $sid = $this->sessionId($user['token']);
        $noExp = JWT::encode(['sub' => $user['id'], 'sid' => $sid, 'jti' => 'x', 'iat' => time(), 'type' => 'access'], JWT::secret());
        self::assertSame(401, $this->request('GET', '/api/v1/me', [], $noExp)->status());
    }

    public function testRefreshTokenCannotBeUsedAsAccessToken(): void
    {
        $user = $this->user();
        self::assertSame(401, $this->request('GET', '/api/v1/me', [], $user['refresh'])->status());
        self::assertSame(401, $this->request('POST', '/api/v1/auth/refresh', ['refresh_token' => $user['token']])->status());
    }

    public function testAlgNoneRejected(): void
    {
        $user = $this->user();
        $h = rtrim(strtr(base64_encode('{"alg":"none","typ":"JWT"}'), '+/', '-_'), '=');
        $p = explode('.', $user['token'])[1];
        self::assertSame(401, $this->request('GET', '/api/v1/me', [], "{$h}.{$p}.")->status());
    }

    public function testMissingTokenRejected(): void
    {
        self::assertSame(401, $this->request('GET', '/api/v1/me')->status());
    }

    public function testWeakJwtSecretRefusesToServe(): void
    {
        $good = Env::get('JWT_SECRET');
        try {
            foreach (['', 'short-secret', 'change-this-to-a-random-64-char-string'] as $bad) {
                Env::set('JWT_SECRET', $bad);
                $r = $this->request('GET', '/api/v1/health');
                self::assertSame(500, $r->status());
                self::assertSame('server_error', $r->errorCode());
                self::assertStringNotContainsString('JWT', (string) json_encode($r->json()));
            }
        } finally {
            Env::set('JWT_SECRET', $good);
        }
        self::assertSame(200, $this->request('GET', '/api/v1/health')->status());
    }

    public function testAuthRateLimit(): void
    {
        $limit = Env::get('RATE_LIMIT_AUTH_PER_MINUTE');
        Env::set('RATE_LIMIT_AUTH_PER_MINUTE', '3');
        try {
            for ($i = 0; $i < 3; $i++) {
                self::assertSame(401, $this->request('POST', '/api/v1/auth/login', ['mobile' => '+15550002222', 'password' => 'x'], null, [], '10.0.0.9')->status());
            }
            $r = $this->request('POST', '/api/v1/auth/login', ['mobile' => '+15550002222', 'password' => 'x'], null, [], '10.0.0.9');
            self::assertSame(429, $r->status());
            self::assertSame('60', $r->header('Retry-After'));
        } finally {
            Env::set('RATE_LIMIT_AUTH_PER_MINUTE', $limit);
        }
    }

    public function testPerMobileLoginFailureThrottle(): void
    {
        $user = $this->user();
        $limit = Env::get('LOGIN_MAX_FAILURES_PER_MOBILE');
        Env::set('LOGIN_MAX_FAILURES_PER_MOBILE', '2');
        try {
            // Failures from different IPs still count against the number.
            $this->request('POST', '/api/v1/auth/login', ['mobile' => $user['mobile'], 'password' => 'wrong one here'], null, [], '10.0.1.1');
            $this->request('POST', '/api/v1/auth/login', ['mobile' => $user['mobile'], 'password' => 'wrong one here'], null, [], '10.0.1.2');
            $r = $this->request('POST', '/api/v1/auth/login', ['mobile' => $user['mobile'], 'password' => self::PASSWORD], null, [], '10.0.1.3');
            self::assertSame(429, $r->status());
            $row = Database::queryOne("SELECT COUNT(*) AS c FROM rate_limits WHERE ip LIKE '+%'");
            self::assertSame(0, (int) ($row['c'] ?? -1), 'Raw mobile numbers must not be stored');
        } finally {
            Env::set('LOGIN_MAX_FAILURES_PER_MOBILE', $limit);
        }
    }

    private function sessionId(string $token): string
    {
        $payload = json_decode((string) base64_decode(strtr(explode('.', $token)[1], '-_', '+/')), true);
        self::assertIsArray($payload);
        return (string) $payload['sid'];
    }
}
