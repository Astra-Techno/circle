<?php

declare(strict_types=1);

namespace Circle\Core;

/**
 * Password hashing policy (ADR 0005).
 *
 * Argon2id with explicit, reviewed parameters: 64 MiB memory, 3 iterations,
 * 1 lane. This is above the OWASP Password Storage Cheat Sheet minimum
 * (19 MiB, t=2, p=1) and measured ~100 ms per hash on the development
 * machine. PHP's libsodium backend only supports threads = 1.
 * Passwords are hashed exactly as received: never trimmed or normalised.
 */
final class Passwords
{
    public const OPTIONS = [
        'memory_cost' => 65536,
        'time_cost' => 3,
        'threads' => 1,
    ];

    /**
     * Hash of a random throwaway value with the same parameters, used so that
     * a login for an unknown mobile number costs the same as a real one.
     */
    public const DUMMY_HASH = '$argon2id$v=19$m=65536,t=3,p=1$MHFqWWVEUmVYeTUuL2NYbw$VlfCYGZ8DsVsB1dcDiYIuf4GZi0LF3QoRXsG5WZQtYU';

    public static function hash(string $password): string
    {
        return password_hash($password, PASSWORD_ARGON2ID, self::OPTIONS);
    }

    /** Always performs one Argon2id verification, even when $hash is null. */
    public static function verify(string $password, ?string $hash): bool
    {
        if ($hash === null || $hash === '') {
            password_verify($password, self::DUMMY_HASH);
            return false;
        }
        return password_verify($password, $hash);
    }

    public static function needsRehash(string $hash): bool
    {
        return password_needs_rehash($hash, PASSWORD_ARGON2ID, self::OPTIONS);
    }
}
