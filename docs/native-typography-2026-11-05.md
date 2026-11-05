# Native typography correction — 5 November 2026

Owner rejected the installed Social2.0 screen: the type looked too heavy and the failed-photo panels overwhelmed Home. This correction is source1.0.33+38, interface marker **Social2.1**.

## What was found

The three static Inter files generated for Social2.0 had different OS/2 weight classes (400/500/600) and different outlines, but all declared the same internal family/full/PostScript identity, `Inter Regular` / `Inter-Regular`. Medium and SemiBold were exported without `updateFontNames=True`. This is a real native font-identity defect and a CoreText collision risk. It is not proof of the exact face selected on the owner's phone; screenshot-only inspection cannot establish CoreText selection or the phone's Bold Text preference.

The earlier IPA inspection proved the font files were bundled and matched source. It did not inspect their internal identity tables. That gap is corrected with a binary sfnt-table check, run by Windows CI and both iOS release paths. No third-party Python dependency is needed to validate the committed fonts.

## Correction

- iOS/macOS now use Flutter's official `CupertinoSystemText` native alias, consistently across all text roles. Android/web use corrected Inter. No Apple font is downloaded or redistributed. Accessibility bold-text and text-size settings remain respected.
- Inter was re-exported from the same original variable font at optical size14/weights400/500/600 using fontTools4.61.1 with `updateFontNames=True`. PostScript names are now `Inter-Regular`, `Inter-Medium`, `Inter-SemiBold`; typographic family remains Inter. CI verifies the real name table, OS/2 weights, static format and distinct glyph outlines.
- Body remains16/24 regular; titles21/28, names15/20 semibold, metadata12/16, labels13/18 medium, buttons15/20 medium. Header artwork28 and icon paint36/icons20 retain48px hit targets and the prior footer fix.
- Photo mosaics have4px inner corners. Failed previews use a small retry affordance; narrower tiles use the icon with the full accessible description, instead of repeating a long sentence across every tile.
- A signed-file403 can renew the link **once per resource path** via the existing authenticated repository, which rechecks current access. A second403,404 or other persistent error stays an explicit retry state. No request storm, public-photo fallback, relaxed authorization or off-screen download was added.

## Checks and limits

The source font-identity test passes. Focused Flutter checks pass22 tests, including native-family/regular-weight selection, simulated403 renewal bounded to one, persistent404/manual retry, off-screen download behavior, preview decode budgets, design guard, forms and112 route/configuration renders. Final analyzer/format and Windows integration/release results will be recorded below.

Windows renders remain layout references, not an iOS-native font preview. Actual iPhone appearance still needs owner acceptance. Photo renewal is verified for simulated expired-link failures; the screenshot's real delivery error has not been diagnosed from an authenticated production request. Missing storage files or persistent server errors are not claimed repaired. The owner was asked whether tapping Retry loads the image; work does not depend on that optional answer.

All prior membership/privacy, scoped media, drafts, pagination and backend query optimizations remain. No backend or SQL migration changed. Android signing is still unavailable; current Android downloads remain unchanged.

## Windows verification

Source `1f018d1` passed analyzer/format and Windows run `42031231585`: **752 tests passed, 1 skipped**. All22 decoded baseline PNGs were reviewed across light/dark, auth, Home, Circles, compose, profile and responsive layouts, then copied from Windows CI. These fixtures include simulated loading/error states and are not production or native-iPhone evidence. Artifact13416123427 SHA256: `1457df0f34e719d69ef4ac0e48a64725746bce4773f4d86dde578c7e5437cfc6`. Signed iOS run42031235809 is in progress; normal golden comparison will run after this baseline commit.
