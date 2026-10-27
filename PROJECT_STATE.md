# CIRCLE project state

Updated: 27 October 2026. Inspect Git status before work; source, deployment and physical acceptance are distinct.

## Architecture and rules
- Flutter/Riverpod/go_router, shared Warm Keepsake tokens in mobile/lib/core; PHP8.3+/MySQL, OpenAPI docs/api-contracts/openapi.yaml.
- Main only; preserve unrelated work. Active checkout /workspace/circle-docs-sync. Original /workspace/circle retains old WIP; do not reapply it.
- AGENTS.md and README §0 govern verification, privacy, optional push, stable signing and coherent immutable downloads.
- Server core includes auth, private profiles/media, nested groups/membership/invite links, Memories/comments/reactions/saves/search. Chat/events/albums remain isolated previews, pending actual service batches.

## Current batch
- Owner requested contact-first group invitations plus Copy link. Pulled main through ad0578d, preserving local invitation work and incoming design samples/build11/debugging additions.
- OpenAPI0.3.7: one confirmed E164 contact, persistent recipient-owned list/detail/accept/decline, 20 attempts/hour, expiry/cooldown/immutable IDs, exact-group and parent/ban/removal enforcement. No automatic joining; member invitations obey approval.
- Groups/You inbox persists independently of push. Invite opens single-record picker; unregistered contacts offer WhatsApp/SMS. Copy remains independently available; long link/settings moved to Manage invite link. No address-book upload or broad contacts/SMS permission.
- Migrations011/012 persist invitations and transactional scoped group.invitation outbox. Worker/preferences/quiet hours/session checks plus foreground/background/taps implemented. Memory authorization/envelope remains separate. Source push retains explicit optional flag; production candidate enables it.
- Backend S1a password API0.3.6 foundation is included; S1b client password form is still pending. This invitation batch takes priority at owner request.

## Validation
- Dedicated circle_test:184 tests /3,087 assertions; PHPStan clean. Contract YAML parses and all internal references resolve.
- Flutter full:613 passed /1 skipped /13 known Windows-baseline golden failures on Linux. Final focused invite/push/design:48 passed; format/analyze clean. Invite phone/tablet, light/dark at200% rendered and inspected; Copy works independently of contacts.
- Existing thirteen Windows-baseline golden comparisons fail on Linux; preserve approved baselines. One known skipped test. No Android device attached.

## Release versus live
- Incoming main contains immutable Android1.0.10+11 and matching stable metadata/site links. Its live deployment is not inferred from Git.
- Packaged Android1.0.11+12, production HTTPS API/previewfalse/client pushtrue; 65,015,086 bytes, SHA256 8c1047e10c97c9e73914ab97fdaf88728a1b79d156bdc0359fd03e600976b59e. Stable/immutable APKs, metadata and both buttons align; original certificate and no broad contacts/SMS permission verified. Hosted verification pending.
- Established beta certificate SHA256:6c78be13d88b19587e4c37edb9012e3f2eb37fee34f6850084dd069d78f9b66c. Preserve earlier immutable APKs; never overwrite them.
- Deployer preserves hosted .env, storage, PHP handlers and deploy.php itself. Successful push is not deployment evidence.

## Remaining acceptance and next work
- Owner confirmed private server sender/cron ready and can test APK. Real device update, contact-provider/WhatsApp/SMS and foreground/minimized/closed push/tap results remain pending.
- Later feature order and notification matrix: docs/pending-work.md. Resume S1b password client/cleanup, then safety/privacy, live Chats, live Events, polls/albums in verified batches.
- Evidence: docs/contact-invite-sharing.md, docs/push-device-acceptance.md, docs/password-change-foundation.md.

## Commands
- Source /workspace/toolchain/mobile-env when present; dart format, flutter analyze and focused/full flutter test. Never run Flutter tests during APK build.
- Backend composer test only against circle_test, composer analyse; toolchain test-env when present (never print secrets).
- Release verify package/version/certificate/permissions/hash/bytes; align stable+immutable APK/JSON/both buttons, then verify complete hosted bytes.
