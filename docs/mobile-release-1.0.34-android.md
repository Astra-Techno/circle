# Android release1.0.34 (39) — 6 November 2026

The owner explicitly requested new Android signing keys and a release app. The original build20–28 key/private backup was absent after a targeted workspace search. A new RSA4096/SHA256withRSA release key was generated with a cryptographically random password, outside Git. This is an owner-requested identity transition, not an update signed with the missing old key.

## Release and compatibility

- APK: `downloads/circle-1.0.34-39.apk`, **65,010,241 bytes**. Version1.0.34/build39, packagecom.circlecommunity.mobile, minSdk24/Android7.0+, targetSdk36, non-debuggable, ARM32/ARM64/x86_64. Interface **Social2.2**.
- SHA256: `ba84d1a6ca24a4a4ce4c6e3e27a7c4c7b5259c7d7673ba14a506eadb33366ac2`.
- New certificate SHA256: `bcd5a9dcd2262be9f445f2d52892f574054e8616fbf0df66f226d88b263b9966`.
- Actual prior APK28 verifies under `157579dd08f44d8aebe9bc5b6e53e778d8ca642d97233d15c206f8f5185df01e`. The new certificate differs: **existing Android installations require a one-time reinstall**. Finish/copy unsent local drafts first. Server account data is not removed by uninstalling the app. No installation/uninstallation was performed here.
- Build39 is the first release under this new identity; future Android updates must reuse it. This is not a Google Play signing-key migration or Play upload.

## Build and verification

Runtime source is unchanged from verified Social2.2 (release sourcecommit `f27d3248e1aa04090a2bd38177f905f81cb6e8e6`, earlier app source253da19). Both Windows runs42168291358/42168921653 passed758 tests/1skip before this packaging task. No app/backend code or dependency changed, so no redundant runtime suite was run.

Official `scripts/build-android-release.sh` sets production APIhttps://circle.cloudkart24.com/api/v1 and CIRCLE_PUSH_ENABLED=true. The final successful build took264.3s after environment setup. A complete matching local JDK21 was added; Gradle uses the inherited managed proxy, and disposable Gradle caches use available temporary storage after disk exhaustion. The existing AGP/newDsl settings were retained; earlier toolchain/disk failures were not app-code fixes.

Actual final APK checks: apksigner verification succeeds (v2), certificate matches the independently exported keystore certificate, package/version/minSdk/targetSdk/non-debuggable metadata match, ZIP integrity passes, each of the three ABI AOT libraries contains Social2.2 and the production API, and no keystore/key.properties is bundled. The copied immutable APK matches the verified checksum. [Machine-readable receipt](mobile-release-1.0.34-android.json).

## Private key retention

Private key and properties are under `/workspace/toolchain/signing/`; ignored `mobile/android/key.properties` points there. Private owner backup: `/workspace/circle-signing-backup-2026-11-06.zip` (keystore, properties with passwords, restore instructions). Save it privately outside this temporary workspace; future builds need the same key. Do not commit, publish or put the archive in downloads. No signing passwords or key bytes are in this document or Git. A fresh machine must restore the archive privately and adjust storeFile to the actual local path.

## Publication and limits

The APK, release.json, downloads page and website Android button are updated together; earlier immutable APKs are preserved. Both pages disclose the new-key reinstall requirement. Repository publication and live hosting deployment are separate; the live domain remains unavailable under this environment network policy. Run the existing authorized hosting deployment process to update website metadata/pages; missing current binaries use the existing checked repository fallback. Physical installation, Android push receipt, production authentication and native design acceptance remain unverified.

The full public repository APK download at commit `e1d54a7` returned HTTP200 and exactly65,010,241 bytes; its SHA256 matched the verified release. Direct download: https://raw.githubusercontent.com/Astra-Techno/circle/e1d54a7/downloads/circle-1.0.34-39.apk. This verifies repository availability, not the live hosting domain.
