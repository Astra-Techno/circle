# Mobile/password access preview — 22 October 2026

## Scope and decisions

Added an isolated original Flutter design proposal for welcome, registration, login and preview completion. Mobile number + password is initial authentication direction; OTP comes later. PHP/MySQL remains the planned lightweight API. ADR 0005 records the owner direction and production security prerequisites.

Run from mobile/: `flutter run -t lib/auth_design_preview.dart -d chrome` or use an Android/iOS device ID. The existing application entry point is unchanged. Input validation is interactive, but there is no registration, credential verification, account persistence or backend request. Preview input is cleared from controllers on completion. Registration never grants membership in existing group fixtures.

## Actual checks

- `flutter pub get --enforce-lockfile`: passed; no new dependencies.
- `dart format --output=none --set-exit-if-changed .`: passed, 22 Dart files, zero changes.
- `flutter analyze`: passed, no issues.
- `flutter test`: **53 tests passed**, including all 10 previous goldens and 4 new access goldens without regeneration in the final run.
- New tests cover phone syntax, registration password bounds, login presence checks, validation feedback, password visibility, input clearing, accessible targets/labels/contrast, and scrolling at 360x800, 393x852 and 900x1100 with 2x text, dark mode and keyboard insets.
- The first preview test run exposed offscreen lazy-list actions; the test helper now scrolls to mounted actions and settles layout before tapping. Visual review also found and corrected overlapping decorative circles.

## Visual and MCP review

Inspected mobile/test/goldens/access_welcome.png, access_register.png, access_login.png and access_register_dark.png. Readable bundled fonts, semantic theme colors, wrapping, spacing and artwork were reviewed. Baselines are provisional, not an approved Figma match.

Used the installed Microsoft Playwright MCP through its real JSON-RPC initialize/tools/call interface to open the local Flutter web-server preview, resize Chrome to 393x852 and capture screenshots under ignored mobile/build/auth-design-review/. Registration and login rendered and were visually inspected. Initial welcome captures remained blank during debug startup; a console check reported no errors, but a rendered initial welcome was **not verified in the browser**. Passing widget/golden tests do not erase that unresolved web-startup observation.

Figma's local MCP registration is enabled and its previous OAuth login succeeded, but Figma and Product Design tools are not exposed to this conversation. Those integrations were discovered and offered for enabling; confirmation is still pending. No claim of an MCP-generated design, approved reference match, Figma file creation or Figma export is made. The MCP design-generation/review pass remains outstanding.

No Android device/emulator was available. Native Android/iOS rendering, keyboard behavior, TalkBack/VoiceOver and task testing with real people remain unverified. No native build or production security validation was claimed.

## Collaboration and next step

Worked on main, pulled origin/main before implementation and fetched again before delivery. Existing uncommitted user changes were left untouched; only newly created preview/decision/report files belong to this increment. No backend, credentials, real people or remote photo assets were introduced.

Next: enable Figma or Product Design in the current conversation for the requested design pass; resolve the initial web debug-startup observation; review the access design before integrating it with the new multi-group app shell. Implement the reviewed PHP/MySQL auth contract and security tests in a later backend workstream. The preview must never be wired as real authentication.
