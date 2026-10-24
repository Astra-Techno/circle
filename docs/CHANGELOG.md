# Unreleased (23 Oct 2026, not committed)

## Docs restored and updated
- The README, AGENTS.md, CODEX_START_PROMPT.md and the design-system, architecture, development and API-contract docs were restored with the product model:
  - any-community scope, 10-level nesting, roles, invites, approval, listed/hidden, cascade;
  - Memories naming, Instagram Direct–style chat, events with guest RSVPs, polls;
  - the UI plan with §4.0 ease-of-use and calm rules.
- They also now cover ADR 0005 (mobile + password) and the backend draft (ADR 0006), and add a warning not to leave shared docs uncommitted.
- Added ADR 0006 and decisions 7–14.

## Mobile: remaining UI items (preview mode; skeletons in both modes)
- **Skeleton loading:** static, reduced-motion-safe skeletons (`CircleSkeleton*`) replace spinners for list loading.
- **Events:** a List | Month calendar for Upcoming (Monday-first, 48px day targets, spoken event counts, DST-safe `EventCalendar`).
- **@mentions** in group chats and comments:
  - only members of that exact group are suggested;
  - mentions are emphasised in the text;
  - they create personal Activity items (badge, push toggle, quiet hours, mutes);
  - "mentions only" big groups now let real mentions through.
- **Forwarding:** text and shared cards to up to 5 chats; ineligible targets are skipped with a calm note; a "Forwarded" label.
- **Chat:** photos (fictional scenes) with grid, viewer, reactions and replies.
- **Albums:** cover choice (with Undo) and photo captions (≤ 140). Optional per-photo captions in Memory compose (preview only).
- **Server mode:** these features stay gated; comment @mentions are sent as plain text.
- **Tests:** 476 passing (51 new).

## Mobile: app connected to the backend (server mode)
- **Dual mode:** preview (default, fictional) or server (`--dart-define=CIRCLE_API_BASE_URL=…`).
- **Dependencies:** dio 5.11.1, flutter_secure_storage 11.2.0, image_picker 1.2.4, crypto 3.0.7, uuid 4.6.0.
- **Accounts:** register (202) → automatic login, session restore, logout clearing tokens and caches, refresh with rotation and calm error messages.
- **Real data:** groups and subgroups, members and roles, invite links (create, reset, turn off, preview, join), join requests, Memories with cursor paging, comments and replies, reactions, saves, edit, delete (8-second client Undo).
- **Real photos:** picker (≤ 10, 2048 px, quality 80), upload with progress and retry, signed-link display (thumb and medium), a calm message on servers without GD.
- **Not yet on the server:** events, polls, chat, albums, activity, notification and privacy settings, reports, direct invitations. Each shows "Not on the server yet".
- **Platform:** Android INTERNET permission, `allowBackup=false`, cleartext only in debug; iOS photo-library text.
- **Tests:** 425 passing, plus an opt-in real-HTTP smoke test. A real run against PHP passed (register → group → Memory → refresh → logout).

## Backend: M4 private media (contract 0.3.1)
- **Endpoints:**
  - upload tickets (`POST /groups/{id}/media/uploads`): membership, type and size limits, per-user rate and open-upload caps, idempotent `client_upload_id`;
  - content upload: real-type sniffing, SHA-256 check, dimension and decompression-bomb guards, re-encoding into thumb/medium/full with metadata removed, original never stored;
  - signed ~5-minute view links re-checked against exact-group membership on every request, and signed downloads with security headers;
  - discarding unattached uploads;
  - `media_ids` on Memory creation (same group, own, ready, unattached, at most 10). Memories now return `media: [{id,width,height}]`.
- **Storage:** `MediaStorage` with private local storage outside the web root.
- **Cleanup:** `composer media:cleanup` for orphans and retention.
- **Tests:** 118 backend tests passing (4 GD-dependent tests skipped until `php8.3-gd` is installed). PHPStan clean.

## Docs: private media design (ADR 0007)
- Added ADR 0007 covering private storage, server re-encoding (EXIF/GPS removed), thumb/medium/full sizes, signed 5-minute view links re-checked for every request, retention and cleanup.
- `openapi.yaml` 0.3.0-draft: a "Media (planned)" tag with upload ticket, content upload, signed link, file download and discard endpoints, plus a planned `media_ids` field on Memory creation and new error codes.
  - All marked `x-status: planned`; not implemented.
  - Redocly lint: valid (the same 3 cosmetic warnings as before).

