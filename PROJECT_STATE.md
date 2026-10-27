# CIRCLE project state

Updated: 27 October 2026. Inspect Git status; source, deployment and physical acceptance are distinct.

## Architecture and rules
- Flutter/Riverpod/go_router, shared Warm Keepsake tokens in mobile/lib/core; PHP8.3+/MySQL, OpenAPI docs/api-contracts/openapi.yaml.
- Main only; preserve unrelated work. Active checkout /workspace/circle-docs-sync. Original /workspace/circle retains old WIP; do not reapply it.
- AGENTS.md/README §0 govern verification, privacy, optional push, established signing and coherent immutable downloads.
- Live core: auth, private profiles/media, nested groups/membership/invites, Memories/comments/reactions/saves/search. Chats/events/albums remain isolated previews pending service batches.

## Current batch
- Person-avatar sweep released in build15: Memories/comments/member lists/search/mentions use stable person IDs, private bytes, bounded session cache and version invalidation. Member lists paginate30. See docs/person-avatar-audit.md.
- Group pictures/banners: OpenAPI0.3.10, migration014 group_photos. Owner/admin add/replace/remove independently; exact members read private bytes. Parent-only/discovery/invite access grants no photo permission.
- Group detail has edit controls, banner/avatar and Refresh group photos; group pictures appear in lists/search/groups in common. Reuses shared tokens and existing picker; no new permission/dependency. No routine photo-edit push.
- Captured API/account/session/group guards span sheet/picker/request; backend rechecks current admin/session under locks before commit. Invalid/failed/lost-permission uploads preserve old photos and purge staging. Metadata stripped; no public paths/originals.

## Validation
- Dedicated circle_test196 tests/3,286 assertions, PHPStan and composer validation clean. Covers exact authorization, independent lifecycle, invalid/unavailable/failing processor and permission loss during processing.
- Final focused photo/design20 passed; analyzer/format clean. Final full Flutter659 passed/1 skipped/13 known Windows-baseline golden failures; no functional failures. Approved goldens unchanged.
- Four group phone/tablet light/dark200% renders inspected; no overflow. Contract361 references resolve/60 unique operationIds; frontend/backend mapping/session/permission review complete.
- No attached Android device. Native picker, installation, actual push and two-phone photo visibility remain owner acceptance.

## Release versus live
- Previously verified live: Android1.0.14+15, source6f74bac/proofbef98f9;65,211,890 bytes SHA2564b154b4a3f1ddacd2dc091dc3f1679888f39f42f624790866b4245a859366b5e. Stable/versioned/JSON/both buttons align.
- Current group-photo candidate1.0.15+16 packaged: 65,244,718 bytes, SHA2566fcd6afd16ddf5cf5e4bba9c677555de7c9844ee00c525e7f728121e8b63dc45; not yet claimed pushed/deployed. See docs/mobile-release-1.0.15.md and docs/group-photos.md for final artifact/hosted evidence.
- Required certificate SHA2566c78be13d88b19587e4c37edb9012e3f2eb37fee34f6850084dd069d78f9b66c; production API/previewfalse/client pushtrue. Candidate certificate matches immutable build15; package/versionCode16/minSdk24/targetSdk36 verified. Build153s.
- Deployer preserves hosted .env, private storage, PHP handlers and deploy.php itself. Migration014 must deploy with this batch.

## Remaining acceptance and next work
- Owner confirmed private sender/cron ready and can test APK. Real Android update, native location/geocoder/permissions, two-device logout/password re-login, contacts/composers, photo display and actual push/tap results remain pending.
- Sequential backlog and notification matrix: docs/pending-work.md. Safety/privacy, live Chats, live Events, polls/albums follow in verified batches.
- Prior evidence: docs/contact-invite-sharing.md, docs/push-device-acceptance.md, docs/password-change-foundation.md.

## Commands
- Source /workspace/toolchain/mobile-env; dart format/flutter analyze and focused/full flutter test. Never run Flutter test tooling during APK build.
- Backend composer test only against circle_test; composer analyse. Source toolchain/test-env when present; never print secrets.
- Verify package/version/certificate/hash/bytes; align stable+immutable APK/JSON/both buttons, then verify complete hosted bytes. Preserve earlier immutable APKs.
