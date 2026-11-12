# Selected-contact invitations — 12 November 2026

The iPhone invite screen hid contact selection because its platform bridge supported Android only. Its Copy button also generated a general group link, so it could not promise a selected-number restriction.

The screen now offers the system contact picker on iOS and Android, plus manual international-number entry. It submits only the explicitly confirmed number. Registered active users receive the existing consent invitation and eligible notification; exact-circle members get an already-member result. Membership is never granted by sending an invitation.

For unknown/inactive accounts, the server creates a random, seven-day, single-use token bound to a keyed digest of the selected canonical mobile and group. Copy, SMS, WhatsApp and the share sheet reuse this token. The URL contains no phone number. Joining requires an active authenticated account with the matching registered mobile; mismatches neither consume the link nor create a join request. Parent membership, bans, revocation, expiry and manual approval remain enforced. General group links remain separate and unrestricted by phone.

Public previews of these links use a neutral circle name, no cover and no real member count. Account/server/session changes invalidate pending share actions. The client refuses an old server's share_link response without a bound token. This uses Circle's current mobile/password identity (ADR0005), **not OTP/SIM verification**. JWT signing-key rotation also invalidates outstanding selected-contact tokens.

Deploy the backend through the existing deployment script, including **031_phone_bound_invites.sql**, before using mobile **1.0.40+46**. No new deployment secret is needed. Deployment and physical-device contact selection/push delivery are not established by local tests.

Validation: full dedicated-circle_test backend suite 288 tests/5248 assertions passed; additional focused invitation suite 11 tests/232 assertions passed (forwarded recipient, single use, parent prerequisite, approval, revocation, direct invitations). PHPStan clean. Flutter analyzer/design guard and focused contact tests pass; full functional suite 836 passed/one existing live-HTTP smoke skip (including 41 functional cases from mixed golden-test files). Large-text light/dark phone/tablet invitation layouts pass. Windows golden-image verification remains a separate existing release gate; no baselines regenerated. iOS helper suite 19 passed/one platform skip. Native iOS code requires Xcode CI and a real-device picker/share check.

Xcode CI caught a Swift importer mismatch in the bridge: Flutter exposes registrar.viewController as a property. Corrected the invocation before retrying the signed build; no failed-run IPA was uploaded.

The shared-link landing page also links to the existing iPhone installation instructions, alongside Android downloads, and explains returning after installation and using the invited number. Public iPhone beta availability still follows Apple approval and tester access.
