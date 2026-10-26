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

## Current source integration checkpoint (not a deployed release)
- Working checkout: `/workspace/circle-docs-sync`, branch main; primary `/workspace/circle` remains preserved with its original unfinished edits. Do not blindly reapply that patch to the integrated source.
- B1 integrated routes/profile/session guards, serialized profile writes and migration 008; B2 gates corrected. Core Firebase failures isolated; full push remains disabled and unfinished.
- Backend: 134 tests / 2,093 assertions passed on circle_test; separate FCM invalid-token classification test: 1 test / 7 assertions passed; PHPStan clean.
- Flutter: format/analyze clean; broader suite 507 passed / 1 skipped / 13 golden failures; additional photo lifecycle widget test passed. Focused auth/profile flows: 27 passed (included in broader count).
- The 13 golden failures match previously recorded Windows-baseline cases; approval remains unresolved, baselines unchanged. Native picker/push, hosted profile checks and new APK publication remain unverified.
- See `docs/integration-checkpoint.md` for exact scope and remaining acceptance checks. No new APK built or deployment triggered.

## Validation commands
- Mobile: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, focused `flutter test test/<relevant_test>.dart`; required broader suite at integration/release.
- Backend: `composer test` against dedicated `circle_test` only; `composer analyse`.
- Release: inspect APK package/version/certificate, compute size/SHA-256, align both APK paths/metadata/site links, verify hosted bytes after authorized deployment.
- Cloud toolchain helper, when present: `/workspace/toolchain/mobile-env`. Local machines use their configured SDKs; do not copy cloud-only paths blindly.
