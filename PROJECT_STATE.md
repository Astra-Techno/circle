# CIRCLE project state

Updated: 27 October 2026. Inspect Git status before work; source, deployment and physical acceptance are distinct.

## Architecture and rules
- Flutter/Riverpod/go_router, shared Warm Keepsake tokens in mobile/lib/core; PHP8.3+/MySQL, OpenAPI docs/api-contracts/openapi.yaml.
- Main only; preserve unrelated work. Active checkout /workspace/circle-docs-sync. Original /workspace/circle retains old WIP; do not reapply it.
- AGENTS.md and README §0 govern verification, privacy, optional push, stable signing and coherent immutable downloads.
- Server core includes auth, private profiles/media, nested groups/membership/invite links, Memories/comments/reactions/saves/search. Chat/events/albums remain isolated previews, pending actual service batches.

## Current batch
- S1b plus owner-requested active-device/session controls. Pulled main safely through5e38ce5; contact-first invitations remain in place.
- OpenAPI0.3.8/migration013: owner-only active session list, separate public handles, device/OS/app labels, login/activity/IP timestamps and individual current/remote revocation. User-first locks serialize credential changes; revoked access/refresh/device registrations cannot survive.
- Android device details update optionally after login, without delaying authentication. Optional one-shot foreground location stores only a removable city/region/country label and timestamp. No background tracking, coordinates or hardware IDs are sent to CIRCLE.
- You → Account exposes Your devices and Change password. Password mutation uses no-replay, explicit success, raw current/new/confirm fields and safe ambiguous-outcome guidance. Auth/drafts/images/push cleanup is independent and guarded against newer sessions. Normal logout keeps the existing welcome navigation.
- Evidence and phone acceptance: docs/account-security-sessions.md. Recovery/security alert channels, registration policy alignment and broader privacy controls remain pending.

## Validation
- Dedicated circle_test:190 tests /3,167 assertions; PHPStan clean. Contract YAML parses and all internal references resolve.
- Flutter full:632 passed /1 skipped /13 known Windows-baseline golden failures on Linux. Final focused login/security/design/guards:45 passed, including storage-failure cleanup added after full run. Format/analyze clean; eight security phone/tablet light/dark200% renders inspected.
- Existing thirteen Windows-baseline golden comparisons fail on Linux; preserve approved baselines. One known skipped test. No Android device attached.

## Release versus live
- Verified live main download: Android1.0.12+13, production HTTPS API/previewfalse/client pushtrue;65,129,974 bytes, SHA256668516107c74d4005c988bb9e62688bbfeecfb0127ae43eeb292fc41b3263bfe. Stable/versioned APKs, JSON and both buttons align; earlier immutable artifacts preserved.
- Source/release81006ef pushed. Deployment completed (125s response/123s script), migration013 applied. Complete hosted stable+immutable APK hashes, metadata/buttons and expected cache headers verified. API healthy; session list/update/revoke routes reject unauthenticated access.
- Established certificate SHA256:6c78be13d88b19587e4c37edb9012e3f2eb37fee34f6850084dd069d78f9b66c; verified. Existing coarse-location only, no fine/background location, hardware-ID, broad contacts or automatic SMS permission added. Build127.5s.
- Deployer preserves hosted .env, storage, PHP handlers and deploy.php itself. Source push alone is not deployment evidence.

## Remaining acceptance and next work
- Owner confirmed private server sender/cron ready and can test APK. Real device update, native location/geocoder/permissions, two-device logout/password re-login, contacts/composers and actual push/tap results remain pending.
- Later feature order and notification matrix: docs/pending-work.md. S1b/session controls are the current batch; safety/privacy, live Chats, live Events, polls/albums follow in verified batches.
- Evidence: docs/contact-invite-sharing.md, docs/push-device-acceptance.md, docs/password-change-foundation.md.

## Commands
- Source /workspace/toolchain/mobile-env when present; dart format, flutter analyze and focused/full flutter test. Never run Flutter tests during APK build.
- Backend composer test only against circle_test, composer analyse; toolchain test-env when present (never print secrets).
- Release verify package/version/certificate/permissions/hash/bytes; align stable+immutable APK/JSON/both buttons, then verify complete hosted bytes.
