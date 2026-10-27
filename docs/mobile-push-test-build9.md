# Android push acceptance APK — 1.0.8 build 9

27 October 2026. An opt-in owner test candidate; actual device delivery is not yet verified. Stable site buttons, circle.apk, stable release.json and immutable build8 are unchanged.

- APK: `downloads/circle-1.0.8-9-push-test.apk`.
- Candidate metadata: `downloads/push-test-release.json`.
- Intended URL: https://circle.cloudkart24.com/downloads/circle-1.0.8-9-push-test.apk
- Package: `com.circlecommunity.mobile`, versionName `1.0.8`, versionCode `9`, min SDK24, target/compile SDK36.
- Build: release, production HTTPS API, `CIRCLE_PREVIEW=false`, `CIRCLE_PUSH_ENABLED=true`; 117.3 seconds. Source defaults remain false.
- Bytes: 64,752,578.
- SHA-256: `c707df83fd020ee01956012eae34b64a648fa10e7b00b5b724777af428477d84`.
- apksigner verified the established beta certificate: `6c78be13d88b19587e4c37edb9012e3f2eb37fee34f6850084dd069d78f9b66c`. No signing key/password committed.
- Original immutable build8 SHA-256 rechecked unchanged: `cf55a769270c28266c0025f1a680f60dc6a57e1fd6e88e437b31e7af241cb157`.

Native plugin/Android release compilation and package/certificate checks pass. Flutter 564 passed / one skipped / 13 known Linux golden mismatches; format/analyze clean. Focused validation and implementation limitations: [background checkpoint](push-background-checkpoint.md).

Any subsequently distributed changed APK must increment to build10 or higher; never replace this immutable candidate with different bytes.

Use the [device acceptance checklist](push-device-acceptance.md). The owner can install this candidate over the beta and opt in explicitly. As a higher versionCode, this is an upgrade; returning to an older APK generally requires uninstalling, so preserve the account password. Server credentials/cron readiness was owner-confirmed, not inspected from cloud. Actual sender flags/worker counters, matching Firebase project and real device results must still be checked. No broad push rollout, iOS delivery or notifications for future features is claimed.

Hosted deployment/checksum verification is pending at preparation; record it only after fetching the complete published artifact. Do not infer deployment from a Git push.
