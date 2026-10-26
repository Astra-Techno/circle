# CIRCLE project state

Updated: 26 October 2026. This file is a short handoff, not a substitute for inspecting Git status.

## Architecture and scope
- Flutter/Riverpod/go_router; shared UI tokens in `mobile/lib/core/`.
- PHP 8.3+/MySQL API; contract `docs/api-contracts/openapi.yaml`.
- Implemented server core: auth, nested groups/membership/invites, Memories/comments/reactions/saves, private Memory photos and scoped search/pagination.
- Preview implementations do not establish live chat/events/albums/moderation or push preference enforcement.

## Repository versus live release
- Owner requested an installation-check APK: candidate 1.0.7+8, production API, preview/push disabled, original beta signing certificate verified. Package details: `docs/mobile-release-1.0.7.md`.
- Stable/new immutable APKs and both site buttons/metadata align; 63,359,206 bytes, SHA-256 `cf55a769270c28266c0025f1a680f60dc6a57e1fd6e88e437b31e7af241cb157`. Earlier immutable artifacts retained.
- Hosted metadata was build7 before this packaging task. Publishing/deployment verification is recorded separately; local packaging alone is not live availability.

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
- This backend-only batch: Flutter format/analyze clean and 11 server-mode checks passed. Prior full Flutter run: 513 passed / 1 skipped / 13 existing golden failures; no baselines changed or new visual approval claimed.
- Windows golden approval, native picker/push and hosted profile behavior remain unresolved. Build8 passed 17 focused profile/UI checks and APK identity checks; hosting verification follows the artifact push.
- Evidence: `docs/integration-checkpoint.md`, `docs/push-foundation.md`, `docs/notification-worker.md`. Scoped contract/worker review found no blockers; 306 OpenAPI refs and minimal envelope schema fixtures validated.
- Next N1c: SDK lifecycle/contextual opt-in UI, trusted origin/account/session/expiry validation and scoped deduplication; then authorized foreground/tap behavior and device checks. Reaction/group hooks and remaining families stay tracked; hosting cron/credentials/retention require verification before enablement.

## Validation commands
- Mobile: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, focused `flutter test test/<relevant_test>.dart`; required broader suite at integration/release.
- Backend: `composer test` against dedicated `circle_test` only; `composer analyse`.
- Release: inspect APK package/version/certificate, compute size/SHA-256, align both APK paths/metadata/site links, verify hosted bytes after authorized deployment.
- Cloud toolchain helper, when present: `/workspace/toolchain/mobile-env`. Local machines use their configured SDKs; do not copy cloud-only paths blindly.
