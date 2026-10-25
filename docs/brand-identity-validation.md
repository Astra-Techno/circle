# Supplied CIRCLE identity — 25 October 2026

The owner supplied a square PNG with the purple linked-circle logo, **CIRCLE** wordmark and **MY CIRCLE. BILLION MEMORIES.** tagline. The canonical asset is copied unchanged to `mobile/assets/brand/circle-brand.png`.

Implemented in the shared `CircleBrand` widget on welcome, registration and login. Removed the previous alternative access branding and welcome collage. The widget exposes the full name and tagline to screen readers and preserves the original image in both themes. Existing account, invitation and group behaviour is unchanged.

Android/iOS launcher PNGs, web icons and favicon are full-artwork size exports, with no crop or recolouring. Browser metadata now uses CIRCLE and the exact tagline. `mobile/tool/generate_brand_icons.ps1` reproduces the exports using Windows System.Drawing. No dependencies, lockfiles or backend files changed.

Four access goldens were regenerated on Windows and visually inspected, including dark registration. The original asset is not a Figma-generated or recreated logo. Goldens remain regression baselines, not native-device approval. No Android/iOS device rendering or installation was performed.

Validation on Windows:

- Source and bundled asset SHA-256 both equal `CE2DAEB4C06B007EC6FA21CCF0D4039B90501400B4AB2223A5E5F79EF3EA19CF`.
- `flutter pub get --enforce-lockfile`: passed, lockfile unchanged.
- `dart format --output=none --set-exit-if-changed .`: passed, 149 files, zero changes.
- `flutter analyze`: passed, no issues.
- `flutter test -j 2`: 490 passed, 1 opt-in HTTP smoke test skipped; no failures.
- `flutter test test/access_design_test.dart test/circle_brand_test.dart -j 2`: 15 passed after regenerating the four access goldens; screenshot checks preload the asset in each route to avoid an undecoded-image baseline.
- `flutter test test/circle_experience_test.dart --plain-name "original circle golden" -j 2`: 9 passed. An existing day-rollover issue in the Events and nested-group date snapshots was resolved with a fixed fixture clock, without changing their golden files.
- `flutter build web --release --no-wasm-dry-run`: passed, including the final manifest and branding assets.

Initial checks caught a login assertion that needed to scroll to the existing OTP guidance, the screenshot asset-decoding race, and date-dependent existing goldens. These were corrected before delivery. Screenshots are under `mobile/test/goldens/access_*.png`.
