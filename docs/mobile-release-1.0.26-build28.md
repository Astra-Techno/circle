# CIRCLE 1.0.26 build 28

Notification previews approved by owner on 3 November 2026: circle names, person names and short message/content snippets. Server previews are opt-in at rollout via PUSH_PREVIEWS_ENABLED; default false retains legacy payload compatibility. Install updated Android/iOS clients before enabling this flag. Existing recipient/session/permission/quiet-hour/content checks remain. Report notes and reporter identities are excluded.

Android immutable artifact: downloads/circle-1.0.26-28.apk
- Bytes: 64917077
- SHA256: 538b21aee34039d6843789a8abfaff31aec01c9be8f4aa40697975e076904035
- Certificate SHA256: 157579dd08f44d8aebe9bc5b6e53e778d8ca642d97233d15c206f8f5185df01e (unchanged since build20; APK verifies v2).
- Package com.circlecommunity.mobile, version1.0.26/code28, minSdk24/targetSdk36.
- Built with production API and CIRCLE_PUSH_ENABLED=true using scripts/build-android-release.sh; metadata and both download buttons agree. Previous APK27 checksum unchanged.

Validation: full backend231 tests/4184 assertions, PHPStan clean; focused diagnostics/Unicode2 tests/35 assertions, rollout1 test/21 assertions; Flutter87 push checks and analyzer clean. APK compilation validates the Android bridge; iOS compile/upload is a separate GitHub job. No physical preview acceptance or hosted deployment/checksum verification is claimed.

Rollout from phone: run existing deployment link, install Android28 and updated TestFlight, then set PUSH_PREVIEWS_ENABLED=true in production .env. Protected diagnostics displays whether previews are enabled. Send a new eligible Memory/message; previously delivered notifications are not replaced.
