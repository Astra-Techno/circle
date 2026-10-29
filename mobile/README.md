# CIRCLE mobile

Fictional, session-local Phase 1 prototype of a private app for any group — family, friends, school, college, office or club. See [developer setup](../docs/development.md), [architecture](../docs/architecture.md), and [design system](../docs/design-system.md).

Run `flutter pub get --enforce-lockfile`, then `flutter run -d <device-id>`. On the welcome screen choose **Explore fictional circles** for sample groups, or preview registration/log in with any well-formed fictional mobile number and password (input is validated, then discarded; the workspace starts empty). In preview builds no real account, backend or network call is used, and every change disappears when the preview ends or the app restarts.

## Server mode (real CIRCLE API)

The app is **dual-mode**. Without a define it is the fictional preview above. Built with `CIRCLE_API_BASE_URL`, the access screens register and log in for real against the PHP API (`backend/`, contract `docs/api-contracts/openapi.yaml` 0.3.1), and the header reads `CIRCLE • <host>` instead of `PREVIEW`. **Explore fictional circles** stays available as a separate, session-local tour that never calls the server.

```sh
flutter run --dart-define=CIRCLE_API_BASE_URL=http://10.0.2.2:8080/api/v1
```

- **Android emulator:** `10.0.2.2` is the host machine. **Physical device:** use the computer's LAN IP (e.g. `http://192.168.1.20:8080/api/v1`) and start PHP on `0.0.0.0` instead of `localhost`. **iOS simulator:** `http://localhost:8080/api/v1`.
- Plain HTTP works only in Android **debug** builds (`android/app/src/debug/AndroidManifest.xml` allows cleartext) and on the local network on iOS (`NSAllowsLocalNetworking`). **Production needs HTTPS.**
- Tokens live in `flutter_secure_storage` (Keychain / Android Keystore), bound to the server URL; passwords are sent exactly as typed and never stored or logged.

**Works against the server:** register (202, then automatic log-in) / log in / session restore / log out; groups and subgroups (list, create, settings, leave, transfer ownership); members (roles, remove); invite links (create, change = new link, reset, turn off, preview, join with a case-sensitive token); join requests (approve/decline); Memories (cursor pages loaded on scroll, pull to refresh, create with photos, edit text, delete with an 8-second Undo, comments with replies, the 8 reactions, save); private photos (picker → upload ticket → bytes → attach; shown through ~5-minute signed links).

**Not on the server yet** (one calm "Not on the server yet" card, no fake data): events (including the month calendar), polls, chat (including @mentions, forwarding and photos in chat), albums (including covers and captions), activity, notification and privacy settings, reports/moderation, direct invitations, asking to join from the subgroup list, deleting comments.

On a server, **@mentions in comments** still suggest only members of the Memory's exact group (once its member list has loaded), but the API has no mention field yet: the comment is sent as plain text (`"Thanks @Devika"`), nobody is notified and the name isn't emphasised. **Photo captions** in the Memory composer are preview-only (the API has no caption field), so the caption input is hidden on a server.

### Local API for development

```sh
cd backend
composer install
cp .env.example .env    # never commit .env; it is gitignored
# In .env: DB_DATABASE=circle_dev, DB credentials, and two different random
# secrets: php -r 'echo bin2hex(random_bytes(32)), PHP_EOL;'
#   JWT_SECRET=…  MEDIA_SIGNING_SECRET=…
php -r '$p=new PDO("mysql:host=127.0.0.1","root",""); $p->exec("CREATE DATABASE IF NOT EXISTS circle_dev CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");'
composer migrate
composer serve          # php -S localhost:8080 -t public (use 0.0.0.0:8080 for a phone)
```

Photo uploads need the PHP GD extension (`sudo apt install php8.3-gd`). Without it the server answers `503` and the app says "Photos can't be processed on this server yet." while the Memory can still be shared without photos. HEIC is refused by the server; the picker already returns downsized JPEGs (2048 px, quality 80).

### Smoke test against a real server

`test/smoke/api_smoke_test.dart` (tag `smoke`, skipped by default via `dart_test.yaml`) drives the app's own client and repositories over real HTTP: register, log in, create a group and subgroup, share/react/comment/save a Memory, invite link, photo upload, forced token refresh, log out.

