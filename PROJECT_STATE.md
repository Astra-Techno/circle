# CIRCLE project state

Updated: 26 October 2026. This file is a short handoff, not a substitute for inspecting Git status.

## Architecture and scope
- Flutter/Riverpod/go_router; shared UI tokens in `mobile/lib/core/`.
- PHP 8.3+/MySQL API; contract `docs/api-contracts/openapi.yaml`.
- Implemented server core: auth, nested groups/membership/invites, Memories/comments/reactions/saves, private Memory photos and scoped search/pagination.
- Preview implementations do not establish live chat/events/albums/moderation or push preference enforcement.

## Repository versus live release
- Recent runtime commits: `374e02f` Firebase infrastructure/feature flags; `8c1f677` stable APK replacement.
- Review found incompatible APK signing, reused build7 and inconsistent stable/versioned artifacts/metadata. Fix before another runtime release; README §0.4–0.5.
- Last read-only live check still identified the previously verified 1.0.6+7 artifact: 63,085,188 bytes, SHA-256 `8ab534bd2aa0b33cce92d3ee9d091549567062d11944d02bcaeb52ba47a9c15a`.
- Recheck current Git and hosted metadata before assuming deployment state has changed.

## Current work and priorities
- Canonical backlog and acceptance criteria: `docs/pending-work.md`.
- Next batch B1–B5: preserve/integrate profile work; truthful capability gates; optional/safe Firebase; complete profiles; correct signing and coherent release.
- Full push delivery may stay disabled until its own acceptance checks pass. No new live chat/events/albums family in this batch.
- Owner approved sequential backlog execution: real push foundation; safety/privacy/account controls; restore live Chats; restore live Events; polls; albums. Core reliability/accessibility stays tracked.
- Cross-feature push is required for relevant recipient-facing events; matrix and delivery/privacy/device acceptance are in the canonical backlog. No notifications for every tap/private edit.
- Do not start another implementation batch before recording which acceptance criteria it owns.

## Last checks on remote `8c1f677` (not proof of current/live behavior)
- Backend: 129 tests / 1,959 assertions passed on dedicated `circle_test`; PHPStan failed with 10 errors, including nonexistent `Log::info()`.
- Flutter analysis passed; focused server flows: 3 passed / 8 failed, chiefly Firebase initialization/injection and capability expectations.
- Known 13 Windows golden differences need platform/human review; do not replace baselines on Linux.
- Native push delivery/device validation remains unverified.

## Validation commands
- Mobile: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, focused `flutter test test/<relevant_test>.dart`; required broader suite at integration/release.
- Backend: `composer test` against dedicated `circle_test` only; `composer analyse`.
- Release: inspect APK package/version/certificate, compute size/SHA-256, align both APK paths/metadata/site links, verify hosted bytes after authorized deployment.
- Cloud toolchain helper, when present: `/workspace/toolchain/mobile-env`. Local machines use their configured SDKs; do not copy cloud-only paths blindly.
