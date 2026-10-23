# Original CIRCLE UI validation — 23 October 2026

## Delivered scope

The default `mobile/lib/main.dart` now opens the original CIRCLE experience described in [the design specification](original-circle-design.md). This delivers the UI-1 shell and neutral multi-group mock experience, with selected group and Memory foundations for subsequent phases. It does not complete UI-2 through UI-6.

The five tabs retain independent navigation stacks. Open mobile/password registration and login are explicitly local previews and start with no memberships. The separate **Explore fictional circles** action loads fictional family, nested college, friends, office and club examples. Exact memberships govern group content and mutations; owning a parent never unlocks a private subgroup. Creating a group/subgroup, text Memories, love/save/comments, local RSVP, appearance and clearing the session work in memory. Nothing is sent to a backend or persisted across a restart.

Chat delivery, invitations/direct additions, approvals, membership administration/cascade departure, DM eligibility, uploads, polls and full event/album/settings workflows remain unimplemented and are not exposed as working actions. The previous prototype remains in legacy source/tests; the default entry point uses the new app.

## Changed areas and ownership

- `mobile/lib/app/circle_experience.dart`, `workspace_providers.dart`, `workspace_view.dart`, `circle_support_screens.dart`: router, session, repository injection, asynchronous states and shell.
- `mobile/lib/core/circle_components.dart`: shared semantic visual components.
- `mobile/lib/features/groups/{domain,data,presentation}/`: immutable group/event workspace, repository contract/mock, membership/depth checks and group UI.
- `mobile/lib/features/memories/{domain,presentation}/`: immutable Memories, audience selection and local interactions.
- `mobile/lib/main.dart` and optional callbacks in `features/auth/presentation/access_design.dart`: connect the access design to the new default app.
- New repository/widget/golden tests and updated `mobile/integration_test/journey_test.dart`.

Pre-existing user edits in README, AGENTS, startup prompt, architecture/design docs, ADRs, dependency files and platform scaffolding were preserved and excluded from this commit. No branches, pull requests, backend services or dependency changes were introduced.

## Executed validation

Windows; Flutter 3.44.8 / Dart 3.12.2. Commands run from `mobile/`:

| Command | Actual result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | Passed; 35 Dart files, 0 changes |
| `flutter analyze` | Passed; no issues |
| `flutter test` | Passed; all 79 tests, including 26 new tests |
| `flutter test test/circle_repository_test.dart test/circle_experience_test.dart --update-goldens` | Passed after fixing fixture chronology; provisional goldens generated |
| `flutter test test/circle_experience_test.dart --update-goldens` | Passed after visual spacing/copy refinements |
| `flutter build web --release` | Passed; Wasm dry run also succeeded |
| `flutter build web --release --no-wasm-dry-run` | Passed for the final refinement |
| `flutter devices` | Windows, Chrome and Edge only; no Android/iOS device connected |

Tests cover empty registration, explicit sample tour, group creation, text composition, route guards/return paths, retained branch stacks, exact-membership denial including a parent owner/private child, roles, depth 1–10 and rejection at 11, input boundaries, deterministic ordering, local mutations, RSVP and session reset. Layout checks exercise nine routes at 360×800, 393×852 and 900×1100 with dark theme and 200% text. Home semantics tests check labeled controls and Android minimum touch targets. These checks do not establish full screen-reader or native accessibility certification.

Nine new golden PNGs in `mobile/test/goldens/circle_*.png` were inspected visually. Review found and fixed a duplicate detail-page floating action, overly heavy test shadows, an oversized Memory illustration, and crowded group-tab labels. Goldens are regression references, not owner approval or proof of equivalence to a design file.

## MCP and browser evidence

`codex mcp list` reports Figma enabled with OAuth and Playwright enabled. Figma and Context7 tools are absent from this conversation; no authorized design reference was supplied. This is original design, with no claim of a Figma implementation. No MCP settings or credentials were changed.

The installed Playwright MCP was invoked through local stdio JSON-RPC against a temporary loopback server serving `build/web`. The final Chrome smoke check at 393×852 opened the welcome page, entered the fictional tour at `/#/home`, and clicked through Chats, Groups, Events, You and back to Home successfully. Welcome and Home screenshots were visually inspected; browser console reported zero errors and warnings. Browser checks validate the web build only.

Screenshots: [Welcome](screenshots/original-circle-welcome-web.png), [Home](screenshots/original-circle-home-web.png). Golden examples: [dark Home](../mobile/test/goldens/circle_home_dark.png), [nested group](../mobile/test/goldens/circle_groups_g_friends.png), [create group](../mobile/test/goldens/circle_groups_new.png).

## Remaining validation and next step

The updated integration journey has not run on Android or iOS. No native visual, keyboard, lifecycle, performance or device-security claims are made. Production mobile/password authentication, OTP and the planned PHP/MySQL API remain outside this mock UI increment.

Next: complete UI-2 membership workflows with tested invitation consent, approval, listed/hidden discovery, role/last-owner safeguards and cascade-removal rules before exposing those controls; then validate the current journey on an Android emulator/device and iOS simulator/device.