```sh
flutter test test/smoke --run-skipped --tags smoke \
  --dart-define=CIRCLE_SMOKE_API=http://127.0.0.1:8080/api/v1
```

Use a development database only (`circle_dev`); the test creates fictional accounts.

## Layout

- `lib/app/` — router (`go_router`, five-tab `StatefulShellRoute`), shell and app widget.
- `lib/core/` — theme tokens, shared components, calm feedback helpers, `CircleFailure`, theme mode.
- `lib/features/workspace/` — repository contracts (all `Future`-based), the local mock repository with fictional seed data, Riverpod providers (current viewer, session, workspace controller) and the shared async view.
- `lib/features/groups/` — group models, pure membership rules (`domain/membership_rules.dart`), tree ordering, and the groups, detail, members, invite, settings and invite-link screens.
- `lib/features/chat/` — chat models and pure rules (`domain/chat_rules.dart`), the `Future`-based `ChatRepository`, the local `MockChatRepository` (group membership always read from the workspace repository), Riverpod providers and the inbox, new chat, conversation, details, privacy and "Reply privately" screens.
- `lib/features/albums/` — album model and pure `AlbumRules`, the `Future`-based `AlbumRepository` and its local mock (membership read from the workspace repository), providers, the Albums tab, album detail, album photo viewer and the event "Photos from …" section.
- `lib/features/moderation/` — report targets, reasons, queue/audit models and pure `ModerationRules`, the `ModerationRepository` contract (implemented by the workspace mock), the shared report sheet and the "Hidden by admins" notice.
- `lib/features/notifications/` — activity items, `NotificationSettings`, pure `NotificationRules` (delivery, quiet hours, group levels, badge) and `ActivityInboxRules` (item generation, tap-through), the local mock repository, the bell, Activity and Notifications screens.
- `lib/features/search/` — pure `SearchRules` over a `SearchCorpus` built from the workspace and readable chat messages, and the search screen.
- `lib/features/memories/`, `events/`, `profile/`, `auth/` — the remaining screens (profile also holds member profiles and Account). Dependencies point one way: groups → albums/memories/events → workspace → core; moderation, albums, notifications and search depend on workspace (and chat) but never on `app/`; events reuse the Memories poll rules and poll card for date polls; chat reuses the Memories poll editor/card, reactions and the event card.
- `lib/core/two_pane.dart` — `CircleAdaptivePane` and `CirclePaneScope`, the tablet list + detail layout used by the Chats, Groups and Events branch roots.

## Mock membership flows (UI-2)

Roles (owner/admin/member), approvals, invite links (7-day default expiry, optional usage limit, reset/turn off), direct additions that need the invitee's consent, listed/hidden subgroups, cascade leave/removal and owner/last-admin protections are enforced by `MembershipRules` and the mock repository. Invite links look like `circle://invite/<code>`; they are labelled "Preview link — not shareable" and work only inside the running preview (use **Open an invite link** on the Groups tab).

## Mock Memories (UI-3)

Memories can mix text, fictional illustrated "photos" (10 local scenes, no uploads or remote images), and a poll; at least one is required. Optional "taken in" year (1950–this year) and place (≤ 80 characters) sit under **More options**. Cards show a photo grid (full-screen viewer at `/home/memory/<id>/photos?index=n`), poll results per the poll's visibility setting, a reaction summary, and the latest comment. Reactions use the 8-emoji allowlist (one per person; tap Love, long-press or the reaction button for the picker). Comments allow one level of replies; authors can delete their own comments and edit or delete their own Memories, with Undo. The rules live in pure Dart under `lib/features/memories/domain/` (`MemoryRules`, `PollRules`, `ReactionRules`, `CommentRules`); the mock repository re-checks exact-group membership on every change. Everything is session-local and cleared when the preview ends.

## Mock Events (UI-4)

