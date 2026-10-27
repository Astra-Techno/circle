# Main beta download — Android 1.0.9 build 10

27 October 2026. At the owner's explicit request, promote the already packaged build10 to the main site buttons and circle.apk. This changes publication pointers only; no runtime rebuild, new versionCode, backend enablement or private configuration change. Device contacts/composer/push acceptance is still pending and is not implied by publication.

- Main immutable URL: https://circle.cloudkart24.com/downloads/circle-1.0.9-10.apk
- Stable alias: https://circle.cloudkart24.com/downloads/circle.apk
- Same verified bytes as the preserved circle-1.0.9-10-test.apk: 64,785,682 bytes, SHA-256 `9f3b2507f350be8f3c8a93b03d5f67fc40d5fcea76122317963dd683e4a35f13`.
- Original beta certificate: `6c78be13d88b19587e4c37edb9012e3f2eb37fee34f6850084dd069d78f9b66c`.
- Production HTTPS API; preview false; client push explicitly enabled with user opt-in. No broad contacts/SMS-send permission. See [build10 checks](mobile-invite-test-build10.md) and [phone acceptance](contact-invite-sharing.md).
- release.json and both visible site buttons now select build10. Old immutable build8/build9/test files are preserved. Current .htaccess uses no-store for the stable alias/metadata/download page and immutable caching for the new versioned path.

Local checks compare all three build10 artifacts byte-for-byte via SHA-256, version/build/package/certificate, and both HTML links/labels/metadata. Existing runtime evidence is unchanged: 580 passed / one skipped / 13 known golden failures, final22 sharing/route/design checks pass, analysis clean and Android build verified. Runtime tests are not rerun for these publication-only changes. Published in `aa0350a`; deployment succeeded in 95.9s. Full hosted stable and immutable APK downloads both verified HTTP200, 64,785,682 bytes and the recorded SHA-256. Root/home and downloads/index routes all select build10 with correct labels; release.json matches repository metadata. Stable APK/metadata return Cache-Control no-store, max-age=0; the immutable APK returns public, max-age=31536000, immutable. API health succeeds. Physical-device acceptance remains pending.
