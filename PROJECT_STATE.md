# CIRCLE project state

Updated: 26 October 2026. This file is a short handoff, not a substitute for inspecting Git status.

## Architecture and scope
- Flutter/Riverpod/go_router; shared UI tokens in `mobile/lib/core/`.
- PHP8.3+/MySQL API; contract `docs/api-contracts/openapi.yaml`.
- Implemented server core: auth, nested groups/membership/invites, Memories/comments/reactions/saves, private Memory photos and scoped search/pagination.
- Preview implementations do not establish live chat/events/albums/moderation or push preference enforcement.

## Repository versus live release
- Recent runtime commits: `374e02f` Firebase infrastructure/feature flags; `8c1f677` stable APK replacement.
- Review found incompatible APK signing, reused build7 and inconsistent stable/versioned artifacts/metadata. Fix before another runtime release; README §0.4–0.5.
- Last read-only live check still identified the previously verified1.0.6+7 artifact:63,085,188bytes, SHA256 `8ab534bd2aa0b33cce92d3ee9d091549567062d11944d02bcaeb52ba47a9c15a`.
- Recheck current Git and hosted metadata before assuming deployment state has changed.

## Current work and priorities
1. Preserve unfinished profile/banner/personal-details work in the cloud primary checkout; it is not yet committed to remote main. Another machine may not contain it.
2. Safely reconcile overlapping backend routes and session notifier changes; retain account/server guards and serialized profile mutations.
3. Correct signing/publication and unsupported capability gates.
4. Finish optional, session-scoped Firebase lifecycle, sender wiring, foreground display/tap navigation, privacy and tests.
5. Complete profile UI/API verification, then package a coherent update when requested.

## Last checks on remote8c1f677 (not proof of current/live behavior)
- Backend:129tests/1,959assertions passed on dedicated `circle_test`; PHPStan failed with10errors, including nonexistent `Log::info()`.
- Flutter analysis passed; focused server flows:3passed/8failed, chiefly Firebase initialization/injection and capability expectations.
- Known13Windows golden differences need platform/human review; do not replace baselines on Linux.
- Native push delivery/device validation remains unverified.

## Validation commands
- Mobile: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, focused `flutter test test/<relevant_test>.dart`; required broader suite at integration/release.
- Backend: `composer test` against dedicated `circle_test` only; `composer analyse`.
- Release: inspect APK package/version/certificate, compute size/SHA256, align both APK paths/metadata/site links, verify hosted bytes after authorized deployment.
- Cloud toolchain helper, when present: `/workspace/toolchain/mobile-env`. Local machines use their configured SDKs; do not copy cloud-only paths blindly.
