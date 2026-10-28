# CIRCLE project state

Updated:28 October2026. Source, deployment, APK and physical acceptance are separate facts.

## Rules and architecture
- Active checkout /workspace/circle, main only. Preserve current3D design, floating dock, immutable download strategy and previous build19. AGENTS.md/README§0 govern privacy, optional push, signing and release checks.
- Flutter/Riverpod/go_router and PHP/MySQL; OpenAPI docs/api-contracts/openapi.yaml0.4.1.92 unique operations/514 local references resolved. Previous missing environment WIP is not implemented.

## Current implementation
- Existing auth/groups/Memories/private media/reporting and direct-contact blocking retained. Chats and Events are real services, enabled separately from unsupported rich previews.
- Exact-group/direct text chats, requests, frozen version history, reply/edit/unsend/Undo/reactions, read/unread/mute/pin/archive, private selected-message reports and recipient messaging policy. Session-scoped encrypted pending sends retry only while Chats is active.
- Events create/edit/cancel, IANA/UTC times, place/HTTPS link, capacity/deadline, RSVP/guests/private own notes/attendees and current group event-creation policy.
- Migrations017–020 add core services and generic notifications/reminders with access/session/preference/quiet-hours/version rechecks; current-member/late-device reminder scanning uses existing worker cron.
- Migration021 adds up to four private JPEG/PNG/WebP chat photos with optional captions/replies; accepted direct requests required. Ownership/exact conversation, immutable retries, frozen cutoff and unsend/Undo enforced server-side. Private inline zoom; no public media URLs/original metadata.
- Event organizer/exact admin add/change/remove cover; version/role/session checked after processing. Covers appear in list/detail; edits refresh notification/reminder references. Existing media-cleanup cron removes orphan assets older than24h.
- Video/document attachments, forwarding/sharing, activity indicators, search, polls/cohosts/albums and broader profile-field privacy/deletion/export/recovery remain separate work. See docs/live-chat-events.md.

## Validation
- Full backend218 tests/3,932 assertions pass; PHPStan/composer validation clean.
- Full Flutter709 passed/1 skipped/13 known Windows-baseline golden mismatches, no functional failures. Final30 focused tests plus12 media tests pass; analyzer/format/design guard clean. Eight new light/dark phone/tablet200% media renders captured, representative layouts inspected.
- Signed production APK build succeeds. No Android device attached; installation/native picking/two-phone access/actual push/reminder acceptance remain owner checks.

## Release/deployment
- Candidate1.0.19+20 built/verified locally;65,851,130 bytes; SHA2562839ded341bf5b35e8111ee1206c99c9fa4dbb17dd6456eec4e06de2c6d5122f. Package com.circlecommunity.mobile/minSdk24/targetSdk36, non-debuggable, production API/previewfalse/pushtrue.
- Owner explicitly approved generating a new dedicated signing key and reinstall. Verified certificate SHA256157579dd08f44d8aebe9bc5b6e53e778d8ca642d97233d15c206f8f5185df01e. Build18/19 cannot update in place; uninstall clears local app data, server data remains. Future builds must reuse this key.
- Private key under /workspace/toolchain/signing; owner-only backup /workspace/circle-signing-backup-2026-10-28.zip is outside Git/public downloads. Owner must save privately outside this temporary workspace. key.properties is ignored; release no longer silently uses a generated debug key.
- New immutable APK/download metadata/both site links agree; previous immutable19 hash unchanged. Deployer still skips APK binaries; downloads/download.php and directory rewrite provide a checked exact-current-version repository fallback.
- No production deployment in this batch. Live domain CONNECT tunnel is denied by environment proxy403, including an escalated read-only check. Owner must run existing hosted deployment link to apply017–021/update pages. Hosted metadata/full APK checksum and live services remain unverified here.

## Environment and next checks
- Source /workspace/toolchain/mobile-env: Flutter3.44.8/Dart3.12.2, writable caches/analyzer and localhost no_proxy; restored full JDK21, SDK platforms34/35/36, build-tools36, NDK28.2/CMake3.22.1. Android tooling/packages checksum-verified from official sources.
- Backend: PATH=/workspace/toolchain/bin:$PATH; source /workspace/toolchain/test-env without printing secrets. Test only circle_test, one suite at a time. Existing environment setup draft still needs user publication; signing backup must not be committed or added to public setup scripts.
