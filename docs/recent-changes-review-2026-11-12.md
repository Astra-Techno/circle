# Recent changes review — 12 November 2026

Reviewed application source **81800fd3b59af292c08073157084528133e84ba0** (`main`, 12 November07:50 IST). The workspace started at `c4ac0fd` on an existing `work` checkout. Its112 subsequent upstream commits were pulled safely; the checkout is now named `main`, the old commit remains an ancestor, and no user edits were discarded. The focused recent-change window is the11 commits after the verified vote fix `169f9f4` (117files,8217insertions/862deletions).

**Decision: do not publish this revision publicly yet.** The visual system has progressed and the new backend baseline tests pass, but the new feature wiring is incomplete, Capsule contributions discard their text, a new search visibility gap is reproducible, and the ordinary Flutter quality pipeline is red. This review changes documentation only; no production fix, deployment, baseline replacement or app rebuild was performed.

## What changed

| Commit/date | Change | Practical effect |
|---|---|---|
| `83a50e9`,7Nov | Theme-based destructive actions and updated golden files | Styling/baseline update; does not establish later changes pass image comparisons. |
| `f5480ed`,8Nov | Memory Capsule domain, local repository, screens and glass tokens | Adds list/create/detail, seal/contribute/delete and countdown UI. It is still device-local in Flutter. |
| `414bba9`,8Nov | Home, Circles, composer and Capsule elevation | More shared glass, animation and layout treatment. |
| `7f2aae2`,8Nov | Country code dropdown height | Aligns the dial-code control with the56px mobile input. |
| `c3ee4ac`,9Nov | Floating glass Home header and pinned-circle refinements | New header/composer presentation and less duplicate tree chrome. |
| `367a7bd`,9Nov | Design mockups and header concepts | Reference documentation/assets; no extra backend behavior. |
| `3dfd38d`,9Nov | Bold flat Home action icons | Refines Search/Alerts and documents their style. |
| `0c91cdb`,11Nov | Style-A coloured icon tiles throughout the app | Shared `CircleActionIcon`, selected/tinted actions and preserved Profile avatar. Existing routes remain. |
| `9c2f9da`,11Nov | Capsules, Albums, Search, Activity and comment deletion APIs | Adds19 authenticated routes, four migration files, five controller/test families, and a separate synthetic-persona CLI runner. |
| `0f7d9cc`,12Nov | Shared error/retry states, shimmer skeleton and motion | Consolidates loading/recovery across many pages; introduces a continuously animating loading skeleton. |
| `81800fd`,12Nov | Dart formatting | Fixes format-check failures; no feature change. |

## Backend and mobile are at different integration stages

| Feature | New backend | Current Flutter behavior | Remaining work |
|---|---|---|---|
| Capsules | Group listing/create/detail, contribution listing/create, seal/delete; SQL026 | `LocalCapsuleRepository` via local secure settings. Server APIs are not called. Capability is deliberately shown per the10Nov owner decision. | Preserve actual entry data, account/session safety, then connect the server or explicitly retain the agreed local scope. Backend creation uses `unlock_days`; local domain uses an absolute `unlockAt`, so an adapter is needed. |
| Albums | CRUD and photo membership/caption operations; SQL027 | `MockAlbumRepository(showcase:false)` remains wired; Albums capability is not enabled in server feature sets. | Real repository, private-media validation, media lifecycle/cover rules and contract mapping before enabling. |
| Search | New `/search` across Memories, people, events, polls and groups | Existing workspace search plus the existing paginated Memory `q` search. It does not call the new cross-category `/search` route. | Repair visibility gap, then wire results, paging and response IDs/types. |
| Activity inbox | List, unread counts, mark-read and record helper; SQL029 | Mock notification repository; Activity capability remains unavailable. | No production caller of `ActivityController::record` was found. Wire event producers, current-access/privacy rules and mobile repository. A table/helper alone will not populate the inbox. |
| Comment deletion | New authenticated DELETE route with author/admin checks | API Memory repository still returns `notOnServerYet(commentDeletion)`; UI capability is not enabled. | Client repository/action and refresh/tombstone semantics. |