Events belong to one exact group and are typed (Family function, Wedding, Reunion, Meetup, Birthday, Trip, Online, Other — labels and icons only). Times are stored in UTC with the zone they were planned in (the device's zone at creation, shown as e.g. "IST"), so they read the same on any device. Creating needs only the group, a title, a date with a start time and a place; **online events need a link instead of a place** (a place stays optional for them, and other types may add an optional link for hybrid plans). End time, description, RSVP deadline (on or before the start), capacity, co-hosts (members of the group) and a **date poll** (2–6 date/time options, "Which date works for you?", named votes, results always visible, multiple choice by default; built with the UI-3 `PollRules` and shown with the same poll card) sit under **More options**. With a date poll the date may wait: the earliest option is used until a host edits the event. The date poll can't be changed after creating.

RSVP is Going / Maybe / Not going, people coming with you (0–20, Going and Maybe only) and an optional note (≤ 140). Every change saves at once with Undo. Capacity counts everyone going plus their guests; Maybe never uses a place. Answers close when the event is cancelled, has started or ended, or its RSVP deadline has passed. Hosts and the group's owner/admins can edit (marked "Edited") or cancel (with confirmation; the real app would notify people who answered — the preview notifies nobody). Who can create events is a group setting (**Everyone** by default, or **Admins only**) enforced by `MembershipRules.canCreateEvent`. Opening maps and adding to a calendar need a real device, so the place and link can only be copied.

**Month calendar (E1):** Upcoming has a **List | Month** toggle. The month grid starts on Monday (simple English labels), rings today, dots days with events (the spoken label carries the count: "Sunday 25 October, 2 events"), and lists the tapped day's events underneath. Previous/next month buttons; Previous stops at the current month (earlier events are under Past). Each day is a ≥ 48 px target; at large text on narrow phones the grid scrolls sideways rather than shrinking targets. The group chips filter it too. An event sits on the date it starts in the zone it was planned in (multi-day events show on their first day). Pure helpers: `EventCalendar` (`events/domain/event_calendar.dart`), all date-only UTC values, so daylight-saving changes never skip or repeat a day.

Routes: `/events` (Upcoming/Past, month headers, group chips), `/events/new?group=<id>`, `/events/e/<id>`, `/events/e/<id>/attendees`, `/events/e/<id>/edit`. The rules live in pure Dart under `lib/features/events/domain/` (`EventRules`, event time helpers); the mock repository re-checks exact-group membership on every change and drops RSVPs and co-hosts of people who leave the group.

## Mock chat (UI-5)

**Local mock, not real-time.** Every chat screen says once: "Preview: messages stay on this device. Nobody receives them." Nothing is sent or received, nothing arrives on a timer, and there are no typing indicators; the only messages from other people are fictional, pre-seeded ones.

- **Conversations.** Every group and subgroup you're in has a group chat whose members are exactly the group's (`/chats/g/<groupId>` from the group space's Chat tab opens it). 1:1 chats are possible only with people who share a group with you, subject to their **who can message me** setting (*Everyone in my groups* by default, *Only people I've chatted with*, *Nobody*) and blocks in either direction. Northbank 2009 is seeded as a large group (57 fictional people) so the request flow can be seen.
- **Message requests.** A first 1:1 message from someone you've never chatted with goes to **Requests** unless you share a *close* group (≤ 50 members by default; mark any group close or not in **You › Privacy**). Requests show Accept / Delete (with Undo) / Block (confirmed); there is no composer until you accept, and the sender sees "Sent", never "Seen", until then. Blocking hides their requests and stops their messages; in group chats their messages are hidden for you.
- **Inbox** (`/chats`): Chats / Requests (with count) tabs, search by name, unread in bold with a dot, "Seen" / "Seen by Mira, Dev +3" / "Sent 2h" lines, pinned first, mute (8 hours, 1 week, until turned back on; groups above 50 members start muted), archive by swipe or menu with Undo, and an Archived list (`/chats/archived`). Every row action is in a visible ⋮ menu and the long-press sheet. A 1:1 row shows a small indigo dot on the avatar only when the person is **active now** (read as "Mira, active now"), and nothing else about activity.
- **Conversation** (`/chats/c/<id>`): grouped bubbles (outgoing indigo, incoming recessed), time separators, avatars beside incoming runs. Double-tap a bubble for ❤️; tap shows Love / Reply / More buttons and the time; long-press opens the 8-emoji reactions, Reply, Copy, Edit (your own, within 15 minutes, marked "Edited"), Unsend (any time, with Undo; others see "Message unsent") and Report (the shared report flow, see UI-6). Swipe right to reply; quotes show in the composer and the bubble. The composer shares a Memory or event as a card, or sends a poll (the Memories poll editor: question + 2–12 options). **The share picker lists only items everyone currently in the chat can see** (every participant is an active member of the item's exact group), with a calm empty state otherwise; the repository refuses anything else. **Shared cards still re-check access for each reader**; someone who can't see the item gets "This Memory isn't shared with you". Leaving a group keeps its chat read-only up to when you left.
- **Details** (`/chats/c/<id>/details`): shared Memories and events, members and a link to the group space, mute, pin, block/unblock and report (1:1; group messages are reported one by one). **Privacy** (`/you/privacy`): who can message me, **Show activity status** (on by default), close groups, blocked people with Unblock (Undo).
- **Activity status** (Instagram-style, 1:1 only): "Active now" (≤ 5 min), "Active 12m ago", "Active 2h ago", "Active yesterday"; older than 48 hours or unknown shows nothing. Shown in the 1:1 header (in place of the shared-groups line), as the inbox dot (active now only) and under names in New chat; never in group chats. Visible only when both people have *Show activity status* on (reciprocal), share at least one group, and neither has blocked the other. Seeded values are fictional and static (Mira 2 min ago, Priya 35 min, Dev 2 h, Lena yesterday, others unknown); you count as active while using the preview. Labels are computed from the app clock when a screen builds; nothing updates on a timer.
- **Reply privately** on someone else's Memory opens the 1:1 chat with them with the Memory attached, or explains calmly why not.

- **@mentions** (group chats and Memory comments): typing "@" and a letter suggests members of *that exact group* only (never you, never people you blocked in chat; up to 5). Picking writes "@Name" and records the person with the message or comment; only current members whose name is still in the text are kept (an edit that removes the name drops the mention). Mentions show bold in the primary colour (bold and underlined on your own indigo bubbles). A mention of you becomes an **Activity** item ("Sam mentioned you in Northbank 2009: …") that counts for the badge as a personal push, following the "Mentions and replies" push switch, quiet hours and chat mutes; big groups' "mentions only" level now lets these real mentions through. Self-mentions and mentions from people who blocked you notify nobody. 1:1 chats have no mentions. Rules: `MentionRules` (`memories/domain/mention_rules.dart`).
- **Forward** (long-press menu and the tap action row): text and shared Memory/event cards only (not polls, photos or unsent messages), to 1–5 chats chosen from a searchable list of chats you can post in (never a group you left, a waiting request or a blocked 1:1). A shared card goes only where everyone can already see the item (the UI-5 share rule); other chosen chats are skipped with one calm note ("Not sent to Studio North: not everyone there can see this Memory."). Copies carry a small "Forwarded" label and never their mentions. Rules: `ForwardRules`.
- **Photos**: the composer's ⊕ menu has **Photos** (the Memories scene picker, up to 10 fictional illustrations), sent as a photo-grid message. Tap a photo for the full-screen viewer (`/chats/c/<id>/photos/<messageId>?index=n`); double-tap for ❤️, swipe or long-press to reply; unsend removes them for everyone.

Sends are idempotent by client message id (a retry never duplicates). The rules live in pure Dart in `ChatRules` (including share eligibility, `ChatRules.everyoneCanSee`) and `ActivityRules`; `MockChatRepository` re-checks membership on every read and change. Ending the preview clears every conversation and setting.

## Albums, activity, search, settings, reports and tablets (UI-6)

All fictional and session-local; ending the preview clears every album, report, read mark and setting. Each new screen carries one preview label. Lists load with static **skeletons** (`CircleSkeleton` in `core/circle_components.dart`; spoken once as "Loading …", nothing animates), never spinners; only "load older Memories", upload progress and photo tiles keep small inline indicators.

- **Albums** (group space › Albums, `/groups/g/<id>/albums/<albumId>`, viewer at `…/photos?index=n`): an album has a name (1–80), an optional year or era (≤ 20, e.g. "2005–2009"), fictional scene photos (the Memories scene picker, up to 10 per pick and 50 per album) and its creator. Any member of the exact group adds photos; people remove photos they added (admins any) with Undo; the creator or the group's admins rename or delete (delete is confirmed). The creator or admins choose the **cover** ("Set as cover", with Undo) from a photo's visible ⋮ button, its long-press menu or the viewer; the Albums grid shows it (the first photo until one is chosen). The person who added a photo, or an admin, writes its **caption** (≤ 140 characters, empty removes it). Memories can carry optional per-photo captions too (composer › Captions, preview only). Past, not-cancelled events show **Photos from <event>** on their page; the album is created in the event's group on the first add. Rules: `AlbumRules`.
- **Activity** (the bell in every tab's header, `/activity`): Today / Earlier items generated from what you can already see (invitations, join requests for admins, comments and replies to you, batched reactions to your Memories, new Memories and events, polls closing and results, changes to events you host or answered Going/Maybe, message requests and unread 1:1 chats) @mentions of you (Sam's message in Northbank 2009 and Tomas's comment are seeded with real mention data) plus three fixed fictional items (a co-host's change, a role change, an approval). Tapping marks an item read and opens it if you still have exact-group access, else says "That's no longer available to you." **Mark all read**. The indigo badge counts only unread items whose delivery would be a push (see Notifications); nothing arrives on a timer.
- **Notifications** (`/you/notifications`, "Preview: no notifications are sent; these settings show what would happen."): push for personal types is on by default (DMs and requests, mentions and replies, your events, invitations and approvals, join requests for admins); new Memories, reactions, new events and polls, poll results and role changes go to Activity and the daily digest unless promoted to push. Quiet hours (on, 10 PM–7 AM, editable; pushes are held, the in-app badge still counts), daily digest on/off and time, per-group level (Everything / Mentions and replies only / Nothing; groups over 50 members default to mentions only) and muted chats with Unmute. Rules: `NotificationRules` (`deliver`, `inQuietHours`, `levelFor`, `countsForBadge`).
- **Search** (header search button, `/search`): one field, at least 2 characters, case-insensitive; results grouped as Groups / People / Memories / Events / Messages. Only your exact groups (plus listed subgroups of them; hidden subgroups only if you're in them), never people you blocked, and only messages from chats you can read — a group you left stays searchable up to when you left. Recent searches are kept for the session. Rules: `SearchRules`.
- **Reports and moderation**: one report sheet (reason — Spam, Harassment or bullying, Hate, Nudity or sexual content, Violence, Private information, Something else — plus an optional note ≤ 500) from a Memory's ⋮ menu, comments, chat messages (long-press), an event's ⋮ menu, a member's profile or manage sheet, and listed subgroups in a parent's Subgroups tab. You can't report your own posts or report the same thing twice; reporters are never shown. Admins of the exact group see **N reports** in the group header and **Reports and admin actions** in settings (`/groups/g/<id>/reports`): reasons and counts, **Hide** (with Undo) / **Unhide**, **Remove member** (the usual cascade warning), **Dismiss** (with Undo), and an audit trail ("Mira hid a Memory · 2h ago"). Hidden content is gone for members and marked "Hidden by admins" with Unhide for admins. A parent group's admins remove a reported subgroup (confirmed) seeing only its name, size and reasons. 1:1 reports go to the platform, not to any group. Rules: `ModerationRules`; seeded: two reports on a message in Northbank 2009 and three on its listed subgroup "Late-night memes".
- **Profiles and You**: tapping a member opens `/people/<id>` (only people who share a group with you): name, groups in common, **Message** (disabled with the reason when they can't be messaged), Block/Unblock and Report. You lists Activity, Notifications, Privacy and Account (`/you/account`: appearance, "Comes before launch" text for password, language, export and deletion, and **End preview**), plus saved Memories.
- **Tablets** (width ≥ 840): Chats, Groups and Events show the list on the left and the chosen item on the right; choosing an item selects it instead of opening a page, and deep links (`/chats/c/<id>`, `/groups/g/<id>`, `/events/e/<id>`) open with both panes. Phones are unchanged.

## Validation

`dart format --output=none --set-exit-if-changed .`, `flutter analyze`, and `flutter test`. Golden baselines in `test/goldens` are rendered on Windows; pixel differences are expected on other platforms. Native integration testing (`integration_test/`) requires an Android or iOS device or emulator.

### iPhone builds without a Mac

Use the manual [iOS build and TestFlight workflow](https://github.com/Astra-Techno/circle/actions/workflows/ios.yml). `validate` builds an unsigned compilation artifact; `testflight` signs and uploads after Apple secrets are configured. See [the setup and installation guide](../docs/ios-testflight.md). iOS push and Android-specific contact tools remain gated; a compiled app is not proof of native-device acceptance.
