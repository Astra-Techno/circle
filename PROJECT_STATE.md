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
- N1c1/N1c2 client source: strict scoped envelopes, lazy Android SDK, saved supported-category settings with explained consent/quiet hours/IANA timezone, encrypted durable handoff, authorized foreground banners and validated internal View/tap routes. Client flag remains false; live APK remains build8.
- Auth requests carry login generations; device/logout requests pin their original session. Stale refresh/401/403/logout cannot overwrite or clear later logins in focused regressions. Serialized token persistence preserves ordering; Firebase remains optional.
- Current Flutter: 546 passed / 1 skipped / 13 existing Windows-baseline golden failures; plus the subsequently added real-controller regression passes. Latest settings/controller run: 7 passed; focused auth/UI captures: 18 passed. Format/analyze clean; baselines unchanged.
- UI inspected at 320px/900px, light/dark, 200% text; permission cancel/continue, paused delayed settings and IANA DST checks pass. Static review blockers fixed and rechecked. No native-device/visual approval claimed.
- Android compile-only release succeeded (175.9s, production API, preview/push false), including Kotlin timezone/settings bridge; no APK publication/deployment in N1c2. Backend unchanged; prior 159 tests / 2,673 assertions and PHPStan evidence retained.
- Evidence: `docs/push-settings-checkpoint.md`, `docs/push-client-lifecycle.md`, `docs/notification-worker.md`. Primary `/workspace/circle` still preserves original WIP; do not reapply it.
- Next N1d: safe Android background/terminated processing, native channels/taps and real-device delivery/permission acceptance before enabling flags. Hosting cron/credentials/retention and reaction/group/later-family hooks remain open. Profile/native/Windows golden acceptance remains owner/device work.

## Validation commands
- Mobile: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, focused `flutter test test/<relevant_test>.dart`; required broader suite at integration/release.
- Backend: `composer test` against dedicated `circle_test` only; `composer analyse`.
- Release: inspect APK package/version/certificate, compute size/SHA-256, align both APK paths/metadata/site links, verify hosted bytes after authorized deployment.
- Cloud toolchain helper, when present: `/workspace/toolchain/mobile-env`. Local machines use their configured SDKs; do not copy cloud-only paths blindly.
