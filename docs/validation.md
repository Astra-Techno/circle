# Phase 1 validation — 22 October 2026

Environment: Windows, Flutter stable 3.44.8, Dart 3.12.2, Node 22.16.0. PHP is not on PATH; no backend work was attempted. The original repository had only README.md and CODEX_START_PROMPT.md and no Git history. Work is on feature/flutter-phase1.

## Executed checks

| Command (mobile/ unless stated) | Actual result |
| --- | --- |
| flutter doctor -v | SDK works; some Android licenses unaccepted; Visual Studio absent (Windows desktop not targeted) |
| flutter devices / flutter emulators | No Android device or configured emulator; web browsers available |
| codex mcp list (root) | No Context7/Figma/Playwright integration configured; no MCP installed |
| flutter pub get --enforce-lockfile | Passed after resolving dependency changes; lockfile included |
| dart format --output=none --set-exit-if-changed . | Passed; 16 Dart files, zero changes |
| flutter analyze | Passed; no issues |
| flutter test | Passed; 25 tests, including 10 golden comparisons without regeneration |
| flutter build web | Passed initial build and rebuild; missing icon-font warning resolved; output in mobile/build/web |
| flutter build apk --debug | Attempted; interrupted after prolonged Gradle assembleDebug with no additional diagnostic; no APK success claimed |
| native integration_test | Written but not executed: no Android device/emulator |

Initial analyzer findings (four missing braces) and an accessibility-test semantics teardown failure were fixed before the passing checks. An intermediate enforce-lockfile check correctly rejected a removed dependency; pub get refreshed the lock. A web-build font warning prompted restoration of cupertino_icons, which the router's platform UI references.

## Screenshot review

Generated and visually inspected 10 PNGs under mobile/test/goldens: welcome, invitation, feed light/dark, post detail, groups, memories, friends, reunions and profile at 393x852. Loaded bundled licensed Roboto and Material Icons; corrected the initial unreadable test-font rendering. Inspected spacing, contrast, wrapping, alignment and clipping. Post detail scrolls to its composer action; content below the viewport is intentionally scrollable.

Automated overflow checks cover 360x800, 393x852 and 900x1100 in dark mode at 2x text. Additional tests cover invitation denial, guarded navigation, create/comment/reaction/save state, search, RSVP, reset, empty/error/retry/loading, long content and 100 posts, tenant denial and unknown resources. Welcome passes Android tap-target, labeled-target and contrast guidelines.

These are provisional original-design baselines, not human-approved reference matches or native Android screenshots. Keyboard, TalkBack, physical-device performance, reduced motion and native rendering remain unverified. See development.md for the device checklist.

## Remaining scope

This is a local prototype. Production sign-in/sign-up, approvals, real group posting, photo upload/tagging, moderation/reporting, export/deletion, persistent storage and server authorization are deferred. Local tenant tests do not establish server security. No backend, API, cloud credentials or real personal data were added. iOS is scaffolded but unbuilt on Windows; release signing and final store assets remain future work.

Next task: connect/configure an Android device, resolve SDK licenses interactively, complete the native build and run integration_test/journey_test.dart, then capture and review the prescribed native screenshots before Phase 2 contract work.
