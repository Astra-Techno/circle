# Validation — 23 October 2026 (Linux, not committed)

Environment: Ubuntu Linux. Flutter 3.44.8 / Dart 3.12.2 was installed for this session in `~/flutter`. PHP 8.3.6 and Composer 2.7.1 are installed. The local database server is **MariaDB 10.4.32**, not MySQL 8. This machine's copy has no Git repository, so nothing was committed. No Android/iOS device was available.

## Mobile (`mobile/`)

| Command | Actual result |
| --- | --- |
| `flutter pub get --enforce-lockfile` | Passed; no dependency changes, `pubspec.lock` unchanged |
| `dart format --output=none --set-exit-if-changed .` | Passed; 38 files, 0 changed |
| `flutter analyze` | No issues found |
| `flutter test` | **104 tests: 91 passed, 13 failed. All 13 failures are golden pixel comparisons** |

**Update after the remaining UI items (step 5):**
- Format: clean (147 files). Analyze: clean.
- `flutter test -j 2`: **476 passed, 1 skipped (smoke), 13 failed, all golden-only.** No dependency changes; goldens untouched. `circle_events` (and possibly `circle_home`/`circle_home_dark`) are visually affected.
- Rendered and reviewed: the month calendar, an @mention in group chat, the album cover and photo menus.

