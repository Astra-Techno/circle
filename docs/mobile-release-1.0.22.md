# Android 1.0.22+23 — 29 October 2026

Live Chats now uses an avatar-led inbox, opposing message bubbles with local times, compact photo/input/send controls and accessible message menus. Secondary conversation controls are collapsed; incoming requests remain visible. Group images use the existing private group-photo pipeline. See [design notes and renders](chat-redesign.md).

- Immutable file: `downloads/circle-1.0.22-23.apk`
- Size: 66,031,742 bytes
- SHA-256: `f920dc155b1036f0f873d33665ab534675749966b71273c1b630945a56f6e15f`
- APK v2 signature verified; certificate SHA-256 `157579dd08f44d8aebe9bc5b6e53e778d8ca642d97233d15c206f8f5185df01e` matches established builds20/22. Existing installations signed by that key can update without reinstalling.
- Verified package `com.circlecommunity.mobile`, versionName1.0.22/versionCode23, minSdk24/targetSdk36; release is non-debuggable. Production API, previewfalse, pushtrue.
- Normal Flutter release build completed in173.4s after tests; no test-only native plugin registration. No dependency upgrades or backend changes.
- Analyzer and formatting clean. Focused chat/retry/reporting/design97 pass; final live-chat/media/group-photo/design51 pass. Full Flutter739 pass/1skip/13 existing Windows-baseline golden mismatches on Linux, no functional failures. Windows baselines unchanged.
- Eight populated chat light/dark phone/tablet renders at100/200% text captured; representative renders inspected. No physical-device installation or real push delivery verification.

Both website download links and release metadata now target build23; prior immutable APK22 bytes are unchanged. Source push and GitHub artifact availability do not establish production deployment. The hosted deployer must update pages/metadata; the existing download redirect supports the current immutable APK when hosting skips binary copying. Production hosting has not been verified here.
