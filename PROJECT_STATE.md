# CIRCLE project state

Updated:29 October2026. Source, production deployment, APK publication and device acceptance are separate facts.

## Current base and rules
- Active checkout /workspace/circle, main only. Pulled1d0f298 (notification defaults on); first partial settings save currently disables them again. See docs/review-notification-defaults.md. Safely pulled87912e1/399cd9d while preserving unfinished poll work. Editorial, photo-first supersedes older3D styling; preserve flat core tokens, pinned chat/RSVP controls and current navigation. See AGENTS.md/README§0/design-system.md.
- Existing auth/groups/Memories/private media/reporting/blocking, live Chats/photos and Events/covers retained. Earlier missing profile-privacy WIP remains unimplemented.
- OpenAPI0.4.2:99 operations/549 local references validated. Migration022 extends existing poll tables and durable notification outbox; do not change applied migrations.

## Live poll core
- Group/event poll list/create/detail,2–12 options, single/multiple choice, named/anonymous votes, optional close time, changeable/locked votes, member-added options, creator/exact-admin close and bounded named voter lists. Results always/after own vote/after close; hidden counts omitted and anonymous identities never exposed through API.
- Stable create ids/canonical hashes, atomic vote replacement and group/poll/current-session locks. Recovered hardening uses current locked reads and bounded retries for MariaDB snapshot/deadlock conflicts; two-connection regression coverage passes. Same-group context checks; parent-only/removed members and hidden/removed Memory contexts denied. Audience names shown. Expiry enforced without cron.
- Entry: Group→Memories→Polls; group chat→Group polls; event detail→Event polls. Separate livePolls capability; legacy preview poll repositories stay isolated. Inline Memory-poll UI, direct-chat polls and structured date slots remain later extensions.
- Notification-default policy changed in1d0f298; prior opt-in contract/docs need alignment. Polls category; generic creation alerts and closing alerts to other current voters/creator, no per-vote notifications. Worker and foreground/headless/taps recheck scope, current access/state, preferences/devices/sessions/quiet hours. Existing worker cron captures expired close once. No new cron.
- Other backlog: video/documents, forwarding/sharing, activity/search, albums, broader profile-field privacy/deletion/export/recovery. See live-polls.md/live-chat-events.md/pending-work.md.

## Verified checks
- Earlier full backend224 tests/4,074 assertions pass; recovered poll hardening now8 tests/178 assertions and PHPStan pass. Latest default-on commit leaves2 opt-in test assertions failing and a confirmed first-save settings regression; branch is not fully green. Initial full run hit Composer300s; rerun completed with900s limit, one circle_test suite at a time.
- Full Flutter729 passed/1 skipped/13 Windows-baseline golden mismatches; no functional failures. Final36 poll/chat/event/design tests pass; analyzer/format clean. Eight poll light/dark phone/tablet200% renders captured, representative layouts inspected. No Windows baseline regenerated here.
- Missing-key native dry-run rejected unsigned release with intended error; private properties restored before real build. After tests use normal Flutter build tooling, without --no-pub, to regenerate release-only plugin registration.
- No physical Android device attached; installation, native picking, two-phone voting and actual push/taps/reminders remain owner acceptance checks.

## Signing and APK
- Pulled build21 SHA256daaae50082e21f0c35a40e0300b84869239d1ffcabfe8c43efafc4af4b411ab5 matches metadata but apksigner DOES NOT VERIFY (Missing META-INF/MANIFEST.MF). Build20 passes v2; do not trust metadata alone or overwrite21.
- New1.0.21+22 signed APK verified:65,933,294bytes, SHA256c57ecc1eb8945309bace68d4b0517fe35a63b2f820345250c4a109f346751a0d. Package com.circlecommunity.mobile/versionCode22/minSdk24/targetSdk36/non-debuggable; production API/previewfalse/pushtrue.
- Same established build20 certificate157579dd08f44d8aebe9bc5b6e53e778d8ca642d97233d15c206f8f5185df01e; build20 can update without reinstall. Release now fails when private signing configuration is absent. Old-key installations still require reinstall.
- Key/passwords outside Git under /workspace/toolchain/signing; owner backup /workspace/circle-signing-backup-2026-10-28.zip remains private and must be saved outside this temporary environment. Never generate a replacement or publish this backup.
- Immutable APK22, metadata and both download buttons agree; previous20/21 bytes unchanged. Deployer still skips APK binaries; existing directory rewrite/download.php serves checked current-version repository fallback. See mobile-release-1.0.21.md for artifact/publication evidence.
- Owner reported previous deployment done. This new migration022/site update has not been deployed from here. Environment proxy denied live-domain CONNECT403; production metadata/full APK/API not verified. Run existing hosted deployment link before testing polls.

## Environment
- Source /workspace/toolchain/mobile-env: Flutter3.44.8/Dart3.12.2, full JDK21, SDK34/35/36/build-tools36/NDK28.2/CMake3.22.1, writable caches/analyzer, localhost no_proxy. Keep release builds separate from Flutter tests.
- Backend: PATH=/workspace/toolchain/bin:$PATH; source /workspace/toolchain/test-env without printing secrets. Only circle_test for tests; COMPOSER_PROCESS_TIMEOUT=900 for full suite. Setup draft publication remains user action; never include signing secrets in public setup scripts.