Relevant source: `mobile/lib/features/capsules/application/capsule_providers.dart`, `capsules/data/local_capsule_repository.dart`, `albums/application/album_providers.dart`, `notifications/application/notification_providers.dart`, `search/application/search_providers.dart`, `workspace/data/api/api_memory_repository.dart`, and `workspace/domain/circle_features.dart`.

## Confirmed findings

### P1 — New search exposes hidden poll metadata

`SearchController.php:62` searches polls by membership and question without applying the linked Memory visibility rule. The existing Poll controller correctly denies a poll whose published Memory is hidden.

A fictional database probe created a poll, hid its Memory, confirmed normal poll detail returned404, then requested `/search?q=hidden` as another current member. Search returned the hidden poll's ID, group/name and question. This is a reproducible bypass of the existing hidden-content behavior, **not** a claim that an outsider can read arbitrary groups.

Repair by sharing the existing poll visibility conditions, including linked Memory/Event checks, and add hidden/deleted content tests to Search. The mobile search currently does not use this endpoint, but authenticated callers can still reach it.

### P1 — Capsule contribution text is discarded

The UI collects text and invokes `addEntry(capsule.id,text)`. `LocalCapsuleRepository.addEntry` at line104 never uses `text`: it replaces metadata and increments `messageCount`. Its encoder stores title/message/counts, not contribution entries. This behavior is visible directly in source; no native-device reproduction is claimed.

The local-only interim scope was owner-approved. Discarding the entered text is a separate data-integrity defect. Preserve each contribution and its author/time, make it readable after unlock, and test restart/seal/unlock behavior before presenting this as a reliable Capsule feature. The new server storage is not automatically used by the current app.

### P1 — Current Flutter quality pipeline is failing

