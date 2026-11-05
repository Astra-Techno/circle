# Page query and image-loading audit — 5 November 2026

Scope: every registered page family in `mobile/lib/app/circle_experience.dart`, nested group tabs, related providers/repositories, image widgets and corresponding PHP read endpoints. This is a source/request-count audit with fictional fixtures, not a production SQL-plan or physical-device timing claim. Version1.0.31+36; Account interface Social1.6.

## Changes implemented in this batch

1. Poll lists batch options/counts, current-user votes and voter totals for the returned page; group name and management role come from the authorized list query. Hidden counts, anonymous identities and exact-group permissions remain enforced. The voters page checks result visibility without constructing an unused full poll payload.
2. Moderation queues join the relevant content and batch reason totals; no per-target content/reason reads. Reporter identity and notes remain excluded. Mutation authorization/locking is unchanged.
3. Uploaded Memory photos and person avatars start their providers only near the visible viewport. Visibility intersects the screen and all ancestor scroll viewports, including shrink-wrapped grids, and respects hidden tabs. A192px prefetch margin is used; activated children retain their own live authorization checks. No image bytes are stored by this helper.
4. Deferred photos use static placeholders. The pagination sentinel animates only while a page request is actually running, avoiding perpetual off-screen spinners.
5. Circle cover previews use320px thumbnails only when the display density/crop budget fits. High-DPI list covers retain medium renditions; profile/group banners are unchanged. Thumbnail bytes use the existing bounded45-second/64-entry session-scoped cache after membership/version checks, separately keyed from banner variants.
6. Remote Memory search is debounced300ms; local group/person matching stays immediate, submit/recent-query selection is immediate, stale results are hidden while typing. Pagination UI flags are reset and guarded when the query changes.
7. Signed photo-link failures show the existing explicit Retry action instead of repeated automatic retries and prolonged loading. Session/token refresh behavior is unchanged.
8. Devices/security controls load server session rows before optional platform-label collection, which runs in the background. Group settings and roster refresh requests run concurrently and both complete before the refreshed group is exposed.

## Page-by-page coverage

| Page / routes | Data and image path | Audit outcome |
| --- | --- | --- |
| Welcome, login, registration: `/`, `/login`, `/register` | Auth/token restore; local branding; explicit country lookup | Retain authoritative session validation; no image fan-out or eager contact/location lookup |
| Home: `/home` | Workspace plus20-Memory pages; signed photos; person avatars | Prior parallel hydration and page-scoped comment SQL retained; viewport gating now also protects eager/nested contexts |
| Memory detail/comments: `/home/memory/:id` | Authorized detail with comments/reactions; image tiles | One detail resource; thread visibility retained; photo and avatar work deferred until near viewport |
| Memory full-screen photos: `/home/memory/:id/photos` | Signed full rendition for the selected photo | Full2048px rendition/zoom retained; no preview decode cap applied to full viewer |
| Compose: `/compose` | Existing workspace choices; local picked previews; uploads after group selection | Existing336px local preview decode budget retained; uploads remain explicit and permission-scoped |
| Photos gallery: `/photos` | Authorized workspace photos/older pages | Same viewport-gated uploaded-photo widget; no fetching every grid image merely to lay out the grid |
| Search: `/search` | Local corpus plus paged `/memories?q=` | Fixed per-keystroke remote reads; retained literal substring semantics and session-local recents |
| Circles: `/groups` | Authorized workspace tree; group avatar/cover variants | Density-aware cover thumbnails; shared bounded avatar/thumbnail reuse; no new API per row for names/counts |
| Group overview and Memories tab: `/groups/g/:id` | Workspace/group refresh and scoped20-Memory pages | Parallel independent refresh; viewport-gated media even inside eager Columns; visible-cursor pagination retained |
| Group members/requests/subgroups tabs | Existing hydrated roster/tree and permission-sensitive actions | Paged UI and deferred avatars; complete role/parent-membership checks retained |
| Group creation/subgroup sheet: `/groups/new`, `?parent=…` | Workspace choices; create only on submit | No speculative write or media load; keyboard-aware sheet retained |
| Group settings: `/groups/g/:id/settings` | Fresh group settings/roster and writes on submit | Independent reads parallelized; authorization still completes before returning the group |
| Contact invitation: `/groups/g/:id/invite` | Explicit contact selection/invitation | No contact upload or public lookup; no unrelated image requests |
| Group link sharing: `/groups/g/:id/invite/link` | Scoped link/read/reset operations | Permission-sensitive reads retained; reset remains a write, not cached for speed |
| Link preview: `/invite/:token` | One preview future per token, reloaded on token change/explicit retry | Retained stable FutureBuilder future; no private photo directory exposure |
| Invitation inbox/detail: `/you/invitations[/:id]` | Paged list or direct detail lookup | Existing joined payload is not N+1; detail route does not scan list pages; existing block/session guards retained |
| Chat inbox: `/chats` |30-conversation page and current state | Prior viewer-scoped candidates/page-only unread counts retained; initial empty-outbox reload eliminated in prior batch |
| Direct/group conversation: `/chats/c/:id`, `/chats/g/:id` |50-message keyset page; batched metadata; private medium photos | Prior constant-count SQL retained; visible-route polling/lifecycle guards preserved |
| New chat: `/chats/new` | Paged exact-shared-group contacts | Existing single joined contacts query retained; avatars deferred, no global directory search |
| Chat privacy: `/chats/privacy` | One scoped settings resource, write on change | Retained explicit invalidation and session checks; no photo work |
| Events: `/events` |30-event page, pure SQL-row payload formatting, lazy sliver cards | No per-event payload queries found; existing lazy cards/medium covers and capped entrances retained |
| Event detail and attendees: `/events/e/:id[/attendees]` | Authorized event, RSVP aggregates, paged attendees | Bounded queries; no per-attendee reads; avatar work deferred |
| Event create/edit: `/events/new`, `/events/e/:id/edit` | Workspace choices and one detail on edit | Timezone data initialized once; uploads/writes remain explicit |
| Poll lists: `/polls`, group/event contexts | Authorized30-poll page | Removed per-poll SQL fan-out with page batches |
| Poll detail: `/polls/p/:id` | One authorized poll with options/results | Bounded detail reads; privacy gating shared with voter endpoint |
| Poll voters: `/polls/p/:id/voters` | Paged named votes, only where permitted | Removed unused payload reads; anonymous/hidden identities still denied |
| Poll creation/options: `/polls/new`, detail actions | Context choices and validated writes | No eager list preload or speculative writes |
| You / own Memories / Saved: `/you` | Account photo, workspace grid and scoped saved pages | Deferred grid images and avatars; stable cursor state; own photo remains account/version scoped |
| Person profile: `/people/:id` | Exact shared-group workspace data plus private avatar/cover | No public directory lookup; photo access checks retained; avatar starts near viewport |
| Edit profile/photos: `/you/edit` | Own photo variants and explicit edits | Existing medium cover/thumb avatar variants retained; no private disk cache added |
| Blocked accounts: `/you/privacy` | Paged label snapshots and explicit unblock | Existing indexed scoped reads retained; no per-row profile lookup |
| Notifications: `/you/notifications` | Scoped preference/connection providers | Shared providers retained; permission/token registration stays outside blocking page rendering |
| Account/password: `/you/account[/password]` | Existing session/account state; sensitive actions on submit | No background export/delete/password work; fresh authorization preserved |
| Devices: `/you/account/sessions` |30-session page and optional platform metadata | Removed optional metadata from security-controls critical path |
| Moderation: `/groups/g/:id/reports` | Authorized target page and bounded audit history | Removed content/reason N+1 queries; anonymity and exact-group admin guard retained |
| Activity/albums routes and overlays | Features without live server APIs remain gated | No fabricated live requests or background preload introduced |

