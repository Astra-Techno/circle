# CIRCLE project state

Updated: 27 October 2026. This file is a short handoff, not a substitute for inspecting Git status.

## Architecture and scope
- Flutter/Riverpod/go_router; shared UI tokens in `mobile/lib/core/`.
- PHP 8.3+/MySQL API; contract `docs/api-contracts/openapi.yaml`.
- Implemented server core: auth, nested groups/membership/invites, Memories/comments/reactions/saves, private Memory photos and scoped search/pagination.
- Preview implementations do not establish live chat/events/albums/moderation or push preference enforcement.

## Repository versus live release
- Owner-requested installation APK 1.0.7+8 is committed/pushed/deployed in 1bba092: production API, preview/push disabled, original beta signing certificate verified. Package details: `docs/mobile-release-1.0.7.md`.
- Stable/new immutable APKs and both site buttons/metadata align; 63,359,206 bytes, SHA-256 `cf55a769270c28266c0025f1a680f60dc6a57e1fd6e88e437b31e7af241cb157`. Earlier immutable artifacts retained.
- Deployment succeeded (67.9s; migrations 008–010 reported without errors). Full hosted SHA-256 of both APKs, metadata, both site buttons and API health verified. Physical install/profile checks remain owner verification.

## Current work and priorities
- Canonical backlog and acceptance criteria: `docs/pending-work.md`.
- Next batch B1–B5: preserve/integrate profile work; truthful capability gates; optional/safe Firebase; complete profiles; correct signing and coherent release.
- Full push delivery may stay disabled until its own acceptance checks pass. No new live chat/events/albums family in this batch.
- Owner approved sequential backlog execution: real push foundation; safety/privacy/account controls; restore live Chats; restore live Events; polls; albums. Core reliability/accessibility stays tracked.
- Cross-feature push is required for relevant recipient-facing events; matrix and delivery/privacy/device acceptance are in the canonical backlog. No notifications for every tap/private edit.
- Do not start another implementation batch before recording which acceptance criteria it owns.

## Current source checkpoint (not a deployed release)
- Working checkout: `/workspace/circle-docs-sync`, main; primary `/workspace/circle` still preserves original WIP. Do not reapply that old patch to integrated source.
- B1/B2 integrated in fd3a327: private profiles, session guards, migration 008 and truthful capability gates. Profile visual/native/live acceptance remains open; owner-requested build8 is packaged for installation testing.
- N1a (265fcd2) and N1b complete in source: session-safe devices/preferences plus migration 010 transactional Memory/comment/reply outbox, injectable FCM transport and bounded CLI worker. OpenAPI 0.3.5. Capture/delivery/settings UI remain off; worker is Android-only.
- Backend full suite: 159 tests / 2,673 assertions passed on circle_test; focused queue/policy: 24 tests / 573 assertions passed; PHPStan and Composer validation clean.
- N1c1/N1c2 source in 9fa0625: scoped envelopes, saved supported-category settings, explained consent/quiet hours/timezones and authorized foreground/tap handling. Client defaults remain false; stable live APK remains build8.
- N1d source adds shared foreground/headless native display/dedup/cancellation, a process mutex for encrypted ledger transactions, read-only background API authorization with no real credential refresh/write, and encrypted persistent native tap handoff/acknowledgement. Scope switching preserves other sessions' bounded pending entries until expiry.
- Android invite sharing source: WhatsApp/Business recipient chooser; SMS system single-number picker or manual composer; system share; HTTPS fragment invite browser fallback. No contacts enumeration/upload or automatic sending. Rechecks current viewer/API/session/link before external composition; preview stays isolated.
- Current Flutter: 580 passed / 1 skipped / 13 existing Windows-baseline golden failures; final sharing/real-route/design subset 22 passed (includes an API-instance test added after full run). Format/analyze clean; four static browser script cases pass. No native-device approval claimed.
- Test build 1.0.9+10 compiled (96.8s), original beta certificate verified; merged manifest contains no READ_CONTACTS/WRITE_CONTACTS/SEND_SMS. 64,785,682 bytes, SHA-256 9f3b2507f350be8f3c8a93b03d5f67fc40d5fcea76122317963dd683e4a35f13. Separate candidate published in e909649; deployment succeeded (85.9s). Complete hosted APK hash, invite HTML, candidate/stable/build9 metadata and stable buttons verified; API healthy. Stable build8 and immutable push-test build9 untouched.
- Owner confirmed hosting configuration ready and willingness to test an APK. No Android device is attached and private hosting sender/cron cannot be inspected here. Actual provider acceptance, device delivery/permission/channel/cold-tap results are pending; do not mark push verified yet.
- Evidence: `docs/contact-invite-sharing.md`, `docs/mobile-invite-test-build10.md`, `docs/push-device-acceptance.md`. Backend files/contracts unchanged; prior 159 tests / 2,673 assertions and PHPStan evidence retained.
- Next: complete build10 contacts/composer and push device/hosting checks, then stable enablement only after acceptance. Reaction/group hooks and later feature families remain tracked. Profile/native/Windows golden acceptance stays open. Primary `/workspace/circle` still preserves original WIP; do not reapply it.

## Validation commands
- Mobile: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, focused `flutter test test/<relevant_test>.dart`; required broader suite at integration/release.
- Backend: `composer test` against dedicated `circle_test` only; `composer analyse`.
- Release: inspect APK package/version/certificate, compute size/SHA-256, align both APK paths/metadata/site links, verify hosted bytes after authorized deployment.
- Cloud toolchain helper, when present: `/workspace/toolchain/mobile-env`. Local machines use their configured SDKs; do not copy cloud-only paths blindly.