**Open questions from step 5 (for the owner):**
1. The calendar shows Upcoming months only. Should it allow browsing past months too?
2. Photos and polls can't be forwarded (Instagram allows forwarding photos).
3. The tap row on a message is now Love / Reply / Forward / More (decision #20 said Love / Reply / More).
4. A comment that mentions the Memory's author creates only the mention item, not a separate "commented on your Memory" item.
5. Mentions on the server need a contract change (mention metadata).
6. The album tile's quick remove (✕) became a ⋮ menu (cover, caption, remove).

**Update after connecting the app to the backend (server mode):**
- Format: clean (138 files). Analyze: clean.
- `flutter test -j 2`: **425 passed, 1 skipped (opt-in smoke test), 13 failed, all golden-only.** An unrestricted parallel run can exhaust memory on this machine, so use `-j 2`.
- Backend code and contract unchanged. A real-HTTP smoke run against `php -S` with `circle_dev` passed every step:
  - register 202, login, `/me`;
  - group and subgroup;
  - Memory, reaction, reply and save;
  - invite link preview;
  - photo upload refused calmly (503, no GD);
  - forced 401 → refresh → retry;
  - logout revokes.
- `backend/.env` is local, gitignored and 0600; its secrets aren't found in any tracked file.
- Not run on a device (no Android SDK here).

**Open questions from integration (for the owner):**
1. Add `my_emoji` and per-emoji counts to the Memory list (a contract change)? It would save requests and make cards exact.
2. Add `link_sharing` to `GroupSummary`?
3. Add a "my pending requests" endpoint with cancel?
4. Is a client-side 8-second Undo for Memory delete OK, or should the server get an Undo window?
5. Raise `RATE_LIMIT_PER_MINUTE` for real use?
6. Should new groups default to approval on (as in the preview) or the server's `auto`?

**Update after M4 private media (backend):**
- `composer test`: **OK, 118 tests, 1737 assertions, 4 skipped.** The skipped tests are the real GD image-processing tests: EXIF/GPS stripping and orientation, real resizing, PNG text chunks, end-to-end upload, corrupt image.
- `composer analyse`: PHPStan level 6 clean. Contract 0.3.1 parses and every `$ref` resolves; Redocly reports valid.
- A real-HTTP smoke test with `php -S` showed that uploads fail closed (503) without GD, signed downloads work, and tampered links get 403.
- **To fully verify:** run `sudo apt install php8.3-gd`, then `composer test` again; the 4 skipped tests should run and pass.

**Update after UI-6 (final UI phase):**
- Format: clean (107 files). Analyze: clean. Design guard: passes. `pubspec.lock` and the golden files are unchanged.
- **378 tests: 365 passed, 13 failed, all golden-only.** UI-6 visually changes `circle_home`, `circle_home_dark`, `circle_chats`, `circle_groups`, `circle_events` and `circle_you` (the search and bell icons, new rows on You, a mention in the Northbank chat).
- Rendered and reviewed: Home header with the bell badge, Activity, Search, Albums tab and album, Reports queue, Notifications, profile, You, and tablet two-pane Chats and Groups at 1280×800.
- Limitations:
  - spinners instead of skeletons on the new screens;
  - no album cover choice;
  - the @mention is a fixed sample;
  - the digest is a setting only;
  - tablet pane selection doesn't update the URL.
- Not run on a device.

**Owner decisions from UI-6 (confirmed by the owner, 23 Oct 2026, all kept as built):**
1. Search and the bell only on tab main pages; Search, Activity and profiles are full pages.
2. The badge counts personal items, including ones held during quiet hours.
3. Albums can start empty; admins can remove anyone's photos; only past, non-cancelled events get an album.
4. 1:1 reports go to the platform team; you can't report your own posts or duplicates.
5. Removing a reported subgroup also removes its descendants.
6. A visible "Report" text button under others' comments.
7. Chat mute and a group's notification level stay separate settings.
8. Appearance and End preview live under Account.
9. On events you can't manage, the ⋮ menu has only Report.
10. Listed subgroups appear in search and open their parent group.

**Update after the UI-5 follow-ups (activity status, share picker, leave rule):**
- Format: clean (79 files). Analyze: clean. **309 tests: 296 passed, 13 failed, all golden-only** (`circle_chats` also shows the new active-now dot).
- Rendered and reviewed: inbox dot, "Active now" header, privacy screen.

**Update after UI-5 (Chats):**
- Format: clean (77 files). Analyze: clean. Design guard: passes. `pubspec.lock` and the golden files are unchanged.
- **277 tests: 264 passed, 13 failed, all golden-only.** UI-5 visually changes `circle_chats`, `circle_you` and `circle_groups` (Northbank 2009 now has 57 fictional members).
- Rendered and reviewed: inbox, requests, 1:1 chat, group chat with a shared event, request conversation, new chat, details, privacy.
- Messaging is a local mock: no delivery, no timers, no fake presence or typing.
- Not run on a device.

**Owner decisions from UI-5 (answered by the owner, 23 Oct 2026; #1 and #10 changed, the rest confirmed):**
1. Northbank 2009 was enlarged with 52 fictional classmates (57 members), so the requests flow can be shown.
2. **Changed:** show activity status ("Active now / Active 2h ago") with a setting to hide yours, Instagram-style. Hiding yours also hides others' from you. Only shown between people who share a group and haven't blocked each other; 1:1 only.
3. **Resolved by the owner (23 Oct):** don't delete messages. After leaving or removal the group chat is disabled for that person: history up to that moment stays readable, they can't send, and they receive nothing new. ADR 0003 and the README were updated; the app already behaves this way (covered by a repository test).
4. "Nobody" blocks every incoming 1:1, including existing chats; you can still send to others.
5. "Chatted with" means the other person sent a message in your 1:1 or accepted your request.
6. Groups over 50 members start muted (standing in for "mentions only" until @mentions exist).
7. Messages from people you blocked are hidden in group chats too.
8. A single tap on a message shows time + Love / Reply / More (the visible alternative to double-tap and swipe).
9. The group Chat tab opens the chat in the Chats tab, so Back returns to the inbox.
10. **Changed:** the share picker lists only items that everyone in the chat can see. The render-time "isn't shared with you" check stays as a safety net.
11. Deleting a request has Undo; a newer message from that person brings the request back.

**Update after UI-4 (Events):**
- Format: clean (62 files). Analyze: clean. Design guard: passes. `pubspec.lock` and the golden files are unchanged.
- **212 tests: 199 passed, 13 failed, all golden-only.** UI-4 visually changes `circle_events`.
- Rendered and reviewed: Events tab; event pages (family function with deadline and capacity, reunion with date poll, full workshop, past picnic); attendees; the create form with More options.
- The month calendar view is deferred. Maps, calendar export, reminders and the event discussion thread need a device or backend.
- Not run on a device.

**Owner decisions from UI-4 (confirmed by the owner, 23 Oct 2026):**
1. Online events need a link and the place is optional; other types need a place and can add a link (hybrid).
2. With a date poll, the event date can be left empty; the earliest option is used until a host edits it.
3. Date polls are named, show results to everyone, are multiple choice by default, have no end date, and allow changing your vote.
4. RSVPs close when the event starts. "Past" means after the end time, or after the start if there's no end.
5. Cancelled events stay under Upcoming with a "Cancelled" pill.
6. New events default to type "Other".
7. Lowering capacity doesn't remove people already going; it only blocks new "Going" answers.

**Update after UI-3 (Memories):**
- Format: clean (52 files). Analyze: clean. Design guard: passes.
- **165 tests: 152 passed, 13 failed, all golden-only.** UI-3 visually changes `circle_home`, `circle_home_dark`, `circle_compose` and `circle_groups_g_friends`.
- Rendered and reviewed: Home, a Memory with photos and replies, a poll before and after voting, a closed anonymous poll, the photo viewer and compose.
- The test renderer has no colour-emoji font, so reaction emoji appear as boxes in Linux renders; devices use their system emoji font.
- Not run on a device.

**Owner decisions from UI-3 (confirmed by the owner, 23 Oct 2026):**
1. Tapping Love when you reacted with another emoji removes your reaction.
2. Poll settings sit under their own "More poll options".
3. Votes get Undo only when vote changes are allowed. Closing a poll asks for confirmation.
4. Results follow the visibility setting strictly; the creator gets no early peek.
5. "+N more" counts the photos beyond the three shown.

**Update after switching to "Luminous Pure Minimal":**
- Format: clean. Analyze: clean.
- **93 passed / 13 golden-only failures**; the design guard passes. All goldens need regeneration on Windows.
- Rendered and reviewed together: welcome, Home, Groups, group detail, Memory detail, Events, Chats, You and group settings.

**Update after the Stitch welcome screen:**
- Format: clean. Analyze: clean.
- **93 passed / 13 golden-only failures.** That includes the welcome accessibility checks (tap targets, labels, contrast), the 360/393/900 × 200%-text layout checks, and the design guard. The guard caught two raw avatars in the first draft; they were replaced with kit components.
- Rendered and reviewed: welcome at 393×1200 (light and dark) and at 360 px with 200% text.

**Update after applying the design system app-wide:**
- Format: clean (39 files). Analyze: clean.
- **106 tests: 93 passed, 13 failed, all 13 golden-only.** These need regeneration on Windows.
- The new design guard test passes. On its first run it caught a raw avatar, which was then fixed.
- Nine screens were rendered locally and reviewed together for consistency: welcome, Home, Groups, group detail, Memory detail, Events, Chats, You, invite.

**Update after the Warm Keepsake restyle:** format clean (38 files), analyze clean, **91 passed / 13 failed, all 13 golden-only**. The theme and font changed every screen, so **all 13 remaining goldens need regeneration on Windows**, including the three access goldens previously marked platform-only. Home, Groups, group detail and You were rendered locally (Linux, light and dark) and visually compared with the Stitch screenshot. These renders are for review only, not baselines.

Golden baselines were rendered on Windows. Before any changes, the original suite on this machine already failed 23 goldens, all platform rendering differences.

**Needs regeneration on Windows** (screens intentionally changed):
- `access_welcome`
- `circle_home`, `circle_home_dark`
- `circle_chats`, `circle_groups`, `circle_events`, `circle_you`
- `circle_groups_g_friends`, `circle_groups_new`, `circle_compose`

**Platform-only differences**, same pixel count before and after the changes:
- `access_register`, `access_login`, `access_register_dark`

The 10 legacy goldens were deleted along with the retired prototype. No golden was regenerated on Linux.

**New coverage:**
- membership rules: owner protection, admin promotion/demotion, last admin, cascade, owned-descendant blocking, parent membership at join and approval, hidden never listed, depth 10/11, invite policy;
- invite links: default 7-day expiry, usage limit, reset/turn-off, removed members needing a newer link;
- direct-invitation consent;
- group tree ordering;
- compose audience rules;
- return-destination policy;
- UI-2 flows;
- layout at 360×800, 393×852 and 900×1100 with 200% text and dark mode.

`integration_test/journey_test.dart` was updated but **not run**: no device.

## Backend (`backend/`)

| Command | Actual result |
| --- | --- |
| `composer install` | Passed using a temporary `COMPOSER_HOME`: the global GitHub token in `~/.config/composer/auth.json` returns HTTP 401 and needs refreshing |
| `composer test` | **OK (74 tests, 925 assertions)**, about 59 s, against database `circle_test` on MariaDB 10.4 |
| `composer analyse` | PHPStan level 6: no errors |
| `php -l` (all files) | No syntax errors |
| OpenAPI | Parses (28 paths, 35 operations, all `$ref`s resolve); `redocly lint` valid with 3 cosmetic warnings |
| HTTP smoke (`php -S`) | health 200, CORS preflight 204, register 202, login, `/me`, create group, create Memory 201 |

A mutation check confirmed the tests catch a removed approval-time parent check.

**Not verified:**
- MySQL 8 itself;
- deployment behind Apache/Nginx/PHP-FPM;
- load or race behaviour beyond the atomic updates;
- any production security property.

The `circle_test` database contains leftover smoke-test rows.

## Not validated

- Native Android/iOS rendering, keyboard, TalkBack/VoiceOver, performance.
- §4.0 task tests with real people.
- Client–server integration (intentionally not started until `openapi.yaml` is reviewed).
- Nothing here establishes production authentication, tenant security or approved visual equivalence.

---

# Phase 1 validation — 22 October 2026 (historical)

## Latest increment: navigation and feed reliability

Worked exclusively on `main`. The worktree was clean and `git pull --ff-only origin main` reported up to date before implementation. Fetched `origin/main` again before delivery; no concurrent remote commits appeared. No feature branches or pull requests were created.

Actual checks: `flutter pub get --enforce-lockfile` passed; `dart format --output=none --set-exit-if-changed .` passed on 18 Dart files with zero changes; `flutter analyze` passed with no issues; `flutter test` passed all **41 tests**, including the 10 existing golden comparisons without regeneration. One new brace-style lint was fixed before final validation.

New coverage verifies invitation return destinations, rejection of external/unknown/looping destinations, query/fragment preservation, session-end cleanup, ordinary entry to the feed, and scrolling to the hundredth post then opening its detail. Existing interactions, accessibility and narrow/tablet/dark/large-text checks continue to pass. Golden baselines are unchanged and remain provisional; no new manual native screenshot review is claimed.

`flutter devices` and `flutter emulators` again found no Android device or emulator. Native interaction, Android build, TalkBack and keyboard validation remain outstanding. No new web or APK build was run for this increment. `codex mcp list` still provides no configured Context7/Figma/Playwright integration; current primary Flutter/go_router docs were used without installing MCP servers or dependencies.

Modified areas: app route policy/router, lazy feed presentation, regression tests, main-only CI and workflow/development/architecture documentation. No backend or real accounts/media were introduced. Native OS app links are not registered; the new return policy applies to in-app go_router destinations.

## Initial prototype validation (historical)

Environment: Windows, Flutter stable 3.44.8, Dart 3.12.2, Node 22.16.0. PHP is not on PATH; no backend work was attempted. The original repository had only README.md and CODEX_START_PROMPT.md and no Git history. Current work is on `main` only.

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
