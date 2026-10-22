# ADR 0005: mobile number and password first, OTP later

Status: accepted by the owner, 22 October 2026. This supersedes earlier OTP-first and email-login wording.

## Decision

- Anyone may register without a group invitation. The initial identifier is a mobile number with country code, and the initial authenticator is a password. No email login. OTP is a later addition.
- Registration creates an account only; it never grants group membership. The person can create a group, join using a link, or accept a direct invitation. Direct additions require consent, and subgroup/approval rules continue to apply.
- Mobile clients are Flutter for Android and iOS. The backend remains a small custom PHP 8.3+/MySQL 8 REST API, with focused TES tasks, explicit dependencies and PDO repositories; no Laravel or authentication SaaS requirement.
- UI work uses an isolated, clearly labeled design preview until the API contract and backend exist. It validates input then discards it. It never stores passwords, creates accounts, issues tokens or silently joins fictional groups.

## Security consequences before real accounts

Without OTP, possession of the mobile number is not verified. Store verification state separately; do not reveal whether a number is registered in public lookup, invite, login or recovery responses. Number changes and recovery need an explicit secure design before launch. Do not invent SMS delivery or a password-reset bypass.

Require HTTPS, server-side validation, rate limiting, generic authentication failures, revocable/expiring sessions, secure device token storage, exact-group authorization and redacted logs. Hash passwords with PHP password_hash/password_verify, preferring supported Argon2id with reviewed resource limits; do not silently truncate passwords or rely on client hashing. Parameterize all SQL. Review the OpenAPI contract and authorization tests before client integration.

The preview proposes 15–128 Unicode characters for registration passwords, permits spaces, allows paste/password managers and has a show/hide control. Login checks only presence, leaving credential verification to the server. Phone checks validate international syntax, not ownership or number validity. Final policies must agree with the API.

References: [OWASP authentication guidance](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html), [PHP password hashing](https://www.php.net/manual/en/function.password-hash.php).