## Mobile: UI-6 (mock), the final UI phase
- **Albums:** per-group albums with an optional era; fictional scene photos; add, remove with Undo, rename, delete with confirmation; photo viewer; "Photos from <event>" albums for past events.
- **Activity inbox (bell):** Today/Earlier, mark read, tap-through with access re-checks. The badge counts only personal items (DMs, mentions and replies, invitations, approvals, your events, join requests for admins).
- **Search:** groups, people, Memories, events and messages, strictly scoped:
  - exact membership;
  - hidden subgroups only for members;
  - blocked people excluded;
  - chat history frozen at the time you left.
- **Notification settings:** push (personal) vs inbox/digest, quiet hours 10 PM–7 AM by default, daily digest, per-group levels (more than 50 members defaults to mentions only), muted chats.
- **Reporting and moderation:**
  - a shared report sheet (7 reasons and a note) for Memories, comments, messages, events, members and subgroups;
  - an admin Reports queue with Hide/Unhide, Remove member, Dismiss and an audit trail;
  - parent admins can remove a reported subgroup without reading it.
- **Profiles and You:** profiles at `/people/:id` (groups in common, Message, Block, Report). You is reorganised: Activity, Notifications, Privacy, Account. Deletion and export are marked "comes before launch".
- **Tablet two-pane (≥ 840 px):** Chats, Groups and Events.
- **Tests:** 365 passing (69 new).

## Mobile: UI-5 follow-ups (owner answers)
- **Activity status:** "Active now / Active Nm ago / Active Nh ago / Active yesterday", Instagram-style.
  - Shown in the 1:1 header, as an inbox dot (active now only) and in the New chat list.
  - A "Show activity status" privacy setting (reciprocal); hidden across blocks, without a shared group, and while a request is unaccepted.
  - Pure `ActivityRules`, plus the `CircleAccents.activeDot` token.
- **Share picker:** only offers Memories and events everyone in the chat can see, and the repository refuses anything else.
- **Leaving a group** freezes its chat read-only (ADR 0003 updated).
- **Tests:** 296 passing.

## Mobile: UI-5 Chats (mock, not real-time)
- **Conversations:** a group chat for every group (membership mirrors the group) and 1:1 chats between people who share a group.
  - Seeded history includes a message request from a 57-member group, shared Memory and event cards, a group poll, and a Memory you can't see.
- **Rules (`ChatRules`):**
  - DMs only between people who share a group, subject to "who can message me" and blocks either way.
  - Requests unless you share a close group (≤ 50 members by default, editable).
  - Edit within 15 minutes; unsend any time.
  - 8-emoji reactions.
  - Duplicate sends ignored (client message IDs).
  - Shared items re-check the viewer's access ("This Memory isn't shared with you").
- **Inbox:** Chats/Requests tabs, search, pin, mute (8 h / 1 week / always), archive with Undo, and an Archived list. Every action works from a ⋮ menu, long-press or swipe.
- **Conversation:**
  - grouped bubbles (indigo outgoing, recessed incoming), time separators;
  - double-tap ❤️, a long-press menu, and a single-tap action row as the visible alternative;
  - swipe or menu to reply; Copy, Edit, Unsend with Undo, Report (local);
  - "Seen" / "Seen by…"; share Memory/event; polls via the shared poll editor and card.
  - Request bar: Accept / Delete / Block.
- **Details:** mute, pin, shared items, members, block (confirm) / unblock (Undo), report.
- **Privacy:** `/you/privacy` with "Who can message me", close groups and blocked people.
- **Entry points:** "Reply privately" on Memories opens the 1:1 with the Memory attached; the group Chat tab opens that group's chat.
- **Tests:** 264 passing (65 new).

## Mobile: UI-4 Events (mock)
- **Typed events:**
  - type, hosts and co-hosts, start/end in UTC with the planning time zone ("IST");
  - place and/or online link, description;
  - RSVP deadline, capacity, cancelled and edited states.
  - 7 fictional seed events, including one that's full, one with a date poll, a past one and a hidden-subgroup one.
