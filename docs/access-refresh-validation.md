# Access and colourful welcome refresh — 26 October 2026

## Requested behaviour

- Pure white initial appearance, independent of the phone's dark setting; dark/system remain explicit choices.
- Use the supplied Stitch welcome composition with local illustrative photo assets and the current CIRCLE logo/name/tagline. Lavender, coral and sage accents come from central semantic tokens.
- Remove the waving-hand decoration from login (and the redundant person-add decoration from registration).
- Start the calling-code picker at India +91, without interpreting an English/UK device locale as physical location.
- Add **Use my location for country code**. Only that action requests foreground permission; coarse Android location is sufficient. Native OS reverse geocoding returns the country code, and CIRCLE neither stores coordinates nor sends them to its own API. Denial, disabled services, unsupported platforms and lookup failures leave manual selection available. A late result cannot overwrite a newer manual choice.
- Release builds connect to the documented HTTPS API by default. Debug/tests retain local preview; `CIRCLE_PREVIEW=true` explicitly builds a fictional preview. The API URL remains overridable with `CIRCLE_API_BASE_URL`.

## Registration diagnosis

The photographed **Preview registration** action was the local mock flow, which discards details. Existing server-mode code already calls `/auth/register`, then `/auth/login`, saves revocable session tokens and opens an empty workspace. Registration never grants group membership. Fake-HTTP flow tests cover this actual client path without real personal data.

The live URL `https://circle.cloudkart24.com/api/v1/health` was checked with a cache-busting query and `Cache-Control: no-cache`. It returned HTTP 500 with Composer's PHP >= 8.3 requirement; the response identified **LiteSpeed / PHP 8.2.35**. The owner confirmed that MultiPHP Manager shows PHP 8.4 for the exact subdomain. Those observations conflict: the panel configuration is confirmed, but the public request is still served by an older handler/process or a different origin. No Composer requirement was bypassed or lowered. Hosting must reconcile the actual web handler (including parent `.htaccess`, document root/origin and LSAPI/PHP process configuration) before live account creation can succeed.

No server configuration or account records were changed. Browser/computer-use tools failed to initialise, so the hosting panel could not be inspected here. No credentials were requested or read. The runtime failure must be resolved on the host before a real-HTTP registration smoke check can run.

## Implementation and scope

`core/design.dart`, `theme_controller.dart`, `api/api_config.dart`; auth domain/application/data/presentation; Android coarse-location permission and iOS when-in-use purpose string; bundled welcome photos; lockfile and plugin dependencies. Location permission/reverse geocoding use the official Baseflow [geolocator](https://pub.dev/packages/geolocator) and [geocoding](https://pub.dev/packages/geocoding) packages. No backend runtime or contract change is included.

The current mobile/backend minimum password length remains six characters. The older OpenAPI password schema still says 15; reconcile that existing contract drift with both tracks before changing policy.

## Validation

Windows, Flutter 3.44.8 / Dart 3.12.2:

| Check | Actual result |
| --- | --- |
| `flutter pub get --enforce-lockfile` | Passed with the new reviewed plugin lockfile |
| `dart format --output=none --set-exit-if-changed .` | Passed; 154 files, zero changes |
| `flutter analyze` | Passed; no issues |
| Focused auth/server-mode/design-guard tests | 33 passed |
| Country/appearance/release-mode tests | 7 passed, including denial, permanent denial, disabled service, opt-in and manual-selection race |
| Main-screen golden render | All 9 passed; all 13 access/main baselines were intentionally updated for the new palette/layout |
| `flutter test -j 2` | 497 passed, 1 opt-in HTTP smoke test skipped, no failures |
| `flutter build apk --release --dart-define=CIRCLE_API_BASE_URL=https://circle.cloudkart24.com/api/v1` | Passed; `mobile/build/app/outputs/flutter-apk/app-release.apk`, 62,740,376 bytes |
| APK manifest (`aapt dump permissions`) | INTERNET and ACCESS_COARSE_LOCATION; no fine/background location permission |
| `flutter build web --release --no-wasm-dry-run` | Passed |
| Live API health | HTTP 500; Composer PHP requirement failure; `X-Powered-By: PHP/8.2.35` |

Welcome, registration/login, Home, Chats, Events and You screenshots were visually inspected. Remaining main-screen goldens passed comparison in the full run. Baselines are original Flutter adaptations of the supplied export, not a claim of native pixel equivalence.

An initial Android compile failed because a concurrent Flutter test run rewrote the generated plugin registrant with the development-only integration-test plugin. The final APK was built successfully after tests stopped; do not run Flutter tests and native packaging concurrently in the same checkout. No generated plugin source was hand-edited.

No connected Android/iOS device was available. SDK 36.1 is installed; Flutter doctor reports some unaccepted Android licenses, but the installed SDK built this APK. The project still uses its existing debug signing key for the test release; store signing is separate. Native location prompts, actual country selection, installation and native screenshot equivalence remain unverified. Live account creation cannot be verified until hosting resolves the PHP handler mismatch. Golden creation is not owner approval.
