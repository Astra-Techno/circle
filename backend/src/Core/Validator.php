<?php

declare(strict_types=1);

namespace Circle\Core;

final class Validator
{
    /** @var string[] */
    private array $errors = [];

    public function required(string $field, mixed $value, string $label = ''): self
    {
        $label = $label ?: $field;
        if ($value === null || (is_string($value) && trim($value) === '')) {
            $this->errors[] = "{$label} is required.";
        }
        return $this;
    }

    public function string(string $field, mixed $value, int $min = 1, int $max = 255, string $label = ''): self
    {
        $label = $label ?: $field;
        if (!is_string($value)) {
            $this->errors[] = "{$label} must be a string.";
            return $this;
        }
        $len = mb_strlen(trim($value));
        if ($len < $min) {
            $this->errors[] = "{$label} must be at least {$min} characters.";
        }
        if ($len > $max) {
            $this->errors[] = "{$label} must be at most {$max} characters.";
        }
        return $this;
    }

    public function mobile(string $value): self
    {
        if (!preg_match('/^\+[1-9][0-9]{7,14}$/', $value)) {
            $this->errors[] = 'Mobile number must be in E.164 format (e.g. +919876543210).';
        }
        return $this;
    }

    /** Length is counted in Unicode characters on the exact, untrimmed value. */
    public function password(string $value): self
    {
        if (!mb_check_encoding($value, 'UTF-8')) {
            $this->errors[] = 'Password must be valid text.';
            return $this;
        }
        $len = mb_strlen($value, 'UTF-8');
        if ($len < 15) {
            $this->errors[] = 'Password must be at least 15 characters.';
        }
        if ($len > 128) {
            $this->errors[] = 'Password must be at most 128 characters.';
        }
        return $this;
    }

    /** Optional calendar date in YYYY-MM-DD form. */
    public function date(string $field, string $value, string $label = ''): self
    {
        $label = $label ?: $field;
        $d = \DateTimeImmutable::createFromFormat('!Y-m-d', $value);
        if ($d === false || $d->format('Y-m-d') !== $value) {
            $this->errors[] = "{$label} must be a date in YYYY-MM-DD format.";
        }
        return $this;
    }

    /** @param array<int, mixed> $allowed */
    public function enum(string $field, mixed $value, array $allowed, string $label = ''): self
    {
        $label = $label ?: $field;
        if (!in_array($value, $allowed, true)) {
            $this->errors[] = "{$label} must be one of: " . implode(', ', $allowed) . '.';
        }
        return $this;
    }

    public function intRange(string $field, mixed $value, int $min, int $max, string $label = ''): self
    {
        $label = $label ?: $field;
        if (!is_int($value) && !is_numeric($value)) {
            $this->errors[] = "{$label} must be a number.";
            return $this;
        }
        $val = (int) $value;
        if ($val < $min || $val > $max) {
            $this->errors[] = "{$label} must be between {$min} and {$max}.";
        }
        return $this;
    }

    public function fails(): bool
    {
        return $this->errors !== [];
    }

    public function firstError(): string
    {
        return $this->errors[0] ?? '';
    }

    /** @return string[] */
    public function errors(): array
    {
        return $this->errors;
    }

    public function bail(): void
    {
        if ($this->fails()) {
            Response::validationError($this->firstError());
        }
    }
}
