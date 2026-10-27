# CIRCLE project state

Updated: 27 October 2026. Inspect Git status before work; source, deployment and physical acceptance are distinct.

## Architecture and rules
- Flutter/Riverpod/go_router, shared Warm Keepsake tokens in mobile/lib/core; PHP8.3+/MySQL, OpenAPI docs/api-contracts/openapi.yaml.
- Main only; preserve unrelated work. Active checkout /workspace/circle-docs-sync. Original /workspace/circle retains old WIP; do not reapply it.
- AGENTS.md and README §0 govern verification, privacy, optional push, stable signing and coherent immutable downloads.
- Server core includes auth, private profiles/media, nested groups/membership/invite links, Memories/comments/reactions/saves/search. Chat/events/albums remain isolated previews, pending actual service batches.

## Current batch
- Fix shared profile/banner visibility: owner uploads worked, but another member’s profile only rendered initials. Main pulled safely through9017286 before changes.
- PersonProfileScreen now fetches avatar+banner through existing private /profiles/{userId}/photos/{kind}; scoped by viewer/target/API/session and active exact shared membership. No public URLs, new backend API or migration.
- Refresh photos reloads replacements/removals; absent/inaccessible photos fall back calmly. Preview/own-photo behavior stays separate. The receiving person must update the APK; no re-upload is needed.
- Account/session/password controls from build13 remain in place. Device/location/two-phone acceptance is still pending. Current evidence: docs/mobile-release-1.0.13.md.

## Validation
- Backend unchanged this batch; focused ProfileTest on circle_test:5 tests /134 assertions pass. Prior full190 tests /3,167 assertions and PHPStan clean. Contract0.3.8 unchanged.
- Shared-photo/own-photo/profile/account/design focused29 passed; format/analyze clean, four phone/tablet light/dark200% profile renders inspected. Full regression640 passed /1 skipped /13 known Windows-baseline golden failures; no functional failures.
- Existing thirteen Windows-baseline golden comparisons fail on Linux; preserve approved baselines. One known skipped test. No Android device attached.

## Release versus live
- Verified live main download: Android1.0.13+14, production API/previewfalse/client pushtrue;65,129,974 bytes, SHA256 b9a7f88636dc5617b677a43633e3c948b4a263553212b4ee4437af0e7aa2c730. Stable/versioned APKs, metadata and both buttons align; earlier immutable artifacts preserved.
- Source/release8ee77c2 pushed; deployment completed (140.5s response/138.5s script). Full hosted stable+immutable hashes, metadata/buttons and expected cache headers verified. API healthy; private avatar/cover endpoints reject unauthenticated access. Backend/migrations unchanged this batch.
- Established certificate SHA256:6c78be13d88b19587e4c37edb9012e3f2eb37fee34f6850084dd069d78f9b66c verified; same package, versionCode14/minSdk24/targetSdk36. Build107.4s; AOT includes shared-photo implementation.
- Deployer preserves hosted .env, storage, PHP handlers and deploy.php itself. Actual two-phone photo display remains owner acceptance; uploader need not re-upload existing photos.

## Remaining acceptance and next work
- Owner confirmed private server sender/cron ready and can test APK. Real device update, native location/geocoder/permissions, two-device logout/password re-login, contacts/composers and actual push/tap results remain pending.
- Later feature order and notification matrix: docs/pending-work.md. S1b/session controls are the current batch; safety/privacy, live Chats, live Events, polls/albums follow in verified batches.
- Evidence: docs/contact-invite-sharing.md, docs/push-device-acceptance.md, docs/password-change-foundation.md.

## Commands
- Source /workspace/toolchain/mobile-env when present; dart format, flutter analyze and focused/full flutter test. Never run Flutter tests during APK build.
- Backend composer test only against circle_test, composer analyse; toolchain test-env when present (never print secrets).
- Release verify package/version/certificate/permissions/hash/bytes; align stable+immutable APK/JSON/both buttons, then verify complete hosted bytes.
