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

## Current source checkpoint (not a deployed release)
- Working checkout: `/workspace/circle-docs-sync`, main; primary `/workspace/circle` still preserves original WIP. Do not reapply that old patch to integrated source.
- B1/B2 integrated in fd3a327: private profiles, session guards, migration 008 and truthful capability gates. Profile visual/native/live acceptance and coherent APK publication remain open.
- N1a complete in source: strict session-bound devices/logout cleanup, migration 009, owner-only persistent opt-in categories/quiet hours, sender policy filtering and typed client API; OpenAPI 0.3.4. Push/settings UI remain gated.
- Backend full suite: 143 tests / 2,222 assertions passed on circle_test; final focused foundation suite after added DST cases: 8 tests / 125 assertions passed; PHPStan clean.
- Flutter full suite: 513 passed / 1 skipped / 13 existing golden failures. Focused auth/profile/design/API: 28 passed; final preference API checks: 5 passed. Analysis/format clean.
- Windows golden approval, native picker/push, hosted profile checks and new APK publication remain unresolved. No deployment/build in this batch.
- Evidence: `docs/integration-checkpoint.md`, `docs/push-foundation.md`. Static frontend/backend contract review completed; 306 OpenAPI references resolve.
- Next N1b: durable notification outbox/worker and provider retry/deduplication; then SDK lifecycle/contextual opt-in and foreground/tap handling. Each feature's eligible events join this pipeline before enablement.

## Validation commands
- Mobile: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, focused `flutter test test/<relevant_test>.dart`; required broader suite at integration/release.
- Backend: `composer test` against dedicated `circle_test` only; `composer analyse`.
- Release: inspect APK package/version/certificate, compute size/SHA-256, align both APK paths/metadata/site links, verify hosted bytes after authorized deployment.
- Cloud toolchain helper, when present: `/workspace/toolchain/mobile-env`. Local machines use their configured SDKs; do not copy cloud-only paths blindly.