[Windows run43140698351](https://github.com/Astra-Techno/circle/actions/runs/43140698351), on the exact reviewed source, reports **816passed,15failed,1skipped**. Format, bundled-font checks and analysis passed.

- Fourteen failures are actual Windows golden comparisons, not Linux renderer differences.
- One additional failure is `Saved uses Home cards; another author is excluded from Your Memories`: `pumpAndSettle timed out`.
- The newly repeating shimmer can prevent settling while a loading placeholder is present. That is a strong explanation to investigate, not proof that Saved data itself is lost. Use bounded waiting or disabled animation in an appropriate test, while retaining assertions that the desired data/state appears. Do not remove the assertion or blindly regenerate images.

Review intended visual changes on Windows, fix the timeout and run the ordinary comparison suite. A successful iOS compile/upload does not replace this gate; its workflow ran a smaller focused guard set.

### P1/P2 — Albums accepts invalid photo references

`AlbumController.addPhoto` checks that `media_id` is nonempty but does not verify the asset exists, is ready/visible, or belongs to the album's exact group. A fictional probe sent a nonexistent UUID and received201, with an album-photo row created.

Require valid same-group accessible media and appropriate lifecycle checks; similarly validate cover references. This proves an integrity/scope-validation gap, **not** that unauthorized photo bytes can be downloaded—media read authorization was not bypassed in this probe. Existing Album tests themselves use dummy unbacked IDs, so a green baseline does not cover this requirement.

### P2 — Static-analysis gate fails in the new persona runner

Fresh PHPStan at the repository's configured level reports **22errors**, all in `backend/tests/agents/run.php`: missing iterable types, an extra argument to `ApiClient::post`, and an always-true type check. Production controllers did not produce these22errors.

The runner is a scripted synthetic API client, not independent AI agents. It supports a remote API URL, disables TLS verification, writes account state, and can create real data. It was **not executed** in this review. Before using it, restrict it to an approved test environment, restore TLS verification, protect/ignore credential-bearing state, and fix the static errors. Running PHPUnit does not run this CLI simulation.

### P2 — New routes are absent from the reviewed API contract

The backend adds19 routes, but `docs/api-contracts/openapi.yaml` was not updated in the recent window. Finish request/response/error/privacy schemas and frontend/backend review before client integration. Do not enable broad capability families merely because controllers now exist.

### P2 — Capsule account isolation and write durability need tests

`capsulesProvider` is a persistent AsyncNotifier whose `build` reads the account-scoped repository with `ref.read` rather than subscribing to it. No Capsule invalidation was found in logout/account switching. Its local storage key includes viewer ID but not API/server identity. This creates a source-backed stale-account/server risk requiring a direct A→logout→B test; it has not been reproduced on a device here.

`_persist` also uses an optional-setting helper that swallows storage exceptions. A successful UI operation can therefore outlive only in memory. Treat Capsule data persistence errors as actionable failures rather than optional-settings failures.

## Schema/deployment implications

- **026** creates `capsules` and `capsule_entries`.
- **027** creates `albums` and `album_photos`.
- **028** is an intentional `SELECT1` sequence placeholder; comment hiding uses an existing status column.
- **029** creates `activity_items`.
- Migrator now executes statements with query/closeCursor, including result-producing placeholder statements; it also drains its migration-list cursor. Database explicitly enables buffered queries. A fresh `circle_test` bootstrap applied the migration set and the279baseline tests passed.
- The earlier owner confirmation that voting works establishes deployment of that vote fix, not that SQL026–029 has been applied today. The normal hosting deployer copies backend source and applies pending SQL when run. This review did not deploy or inspect the production database.

## Build and release state

- App source is **1.0.38+44**, interface direction Social2.6.
- Published Android metadata/download is still **1.0.37(43)**. It does not include these11recent commits. A new verified Android artifact/publication is needed for the current source to appear on Android.
- [iOS run43145846974](https://github.com/Astra-Techno/circle/actions/runs/43145846974) successfully signed and uploaded the reviewed source. Logs verify **1.0.38(1070.1)** and `UPLOAD SUCCEEDED with no errors,1warning`. Apple processing, tester installation and App Store approval are separate.
- Apple warning90068 is the future iOS15 minimum for uploads starting April2027; the current iOS13-target upload succeeded. It is not the reason Windows CI failed.
- Earlier public-launch blockers remain visible: no account-deletion route/UI, placeholder website privacy/community links, and no new recovery/export implementation in this window. Those need completion/operational review before a public store release.

## Verification and evidence

- Safe pull: application HEAD and `origin/main` both81800fd before documentation updates; previous c4ac0fd retained as ancestor. Branch renamed to existing policy name `main` without dropping history.
- Fresh backend PHPUnit: **279tests/5099assertions passed**, dedicated `circle_test` only.
- Fresh PHPStan: **22errors** in the persona runner, recorded without a baseline suppression.
- Two additional adversarial review probes: **2failures/23assertions**, demonstrating hidden-poll search exposure and acceptance of nonexistent album media. These are deliberately absent from the ordinary279tests; no failing runnable test was committed into the normal suite.
- Current-source Flutter and iOS results were inspected through GitHub job logs. Flutter SDK is not installed in this restored local workspace; no new local Flutter run or device render is claimed.
- No real accounts, production database, live photo throughput, physical devices, screen readers, store consoles, or backup/restore were tested.

Evidence: [CI excerpts](review-evidence-2026-11-12/ci-evidence.json), [backend suite](review-evidence-2026-11-12/backend-tests.txt), [static-analysis errors](review-evidence-2026-11-12/backend-static-analysis.txt), [probe results](review-evidence-2026-11-12/adversarial-probes.txt), [non-executable probe source](review-evidence-2026-11-12/RecentReviewTest.php.txt).

## Next implementation order

1. Preserve Capsule contribution text and clear/scope Capsule state correctly; close the hidden-poll search gap and validate album media before deployment/enabling new clients.
2. Repair the Saved timeout, review Windows image changes and restore the normal green quality gate; fix persona-runner static errors without suppressing them.
3. Update the API contract and complete scoped server/client integrations, Activity producers and feature-specific acceptance tests. Keep the agreed capability limits truthful.
4. Confirm staging migrations026–029 and real-device behavior; build/publish the matching Android44 artifact only after the completed batch is verified.
5. Finish deletion/privacy/recovery/support/store-readiness work, then do a two-account/device acceptance pass before public release.