## Image policies checked

| Source | Budget and lifecycle |
| --- | --- |
| Memory preview/grid | thumb320 or medium1080; bounded/bucketed decode; private signed URL; near-viewport start |
| Memory full viewer | full2048; original detail/zoom preserved |
| Person/avatar rows | server thumb; near-viewport start; existing session/version-scoped byte reuse |
| Circle covers | density-aware thumb or medium; variant-specific keys; membership checked before cache access |
| Group/profile banners | existing medium rendition; large-cover byte retention unchanged |
| Chat/event private photos | existing authenticated medium bytes; lazy list placement; authorization follows current scope |
| Composer previews | local bounded decode already present; no network just to preview a selected upload |
| Branding/fallbacks | bundled local assets/initials; no external image hosts |

## Verification

- Poll list:6 SELECTs for1 poll and6 SELECTs for10 polls.
- Moderation queue:6 SELECTs for1 target and6 SELECTs for10 targets.
- Previous chat measurement retained:10 SELECTs for1 message and10 SELECTs for50 messages.
- Complete backend:236 tests/4408 assertions passed on circle_test; PHPStan level6 clean.
- Mobile:63 focused checks passed, followed by a two-case pagination/query-switch rerun and5 shared-layout checks covering108 renders, including nested-grid deferral, no off-screen spinner/network work, explicit retry, one settled search query, density-aware cover quality, cached-variant separation/revocation, device controls and repository permissions. Format/analyzer clean. Full Windows comparison CI [41986651549](https://github.com/Astra-Techno/circle/actions/runs/41986651549) passed738 tests/1 skipped; no Linux golden replacement.

## Remaining measured-follow-up candidates

- Workspace startup still hydrates joined-group rosters/settings with bounded concurrency. The domain uses those roles/relationships for group operations and profile/chat eligibility. A summary/on-demand model needs coordinated API/domain work; this audit does not silently substitute incomplete membership maps.
- Saved/group timelines still use eager container layout. Network/image activation is now deferred, but sliver-based composition would further bound retained widgets after many pages; that is a separate route-layout change.
- Literal `%substring%` search and very deep offset pages can be expensive at large data volumes. Full-text matching or cursors would change current semantics/contracts. Profile representative production data and query plans before changing them; no speculative indexes were added.
- No production latency, cold-start, memory or network-byte reduction is claimed from fixture counters. Those require installed-build/network profiling.

## Delivery

Existing `backend/deploy/deploy.php` copies backend source and runs pending migrations. No new migration is required for these query rewrites. Run the existing deployment link after this commit to activate server changes; a Git push is not proof of live deployment. Install the new mobile build for viewport/search/device-loading changes. Android signing credentials are still absent here, so no replacement APK/download metadata is published.

Release result: [TestFlight41986651454](https://github.com/Astra-Techno/circle/actions/runs/41986651454) completed signing, verification and App Store Connect upload successfully from75379df. Signed job duration12m29s. Source version1.0.31+36, interface Social1.6. Apple processing and physical-device acceptance are separate; backend deployment remains unverified here.
