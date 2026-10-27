# Android invitation/push test candidate — 1.0.9 build 10

27 October 2026. This separate opt-in test candidate adds contact-selected invitation sharing and retains build9's Android push acceptance mode. Stable release.json, circle.apk, both site buttons, immutable build8 and push-test build9 remain unchanged. No broad rollout or real-device verification is claimed.

- APK: `downloads/circle-1.0.9-10-test.apk`.
- Metadata: `downloads/invite-test-release.json`.
- URL: https://circle.cloudkart24.com/downloads/circle-1.0.9-10-test.apk
- Package: `com.circlecommunity.mobile`, versionName1.0.9, versionCode10, min SDK24, target/compile SDK36.
- Release build: production API, preview false, explicit push-client true; 96.8 seconds.
- Bytes: 64,785,682.
- SHA-256: `9f3b2507f350be8f3c8a93b03d5f67fc40d5fcea76122317963dd683e4a35f13`.
- apksigner verification succeeded with the original beta certificate `6c78be13d88b19587e4c37edb9012e3f2eb37fee34f6850084dd069d78f9b66c`; no signing credentials committed.
- Merged APK permissions checked: no READ_CONTACTS, WRITE_CONTACTS or SEND_SMS. SMS opens a draft with only the selected number; sending requires the user in the external app.

Validation and manual acceptance: [contact invitation sharing](contact-invite-sharing.md), [push device checks](push-device-acceptance.md). Flutter full: 580 passed / one skipped / 13 known Linux golden failures; final sharing/route/design subset22 passed; format/analyze clean. PHP/contracts unchanged, so prior backend test evidence retained. An Android build is not contact-provider, WhatsApp, SMS or push delivery proof.

Install over the existing beta using the established signature. Any changed subsequent distributed APK must increment to build11 or higher. Never replace this immutable file with other bytes. Download publication/HTTPS fallback verification is pending at preparation and must be recorded after complete hosted checksum/content checks.
