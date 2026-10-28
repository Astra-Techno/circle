# CIRCLE project state

Updated:28 October2026. Source, deployment, APK and physical acceptance are separate facts.

## Rules and architecture
- Active checkout /workspace/circle, main only. Current base0770004 includes build19/download/deploy fixes and earlier3D design changes; preserve them. Previous /workspace/circle-docs-sync WIP is absent in this refreshed environment.
- AGENTS.md/README§0 govern scope, privacy, optional push, test/release integrity. Flutter/Riverpod/go_router and PHP/MySQL; OpenAPI docs/api-contracts/openapi.yaml.
- Prior core auth/groups/Memories/private media/reporting/direct-contact blocking remains included. Profile-field privacy, deletion/export/recovery are not implemented by this batch.

## Current source — live Chats and Events
- OpenAPI0.4.0; migrations017 chat,018 events,019 private direct reports,020 fair reminder scanning.87 operations/489 local references validated.
- Exact-group and consent-based direct text chats; replies, idempotent sends, bounded history, receipts/unread/mute/pin/archive, edit15min, unsend/Undo, reactions/clear. Frozen message versions prevent later text/edits leaking after removal; rejoin restores access.
- Direct messaging respects shared membership, blocks and persistent recipient policy. One introduction waits for acceptance. Selected direct-message reports go only to private operator CLI; never a group-admin queue.
- Encrypted pending sends are capped/session-scoped, persist across same-session restarts and retry only while Chats is active. Rejected sends need review; logout prevents stale replay.
- Events create/edit/cancel, type/details/place/HTTPS link, IANA/UTC times, RSVP/guests/private own notes/capacity/deadline/attendees. Group creation policy and optimistic event versions enforced.
- Chat/event generic push, safe taps, categories, recipient/session/current-access checks; one-hour reminders include late devices/current members and cancel obsolete versions. Native delivery still needs device acceptance.
- Current visual tokens/dock preserved; selected preview actions now scroll into view. Richer attachment/cover/forward/share/activity/search/poll/cohost/album extensions remain gated. See docs/live-chat-events.md and ADR0008.

## Validation
- Full backend214 tests/3,832 assertions pass; final label/security/invitation/notification regression41 tests/961 assertions pass. PHPStan and composer validation clean.
- Final full Flutter705 passed/1 skipped/13 known Windows-baseline golden failures; no functional failures. New lifecycle/report/outbox/layout26 focused tests pass; analyzer/format clean. Forwarding regression fixed.
- Twelve new light/dark phone/tablet200% renders captured; representative layouts inspected. No Android device attached.

## Release/deployment
- Verified source batch ready to commit/push; no production deployment or APK rebuild in this step. Current repository1.0.18+19:65,277,758 bytes SHA2563c844920fe94fd0f5a17efc5e6bb13c8dc42f9d1760d7efdf50e36cef4d24506.
- Build19 certificate SHA256e38a9bf147b621ee468a1abdda916239663810346aa9f104c956e089bbebbf61 differs from earlier build18. Matching installed-app key/Android SDK are absent here; never generate a replacement or call this APK-ready.
- Last previously verified live18 evidence remains docs/mobile-release-1.0.17.md; current hosted build19 was not verified in this source task. Deployer on main skips APK binaries.

## Environment and next checks
- Restored Flutter3.44.8/Dart3.12.2: source /workspace/toolchain/mobile-env. no_proxy/NO_PROXY must include local addresses for Flutter test WebSockets; XDG/analyzer overrides keep caches writable. Setup/start draft saved; publication of that environment draft remains user action.
- Backend: export PATH=/workspace/toolchain/bin:$PATH; source /workspace/toolchain/test-env without printing secrets; composer test only against circle_test, one suite at a time. composer analyse/validate. Local dev migrations and operator CLI checked; API health healthy.
- Native/two-phone consent, block/mute/quiet hours, frozen history, offline/restart recovery, actual push/taps and RSVP/reminders remain pending. Backlog in docs/pending-work.md.
