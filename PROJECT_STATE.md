# CIRCLE project state

Updated: 27 October 2026. Inspect Git status; source, deployment and physical acceptance are distinct.

## Architecture and rules
- Flutter/Riverpod/go_router, shared Warm Keepsake tokens in mobile/lib/core; PHP8.3+/MySQL, OpenAPI docs/api-contracts/openapi.yaml.
- Main only; preserve unrelated work. Active checkout /workspace/circle-docs-sync. Original /workspace/circle retains old WIP; do not reapply it.
- AGENTS.md/README §0 govern verification, privacy, optional push, established signing and coherent immutable downloads.
- Live core: auth, private profiles/media, nested groups/membership/invites, Memories/comments/reactions/saves/search and supported reporting/moderation. Chats/events/albums remain isolated previews pending service batches.

## Current batch — S2b direct-contact blocking
- Owner chose stop direct contact, keep shared-group content visible. OpenAPI0.3.12/migration016 add private outgoing state/list, block/unblock from shared profiles or received invitations.
- Stops direct Circle invitations and personal comment/reply alerts both ways; pending invitations expire and do not revive on unblock. No block/unblock alert or reverse-block list.
- Shared profiles/photos, Memories/Saved/search/comments/reactions, ordinary group updates, membership and moderation continue. No media-link or content-cache changes.
- Scoped dialogs/invitation cards and guarded actions; only blocking capability enabled. Broader privacy, deletion/export, recovery and live Chats/Events remain separate.

## Validation and release
- Dedicated circle_test206 tests/3,639 assertions; PHPStan/composer valid. Full Flutter684 passed/1 skipped/13 known Windows-baseline golden failures; analyzer clean. Final blocking/server-mode/design24 tests pass; format clean. Final APK rebuilt and deployed.
- Live1.0.17+18/sourcee071227:65,343,022 bytes SHA256539701a9ddbf8bb8e47dada3bb618ca98a4a0b08cd9065a5462eae59e7ef589b. Full hosted stable/immutable hashes, metadata/both buttons/cache verified. See docs/mobile-release-1.0.17.md.
- Previous immutable1.0.16+17: APK/source137ddc3, server3ce253f, proofee77090;65,261,102 bytes SHA2565da05df9bf69bccf781fcb293a7a4c36bad484ad999e3abdfc36d93eb2d61c35.
- Established certificate SHA2566c78be13d88b19587e4c37edb9012e3f2eb37fee34f6850084dd069d78f9b66c. Preserve immutable releases and hosting settings.
- Deployment176.0s response/173.9s script; migration016 applied. API healthy; private blocks/photos/reports unauth401. Hosting settings preserved.
- No attached Android device; actual installation and two-phone notification acceptance remain pending.

## Remaining acceptance and next work
- Owner confirmed private sender/cron ready and can test APK. Real Android update, native location/geocoder/permissions, two-device logout/password re-login, contacts/composers, photo display and actual push/tap results remain pending.
- Sequential backlog and notification matrix: docs/pending-work.md. Safety/privacy, live Chats, live Events, polls/albums follow in verified batches.
- Prior evidence: docs/contact-invite-sharing.md, docs/push-device-acceptance.md, docs/password-change-foundation.md.

## Commands
- Source /workspace/toolchain/mobile-env; dart format/flutter analyze and focused/full flutter test. Never run Flutter test tooling during APK build.
- Backend composer test only against circle_test; composer analyse. Source toolchain/test-env when present; never print secrets.
- Verify package/version/certificate/hash/bytes; align stable+immutable APK/JSON/both buttons, then verify complete hosted bytes. Preserve earlier immutable APKs.
