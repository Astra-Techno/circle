# CIRCLE project state

Updated: 27 October 2026. Inspect Git status; source, deployment and physical acceptance are distinct.

## Architecture and rules
- Flutter/Riverpod/go_router, shared Warm Keepsake tokens in mobile/lib/core; PHP8.3+/MySQL, OpenAPI docs/api-contracts/openapi.yaml.
- Main only; preserve unrelated work. Active checkout /workspace/circle-docs-sync. Original /workspace/circle retains old WIP; do not reapply it.
- AGENTS.md/README §0 govern verification, privacy, optional push, established signing and coherent immutable downloads.
- Live core: auth, private profiles/media, nested groups/membership/invites, Memories/comments/reactions/saves/search. Chats/events/albums remain isolated previews pending service batches.

## Current batch — S2a reports/moderation
- OpenAPI0.3.11/migration015: persistent Memory/comment/member reports; private paginated exact-admin queue, hide/restore, dismiss/Undo and recent admin audit. No reporter accounts/notes/report-row ids/mobiles in admin responses or push.
- Hidden Memories disappear from ordinary reads/Saved/search/actions and existing signed photos; hidden comments suppress descendant branches/counts/replies. Independent child hides survive parent restore; deleted content/assets never resurrect.
- Versioned actions and captured API/account/session scopes; server locks recheck active user/session/exact admin.10 new reports/account/hour, duplicates safe. Parent membership grants no access.
- Generic group.report admin alerts respect groups opt-in/quiet hours and current admin/session/access through capture/sender/foreground/headless/tap; no reporter/content/notes in payload. Actual native delivery remains pending.
- Global blocking, DM/profile privacy, deletion/export/retention, recovery, platform escalation and unsupported subgroup/chat/event reports remain later batches; privacy capability gates stay closed. See docs/safety-reporting.md.
- Previous build15 person-avatar sweep and build16 private group picture/banner controls remain included; photos need no re-upload. See docs/person-avatar-audit.md and docs/group-photos.md.

## Validation
- Dedicated circle_test201 tests/3,466 assertions, PHPStan/composer validation clean. Covers limits/privacy/exact roles/duplicate/stale actions/removed sessions, nested comments, signed media and admin-alert demotion cancellation.
- Final full Flutter676 passed/1 skipped/13 known Windows-baseline golden failures; no functional failures. Final focused UI/push/design28 passed; format/analyze clean. Approved goldens unchanged.
- Four report light/dark phone/tablet200% renders inspected. Contract377 references/63 unique operations verified; backend/frontend mapping and authorization reviewed.
- No attached Android device. Native picker/install, actual push/taps and two-phone privacy/photo visibility remain owner acceptance.

## Release versus live
- Current safety candidate1.0.16+17 packaged: 65,261,102 bytes SHA2565da05df9bf69bccf781fcb293a7a4c36bad484ad999e3abdfc36d93eb2d61c35; not yet claimed pushed/deployed. See docs/mobile-release-1.0.16.md.
- Previously verified live release: Android1.0.15+16, source4aeef59;65,244,718 bytes SHA2566fcd6afd16ddf5cf5e4bba9c677555de7c9844ee00c525e7f728121e8b63dc45. Stable/versioned/JSON/both buttons align; earlier immutable APKs preserved.
- Pushed/deployed successfully:158.0s response/155.7s script; migration014 applied. Full hosted stable/versioned hashes match, including plain circle.apk without cache-busting; no-store stable and long-lived immutable cache headers verified. API healthy; private person/group avatar/cover reads reject unauthenticated access.
- Established certificate SHA2566c78be13d88b19587e4c37edb9012e3f2eb37fee34f6850084dd069d78f9b66c matches build15; package/versionCode16/minSdk24/targetSdk36 verified. Production API/previewfalse/client pushtrue; build153s. AOT includes group-photo and person-avatar code.
- Deployer preserved .env/private storage/PHP handlers/deploy.php. Native/two-phone acceptance pending; existing person photos need no re-upload. Details: docs/mobile-release-1.0.15.md, docs/group-photos.md.

## Remaining acceptance and next work
- Owner confirmed private sender/cron ready and can test APK. Real Android update, native location/geocoder/permissions, two-device logout/password re-login, contacts/composers, photo display and actual push/tap results remain pending.
- Sequential backlog and notification matrix: docs/pending-work.md. Safety/privacy, live Chats, live Events, polls/albums follow in verified batches.
- Prior evidence: docs/contact-invite-sharing.md, docs/push-device-acceptance.md, docs/password-change-foundation.md.

## Commands
- Source /workspace/toolchain/mobile-env; dart format/flutter analyze and focused/full flutter test. Never run Flutter test tooling during APK build.
- Backend composer test only against circle_test; composer analyse. Source toolchain/test-env when present; never print secrets.
- Verify package/version/certificate/hash/bytes; align stable+immutable APK/JSON/both buttons, then verify complete hosted bytes. Preserve earlier immutable APKs.
