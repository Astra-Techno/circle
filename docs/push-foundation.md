# Push foundation N1a — 26 October 2026

This source batch implements secure device registration and saved delivery policy. It does not enable push delivery, live Activity/settings UI, Chats or Events, and it is not an APK release.

## Behavior and contracts

OpenAPI 0.3.4 describes `POST /devices/register`, `POST /devices/unregister` and `GET/PATCH /me/notification-preferences`. Backend implementation and typed Flutter API/model were checked against the contract. A focused independent static review identified JSON shape validation and complete-response category requirements; both were corrected and rechecked with no remaining blockers in this scope. That review did not execute database or native tests.

Tokens are opaque case-sensitive ASCII strings of 1–512 characters, never trimmed, logged or returned. Platforms are exactly android/ios; accepting an iOS token does not configure native iOS delivery. Migration 009 adds login-session binding and binary token comparison. Existing unscoped tokens remain stored but are ineligible until authenticated re-registration. Registration is idempotent and can reassign the installation token to the current account/session. Unregister removes only the matching account/session/token; an earlier session cannot remove a reassigned token.

Registration locks an open refresh session before writing. Server logout revokes the session and deletes its device registrations in the same transaction. Registration rechecks under lock so a request that passed middleware before logout cannot revive the revoked session. Other sessions/devices remain registered. Token rotation preserves the login session. Offline local logout, SDK callbacks and account-switch coordination still require N1b client lifecycle work; this batch does not claim those are solved.

Preferences are owner-only, `private, no-store`, with global push and every category disabled by default. Categories are Memories, replies/reactions, groups, chats, events, polls, albums and security. PATCH atomically merges specified fields/category switches; omitted values survive, explicit false is preserved. Unknown keys, invalid JSON/non-object shapes, null/coerced switches, invalid minutes and invalid IANA zones are rejected. Quiet hours default to 22:00–07:00 UTC, start inclusive/end exclusive; equal endpoints are rejected. The client must explicitly choose the person's timezone during later UI integration.

The internal sender now requires an explicit category and optional exact group, enforces current opt-in/quiet-hours/active-account/membership policy, and selects only tokens attached to open, unexpired login sessions. Non-security events without a group are currently denied. Direct invitations and other nonmember recipient cases need a separately authorized eligibility path, not a blanket bypass. Low-level provider send is private. This filter does not schedule deferred events: N1b must use an outbox/worker and recheck policy at send time. Group/conversation mutes and actionable foreground/tap handling must also be implemented before enabling real dispatch.

## Verification

- Dedicated circle_test backend suite: 143 tests / 2,222 assertions passed.
- Final focused foundation suite, after adding repeated-hour DST cases: 8 tests / 125 assertions passed. Covers validation, case-sensitive token uniqueness, ownership/session reassignment, refresh, logout cleanup, stale registrations, private partial preferences, raw JSON shapes and policy boundaries.
- PHPStan: clean.
- Focused Flutter contract/auth/profile/design checks: 28 passed. Final preference-only checks rerun after formatting/explicit-false coverage: 5 passed.
- Flutter full suite: 513 passed / 1 opt-in skipped / 13 golden comparisons failed, matching the previously recorded Windows-baseline cases. Baselines are unchanged; Windows approval remains unresolved. Flutter analysis and formatting checks recorded in the task handoff.
- OpenAPI YAML parses and all 306 local references resolve.

No production fixtures, provider messages, credentials or devices were used. No deployment or APK build was performed. These checks establish source behavior, not Firebase/device delivery.

## N1b source implementation and next client work

The durable outbox/CLI worker, injectable transport, retry classification, send-time eligibility and quiet-hour deferral are implemented for initial Memory/comment/reply events in [notification-worker.md](notification-worker.md). Group/reaction hooks remain future work. Complete SDK session ownership, contextual opt-in UI, foreground presentation and authorized tap routing in subsequent focused steps. Verify scheduler/private server credentials and real Android delivery before enabling notification capabilities. Each future feature family adds its reviewed events to the same delivery pipeline.
