# Source integration checkpoint — 26 October 2026

This checkpoint begins the owner-approved sequential backlog; it does not complete all feature families or publish a new APK.

## Integrated scope

Preserved the dirty primary checkout at its original base. Saved a tracked binary patch and untracked-file snapshot separately, then applied that work with three-way reconciliation onto the current main-only checkout. Resolved both controller imports/routes and session overlap. Retained profile account/server epochs, stale-response checks and serialized mutations. Renamed the unshipped profile migration to 008, leaving existing device migration 007 intact. Account edit and photo-picker completions now check API identity as well as account id.

Profile contracts and ADR 0008 describe owner-only personal details and authenticated exact-common-group photo access. Private photo processing, cover/avatar controls and full profile editing are integrated. The original WIP must not be blindly applied a second time by another agent.

Unavailable server families are temporarily gated; Chats and Events are required delivery batches, not cancelled features. Firebase is no longer initialized or awaited by authentication. Startup initialization is disabled by default behind CIRCLE_PUSH_ENABLED; setting that switch does not establish functional delivery. The sender now uses static operational logging without provider payloads and classifies only structured FCM UNREGISTERED responses as invalid tokens. Automatic private notification content logging is removed. The unused delivery scaffold still requires replacement/completion during the notification foundation batch.

## Validation

- Backend composer test on dedicated circle_test: 134 tests, 2,093 assertions passed.
- Added FCM error classification regression, run separately after the backend suite: 1 test, 7 assertions passed. Project 404, malformed/untyped responses and other status codes do not trigger token deletion.
- Backend composer analyse: clean, including the previously failing sender.
- Dart format: 169 files checked, no changes; Flutter analyze: clean.
- Focused profile, server authentication and design guard suite: 27 passed.
- Broader Flutter run (`flutter test --exclude-tags golden`): 507 passed, 1 opt-in skip, 13 failed golden comparisons. The historical golden tests are not tagged, so this command did not exclude them. All failures are the previously recorded Windows-baseline cases; no baseline regenerated and no visual approval claimed.
- Added photo UI lifecycle test, run separately afterward: passed. It covers picker cancellation, upload, replacement, removal and retaining an independent cover photo, using fictional valid PNG bytes.

## Remaining before release

Complete profile light/dark/narrow/tablet/200% visual coverage and approved Windows comparison; verify native picker/installation and deployed profile APIs with fictional fixtures. Finish reviewed device/notification contracts, scoped registration/listeners, contextual permission, preferences/quiet hours, durable delivery/retries, real event wiring and authorized foreground/tap behavior. Credentials/scheduler/device delivery need independent confirmation. Preserve original signing certificate, increment build, publish matching immutable/stable artifacts and verify hosted checksum as B5 requires.

No APK was rebuilt and no deployment was triggered by this source checkpoint. Source tests do not demonstrate native or live-server delivery. Continue with docs/pending-work.md; the entire backlog is still sequential work, not a completed release.