- **RSVP:** Going/Maybe/Not going, guest stepper (0–20), optional note, instant save with Undo, Clear.
  - Capacity counts Going people plus their guests (Maybe doesn't count).
  - RSVPs close at the deadline or start; past and cancelled events are read-only.
- **Events tab:** Upcoming/Past, month headers, group filters, rich cards, and a "New event" button shown only where allowed.
- **Event detail:** copy buttons for place and link (no fake maps or calendar links), attendee summary, attendees screen with tabs, the date poll (shared `PollCard`), and Edit/Cancel for hosts and admins.
- **Create/edit form:** group, title, type, date/time and place up front; end time, description, link, deadline, capacity, co-hosts and a 2–6-slot date poll under More options.
- **Groups:** a "Who can create events" setting (Everyone / Admins only); each group's Events tab lists its events with Create.
- **Rules:** `EventRules` plus `MembershipRules.canCreateEvent`, with exact-group checks on every action.
- **Bug fix:** a deep-link paint crash on event pages.
- **Tests:** 199 passing (47 new).

## Mobile: UI-3 Memories (mock)
- **Comments:** typed comments with one level of replies ("Replying to …"), and authors can delete their own with Undo.
- **Reactions:** an 8-emoji allowlist matching the backend (❤️ 😂 😮 😢 🙏 👍 🎉 🔥), one per person.
  - Love toggles ❤️; long-press or the "Choose a reaction" button opens the picker.
  - The summary shows the top 3 emoji and the total, with a counts sheet.
- **Photos:** placeholders from 10 fictional illustrated scenes.
  - The card grid is 1, 2, or 1 large + 2 small with "+N more".
  - A full-screen viewer (`/home/memory/:id/photos`) supports swipe and previous/next.
  - Compose has "Add photos" (up to 10).
- **Polls in Memories:**
  - 2–12 options, single or multiple choice, anonymous or named, closing time, results visibility, change vote.
  - Result bars, "See who voted" (named polls only), and closing by the creator or an admin (with confirmation).
- **Optional "Taken in" year and place** under compose More options.
- **Editing your own Memory:** a ⋮ menu offers Edit (marked "Edited") and Delete with Undo.
- **Rules:** pure domain code (`MemoryRules`, `PollRules`, `ReactionRules`, `CommentRules`). The mock repository re-checks exact-group membership on every action and hides results or voters per the poll's settings.
- **Fixes after review:** the "+N more" badge no longer covers the photo label; snackbars are flat; the members sheet opens above the nav bar.
- **Tests:** 152 passing (59 new across domain rules, the repository and widget flows).

## Mobile: "Luminous Pure Minimal" design system
- **Theme:**
  - pure white canvas and cards with `#EAEDF5` hairlines;
  - indigo `#1B223C` actions;
  - slate text tiers (`#1A1D2E` / `#475467` / `#667085`), monochrome accents;
  - new type scale with negative tracking (body kept at 16px);
  - radii: 4/8/10/12/16/24/pill;
  - 640px content width.
- **Components:**
  - 48px buttons, 12px radius; secondary buttons are white with a hairline;
  - chips are white with a hairline, or solid indigo when selected;
  - the nav bar's selected item is a solid indigo pill with a white icon;
  - the FAB is a 16px rounded rectangle.
- **Lists:** rows now use the new `CircleRow` with hairline dividers instead of one card per row (groups tree, members, invite candidates, chats, You).
- **Welcome:** Log in is now a secondary button.
- **Home:** chips lost their colour dots (monochrome design).

## Mobile: welcome screen from the owner's Stitch design
- Logo, wordmark and tagline; a keepsake collage built from kit components (no photos of people); the headline "Your people. Your moments. Your circle."; three privacy promises.
- Buttons: **Create account →** (primary) and **Log in** (lavender tonal), plus the quiet fictional-tour link.
- "I Have an Invite" is deferred until invites work for new accounts. The legal footer is omitted until those documents exist.
- Added the `CircleTone.surface` kit tone. The headline caps text scaling at 1.3× and the decorative collage doesn't scale, so nothing breaks mid-word at 200%.

## Mobile: one design system across the whole app
- `circleTheme()` now styles every Material component: list rows, switches, checkboxes, radios, tabs, dialogs, bottom sheets, menus, dropdowns, segmented buttons, badges (indigo, not red), tooltips, progress bars and snackbars.
- New tokens: `CircleRadius` (small/tile/inner/card/sheet/pill) and `CircleInsets` (page/form).
- New kit components:
  - `CircleTone` and `circleToneColors()`, plus `circleTypeTone()` for group types;
  - `CirclePill`, `CircleInitialAvatar` (4 sizes), `CircleSectionTitle`;
  - a calmer `CircleHeading`;
  - `CommentBubble`.
- Every screen moved onto the kit: Home, Memory detail, compose, Groups, group detail, members, invite, settings, invite link, Events (new card: group pill, teal date/place icons), Chats, You, welcome/register/login, and loading/error.
- The welcome artwork drops its gradient.
- Added `test/design_system_guard_test.dart`. It fails on hardcoded colours, fonts, radii, padding, gradients, raw avatars or network images in feature code.

## Mobile: "Warm Keepsake" visual direction (owner's Stitch design)
- New theme: indigo/linen with lavender, coral and teal accents (`CircleAccents`). Plus Jakarta Sans is bundled (OFL) and Roboto removed. Cards, chips, buttons and the FAB use pills, and the bottom bar has a lavender active pill.
- Header: "CIRCLE • PREVIEW" plus the tab title and a viewer avatar. The FAB reads "Create Memory".
- Home: "All" + group chips with type dots.
- Memory card:
  - audience pill with lock and "Root › … › Group" path;
  - relative time;
  - ♥ count;
  - latest-comment preview;
  - Love · Comment · Save row.
- Added `othersLoved`/`loveCount` to the Memory model.
- Applied the five corrections to the Stitch screen (see design-system.md).

## Mobile: UI-2 membership workflows and cleanup
- Members tab:
  - Owner/Admin badges.
  - Approve or decline join requests.
  - Promote or demote with Undo.
  - Transfer ownership.
  - Remove with a cascade warning.
  - Owner and last-admin protections.
- Mock invite links: 7-day default, usage limit, reset and turn-off. Direct invitations need consent, with Accept/Decline. Invite-link landing shows clear states (expired, reset, needs parent, limit reached, already requested).
- Settings: approval, who can invite, listed/hidden subgroups.
- Pending-approval view, and a subgroups tab with listed discovery; hidden subgroups are never listed.
- Groups shown as a true tree with collapse/expand and a level/parent hint.
- Compose never silently picks an audience.
- Architecture:
  - Rules moved into pure `MembershipRules` with unit tests.
  - All repository calls are async with calm error handling.
  - Features no longer import `app/`, and the groups↔memories cycle is removed.
  - Events, chat and profile now have their own feature folders.
- Removed the retired first prototype: feed, CIRCLE-DEMO, single community, the standalone auth preview entry point, 41 legacy tests and 10 legacy goldens.
- Accessibility: contextual Love/Save labels, covers read once, a real TabBarView, autofill on access forms, RSVP can be cleared, nav bar height capped at large text.
- Removed members can rejoin only with a link created after their removal, matching the backend.

## Backend: draft hardened (ADR 0006)
- Fixed:
  - repeated PDO placeholders that broke group creation and member adds;
  - Memory creation always returning 403;
  - forgeable tokens with an empty or placeholder secret;
  - duplicate tokens;
  - suspended users keeping access;
  - orphaned subgroups on cascade;
  - join-request uniqueness;
  - raw error leakage;
  - removed or banned members rejoining via old links;
  - approval without a parent re-check.
- Security:
  - No account enumeration.
  - Passwords never trimmed; Argon2id with set cost.
  - Per-mobile login throttling.
  - CORS allowlist; opaque cursors.
  - Revocable sessions.
  - Invite-link list, revoke and reset; ban and unban.
- Added migration 005, 74 PHPUnit tests (circle_test database), PHPStan level 6 clean, and a draft `docs/api-contracts/openapi.yaml`.

# Phase 1

## Navigation and feed reliability increment

- Resume protected in-app post/group/album/member/event routes after mock invitation entry; reject external, unknown and looping return URLs.
- Clear return navigation when ending the demo, so the next entry opens a fresh feed.
- Build feed cards on demand with stable IDs; verify scrolling to the hundredth post and opening its detail.
- Expand regression coverage to 41 tests while retaining all 10 existing golden baselines.
- Align guidance and CI with direct, validated main-only commits and pushes; no feature branches or pull requests.

## Initial prototype

- Original light/dark semantic theme and reusable archive/card/notice layout.
- Explicit mock invitation guard and fictional, community-scoped repositories.
- Chronological feed, create post, comments, reaction/save toggles; all persist within the demo session.
- Groups, albums, searchable directory, profiles, reunion RSVP and appearance controls.
- Tests and Windows Flutter CI; no backend, real authentication or media delivery.
