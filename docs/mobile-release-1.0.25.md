# Android 1.0.25+26 — 30 October 2026

Includes latest committed no-demo app/UI changes (WhatsApp-style live chat and inbox previews, refreshed Events, camera-first Memories, circle activity and profile grids) and first-launch OS notification permission. The app remains usable if permission is denied or Firebase is unavailable. Device-token registration remains authenticated/session-scoped. Saved server notification opt-outs remain respected. iOS-only push bridge/entitlements do not replace Android's existing bridge.

Production build uses scripts/build-android-release.sh with the live HTTPS API and CIRCLE_PUSH_ENABLED=true; normal Flutter release tooling regenerates release plugin registration after tests. The existing dedicated release signing identity is retained. Previous immutable APKs are preserved.

Source checks: analyzer/format/PHPStan clean; full backend230 tests/4172 assertions pass. Focused33 push/background/design and12 avatar tests pass,19 iOS signing/upload helper tests pass. Full Flutter run660 pass/1skip/14fail:13 Windows golden differences on Linux and a stale avatar ListView finder, subsequently corrected and all12 avatar tests passed. No goldens regenerated. Actual Android/iOS push delivery remains device acceptance, not a compilation claim.

Server deployment is needed for current inbox preview and iOS notification outbox changes. No new database migration. A Git push does not deploy hosting; use the existing deployment script, then check the hosted release metadata/download button. Existing current-release download fallback handles hosts skipping APK binaries. No physical Android device is attached here.

Published artifact: downloads/circle-1.0.25-26.apk; 64,637,550bytes; SHA256 `80af7eb27596db9588ffb7ede3b65bc992f80ff4e419fdb90064b82a187ccabb`. APK signature verified with established certificate SHA256 `157579dd08f44d8aebe9bc5b6e53e778d8ca642d97233d15c206f8f5185df01e`. Package com.circlecommunity.mobile, versionName1.0.25/versionCode26, minSdk24/targetSdk36. Production release command completed in236.6s. Metadata and both buttons agree.
