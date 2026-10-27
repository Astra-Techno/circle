# CIRCLE project state

Updated: 27 October 2026. Inspect Git status before work; source, deployment and physical acceptance are distinct.

## Architecture and rules
- Flutter/Riverpod/go_router, shared Warm Keepsake tokens in mobile/lib/core; PHP8.3+/MySQL, OpenAPI docs/api-contracts/openapi.yaml.
- Main only; preserve unrelated work. Active checkout /workspace/circle-docs-sync. Original /workspace/circle retains old WIP; do not reapply it.
- AGENTS.md and README §0 govern verification, privacy, optional push, stable signing and coherent immutable downloads.
- Server core includes auth, private profiles/media, nested groups/membership/invite links, Memories/comments/reactions/saves/search. Chat/events/albums remain isolated previews, pending actual service batches.

## Current batch
- Deep person-avatar audit after build14 connected profiles but left list initials. Main pulled safely throughde11883. See docs/person-avatar-audit.md for every surface and intentional placeholders.
- New shared PersonAvatar wires Memories, comments/replies, group members, people/Memory search and mentions by stable user id. Chat/event/invite person-id surfaces are wired but remain gated fictional previews; group/category/name-only mock icons are not guessed into real photos.
- OpenAPI0.3.9 adds nullable Member.avatar_version. Workspace metadata gates absent photos, replacements/removals invalidate bytes, and a session/API/account-scoped64-entry/45s lazy LRU deduplicates thumbnails without background timers or disk caching.
- Server members render batches of30 with Show more/Refresh members. Private photo reads keep exact authorization with a separate bounded240/min per-IP quota, preserving general API budget. No migration/public image URL or permission change.

## Validation
- Dedicated circle_test192 tests /3,193 assertions, PHPStan clean. Member version/replacement/removal/path privacy and isolated photo quota tests pass. Contract0.3.9 references verified.
- Focused avatar/profile/device/design37 passed; format/analyze clean. Eight phone/tablet light/dark200% avatar renders inspected. Final full Flutter652 passed /1 skipped /13 known Windows-baseline golden failures, no functional failures. Approved goldens unchanged.
- Existing thirteen Windows-baseline golden comparisons fail on Linux; one known skipped test. No Android device attached. Native display remains owner acceptance.

## Release versus live
- Candidate Android1.0.14+15 packaged: 65,211,890 bytes, SHA256 4b154b4a3f1ddacd2dc091dc3f1679888f39f42f624790866b4245a859366b5e; original certificate, package/version/minSdk verified. Stable/versioned/JSON/buttons align; hosted deployment pending.
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
