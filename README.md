# CIRCLE — Private Groups, Shared Memories

> **Current branch policy (owner instruction):** Use `main` only for all work and pushes. Do not create feature/topic branches. This supersedes older branching/PR workflow recommendations below and in the startup prompt. Preserve user changes and never force-push.

> **Required reading for Codex, Claude Code and other coding agents:** follow [§0: shared implementation and release rules](#0-shared-implementation-and-release-rules) and [AGENTS.md](AGENTS.md) before making changes. [CLAUDE.md](CLAUDE.md) loads compact shared instructions for Claude Code; detailed rules are read as needed. Current owner instructions take precedence; older status snapshots and examples do not override the current rules.
>
> **Status distinction:** account/group/Memory APIs and private Memory media have been implemented and live-tested. The broader chat/events/albums UI includes local previews. Firebase source files and enabled feature flags alone do not establish working push delivery or server feature support. See §12 and the release/validation records for evidence.
>
> **Product scope:** CIRCLE is for **any close-knit private group**: families, offices, schools, colleges, friend circles and clubs. Anyone can create a group, nest subgroups inside it, and share memories, chat, plan events and run polls with only the people who belong there.

## 0. Shared implementation and release rules

These rules apply equally to Claude Code, local Codex and Codex Web. They take precedence over conflicting older workflow examples or status descriptions elsewhere in this repository. Keep the product and privacy rules in §2–4 and the current ADRs. Existing code that violates a rule is a defect to fix, not permission to repeat it.

### 0.0 Efficient context and execution

ChatGPT/Codex and Claude follow the efficient workflow in `AGENTS.md`. Start with the compact `PROJECT_STATE.md`, inspect recent diffs and read relevant sections rather than repeatedly loading the whole repository. Use one agent by default, scoped checks while editing and required broader validation at integration/release. Batch APK builds after completed work unless the owner requests otherwise. Keep reports brief and update the handoff with verified results. Token savings never justify weaker privacy, incomplete implementations or false test/release claims.

### 0.1 Safe collaboration and Git

- Inspect `git status`, the current branch and recent commits, then pull `origin/main` safely before starting. Work and push on `main` only; never create feature branches or pull requests, force-push, discard unrelated edits or automatically stash someone else's work.
- If a pull would overwrite unfinished work, preserve it. Review the incoming changes in an isolated checkout, or finish and verify the existing work before integration. Report which checkout/commit was updated; a successful fetch is not a completed pull of the primary checkout.
- Coordinate ownership of shared files, migrations and lockfiles before parallel Web/local changes. Reconcile both implementations when merging; preserve session/account guards, authorization checks and working error handling.
- Commit only the intended, verified changes. Fetch and reconcile safely before pushing. Publish shared documentation changes so the other machine can read them; uncommitted files are not synchronized through GitHub.

### 0.2 Real server support versus preview

- Enable a server capability only after its reviewed API contract, backend persistence/authorization, client repository and relevant tests are implemented. Do not enable a whole feature set merely because screens exist.
- A mock repository, empty local fallback or `notOnServerYet` implementation does not count as server support. Keep those capabilities gated and explain their availability accurately.
- Never pass real accounts or private group data into preview repositories. Preview data must remain clearly labelled, fictional and isolated from authenticated server state.
- Chat, events, polls, albums, privacy controls, moderation and notification preferences each need actual service behavior. A visible setting must not imply enforcement that the backend does not provide.
- Update `docs/api-contracts/openapi.yaml` and get frontend/backend track review for API changes, including device-token and notification endpoints. Use distinct migration filenames and sequence numbers; never edit an already-applied migration to change deployed behavior.

### 0.3 Firebase and push notifications

- Treat Firebase as optional infrastructure: missing configuration, denied permission, SDK/plugin errors or token-registration failure must not prevent app startup, login, session restoration or logout. Auth revocation, local token cleanup and private-image cleanup must run independently of push deregistration success.
- Ask for notification permission in context after an explained user action, following §4.0. Do not prompt on every login or restored session.
- Scope initialization, registration, pending callbacks and listeners to the account, API server and session. Make initialization idempotent; cancel listeners on logout/account changes and dispose. Reject stale completions and prevent an old session from reassigning a device to the wrong account.
- Validate device-token types/lengths and platform values before SQL. Document the endpoints and test authenticated registration, reassignment, deregistration, validation, logout and account switching.
- Wiring is required: business events must call the delivery path, foreground behavior must be implemented, and notification taps must navigate to an allowed internal destination with normal access checks. Android foreground notifications are not automatically displayed merely because the device runs Android 13+.
- Implement and honor persistent notification preferences, membership/access checks and quiet hours before claiming those controls govern real push. Follow the calm rules; never invent delivery or claim a successful device test from source inspection or mocks.
- Use existing logging APIs and redacted error handling. Never log private notification titles/bodies, credentials, bearer tokens or device tokens. Only remove invalid FCM tokens for a confirmed provider error such as `UNREGISTERED`, not every HTTP 404.
- Keep server service-account keys private and outside the web root/source control. Android client configuration does not configure the server sender or iOS. Supply the correct platform configuration, or keep push unavailable on that platform without breaking the app.

### 0.4 Android signing and release identity

- Keep the same application id and established signing key for updates to the existing beta. Compare the candidate certificate against the last validated immutable release, not a recently overwritten `circle.apk`.
- Established beta signing certificate SHA-256: `6c78be13d88b19587e4c37edb9012e3f2eb37fee34f6850084dd069d78f9b66c`. A candidate signed by another key cannot update those installations. Never silently generate a replacement debug keystore and call it update-compatible. If the key is unavailable, report the signing blocker. Never commit a keystore, its password or private signing configuration.
- Increment `versionCode` for every changed application release, including a rebuild that changes runtime behavior. Keep `versionName`/build values consistent with the APK and metadata. Never replace an already published immutable versioned APK with different bytes.
- Build production APKs with the intended HTTPS API and `CIRCLE_PREVIEW=false`; label any preview APK explicitly. Verify package id, version, minimum SDK and certificate from the built artifact. Keep release builds separate from concurrent Flutter test tooling that can regenerate Android plugin registration files.

### 0.5 Download publication and deployment

- A release consists of one verified APK copied to `downloads/circle.apk` and a new immutable `downloads/circle-<version>-<build>.apk`, plus matching `downloads/release.json`, `downloads/index.html` and `website/index.html` links. Preserve earlier immutable releases.
- Generate byte size and SHA-256 from the final APK. Both APK paths and metadata must agree. Do not update only the stable filename, reuse an old build number or leave the site button pointing at an earlier artifact.
- Stable APK/metadata/download pages should use non-stale caching; immutable versioned APKs may use long-lived immutable caching. Verify hosted metadata, the download button and the full hosted artifact's checksum after deployment.
- A commit or successful push is not proof that hosting updated. Record deployment separately. The deployed `deploy.php` does not update itself; changes to that script require replacing its hosted copy. Preserve `.env`, private storage and hosting PHP handler settings.
- Check the current web runtime when diagnosing PHP extensions; CLI settings and an old captured error do not prove the hosting runtime is still broken. Never claim that a deployment script automatically switches the hosting PHP version.

### 0.6 Verification and accurate reporting

- For runtime changes, run Dart format, Flutter analysis and relevant unit/widget/integration regressions. For backend changes, run `composer test` against the dedicated `circle_test` database only and run `composer analyse`. Add coverage for new endpoints and error paths; an unchanged passing suite does not establish coverage of a new feature.
- Functional or static-analysis failures must be addressed before claiming a runtime change is verified or ready to publish. Report exact results and remaining failures; never describe a clean analyzer as proof that authentication, delivery or persistence works.
- Render meaningful UI states in light/dark mode, narrow/tablet widths and at 200% text. Keep Windows golden comparisons and human approval separate; do not regenerate approved Windows baselines on Linux to hide differences.
- Use fictional test data only. Never claim physical Android/iOS installation, push delivery, tenant security or approved visual equivalence from widget tests, screenshots or a successful build.
- Documentation-only changes need a focused diff, reference and whitespace review; do not claim that runtime test failures were fixed by a documentation update.

## 1. Product vision

CIRCLE gives real-life groups a private home: no public profiles, no strangers and no engagement-maximizing algorithm. A family, a college batch, an office team or a cycling club can each create a group, invite their people, organize themselves into smaller subgroups, and then:

- preserve and revisit **Memories** (posts, photos, albums),
- talk in **group chats and 1:1 chats** (an Instagram Direct–style messaging experience),
- organize **events**: family functions, weddings, reunions, meetups, anything,
- decide things together with **polls**.

**Core principles**
- **Private by default:** groups, members, memories, chats and events are never public or publicly searchable.
- **Invitation and approval:** people join a group only by an invite link or a direct add, subject to each group's approval setting. Registering an account never grants membership of any group (ADR 0005).
- **Hard separation:** what happens in one group or subgroup is visible only to its members. Your family never sees your office group, and a subgroup's content is hidden from its parent group.
- **Own your memories:** respectful media controls, consent-based tagging, export and delete paths, and clear audience labels on everything you share.
- **Mobile first:** Flutter on Android and iOS; native Android development and testing first.
- **Effortless and never annoying (top UX priority):** anyone from a teenager to a grandparent should use CIRCLE without help, and the app must never nag, spam or trick people. Messaging feels as easy as Instagram Direct. Memories are chronological, with no ranking algorithm, ads or engagement tricks. Concrete rules are in §4.0.
- **Vocabulary:** the stream of shared posts is called **Memories**, never "feed".

## 2. Core concepts and rules

### 2.1 Accounts (ADR 0005)

- **Anyone can register** with a **mobile number (with country code) and a password**. There is no email login. **OTP verification comes later.**
- Registration creates an account only. After registering, a person can create a group, join through a link, or accept a direct invitation.
- Until OTP exists, owning the mobile number is not verified. Responses must never reveal whether a number is registered.

### 2.2 Groups and group types

- **Any signed-in user can create a group.** A top-level group is the root of a private space (e.g. "Sharma Family", "AKCE 2009", "Acme Design Team", "Sunday Cyclists").
- A group has a **type**: `family`, `friends`, `school`, `college`, `office`, `club` or `other`. The type only sets defaults (icon, suggested profile fields, labels such as "Function" vs "Meetup"). It never changes permissions.
- Root groups are **never discoverable**. You can only reach them through an invite link or a direct add.

### 2.3 Nested subgroups (up to 10 levels)

- **Any member of a group can create a subgroup inside it.** Subgroups can contain subgroups, up to a **maximum depth of 10 levels** (root = level 1).
- Example of a real structure:

```text
AKCE 2009                                   level 1 — college batch
├─ ECE · EEE · IT · Mech · ICE · Biotech     level 2 — departments
└─ CSE
    ├─ Sec B                                 level 3 — sections
    └─ Sec A
        ├─ Boys gang                         level 4 — friend circles
        └─ Girls gang
```

- **A subgroup works exactly like a main group.** It has its own creator/owner, admins, members, invite link, approval setting, Memories, chat, events, polls and albums.

### 2.4 Roles

| Role | Who | Can |
|---|---|---|
| **Owner** | The group's creator (exactly one per group) | Everything an admin can. Cannot be removed or demoted by other admins. Can transfer ownership. |
| **Admin** | The owner, plus anyone an admin promotes | Change settings, manage invite links, add/approve/remove members, promote/demote admins, moderate content. |
| **Member** | Everyone else who has joined | Post Memories, chat, create events and polls, create subgroups, invite (if the group allows it). |

- The **last admin cannot leave** until they promote someone else or transfer ownership.
- Roles are **per group**. Being an admin of "AKCE 2009" gives no rights in "CSE" or any other subgroup.

### 2.5 Joining a group

```text
Admin adds a person directly ─▶ person receives an invitation ─▶ accepts ─▶ Member
Admin/member shares invite link ─▶ person opens it
        ├─ approval OFF ─▶ joins immediately ─────────────────────▶ Member
        └─ approval ON  ─▶ join request ─▶ admin approves ────────▶ Member
                                          └▶ admin declines ─────▶ no access
```

- **Approval setting** (per group): `Approval required` or `Anyone with the link joins directly`.
- **Direct add always requires the person's consent:** they get an invitation they can accept or decline. Nobody is silently added to a family or office group.
- **Invite links:** a default 7-day expiry (configurable, including no expiry), an optional usage limit, and an admin can **reset** the link at any time (the old link stops working immediately). Tokens are stored hashed.
- **Who can share the link:** admins only by default. Each group can allow all members to share it.
- **While pending,** a person sees only the group's name, type, cover and a "Waiting for approval" status. No members, Memories, chat or events.

### 2.6 Subgroup rules

- **You must already be a member of the direct parent** to join a subgroup. This is checked when you join *and again when an admin approves*. A subgroup invite link does nothing for someone outside the parent, so it can never become a back door.
- **Listed or hidden** (each subgroup's choice): *listed* subgroups appear to the parent's members, who can request to join (or join directly if approval is off). *Hidden* subgroups can only be reached by invitation.
- **Privacy between levels:** parent-group admins **cannot read** a subgroup's Memories, chat, events or polls. If a subgroup is reported, the parent's admins can only remove it, without reading its content.
- **Cascade removal:** leaving or being removed from a group also removes you from **all of its descendant subgroups**, and their events. Their **group chats freeze for you**: earlier messages stay readable (nothing is deleted), but you can't send and you receive nothing new (ADR 0003). Before that happens, any descendant you **own**, or where you are the **last admin**, must be handed over first, so no subgroup is ever left without an owner or admin.
- Direct add into a subgroup is limited to the parent's members.

## 3. Feature scope

### 3.1 Memories (shared posts)

- Text plus photos (multiple per memory). Video comes later.
- Each memory belongs to exactly one group or subgroup and shows its **audience label** (e.g. "Shared with CSE · Sec A").
- **No silent default audience:** the composer starts with the group you are in. If you start from Home with no group filter, you must choose a group explicitly.
- Chronological order, newest first. Comments with replies, emoji reactions, save/bookmark.
- An optional **"memory year/date"** for old photos (e.g. "Taken in 2007") and an optional place.
- **Member tagging requires consent.** A tagged person can remove the tag. No face recognition.
- Home shows Memories from all your groups with group filter chips. Each group also has its own Memories tab.
- Author can edit/delete. Admins can hide/remove when content is reported.

### 3.2 Chat (group and 1:1)

Chat follows the **Instagram Direct** model: casual and visual, closely connected to shared content, with message requests protecting privacy. It works inside CIRCLE's privacy model.

**Conversations**
- **Group chat:** every group and subgroup has one automatically, named and pictured after the group. Its membership always matches the group's. After you leave or are removed, the chat stays in your inbox **read-only, frozen at that moment**: old messages are kept, nothing new arrives and you can't send.
- **1:1 chat (direct messages):** you can message anyone who **shares at least one group** with you. There is no global user search and no contact upload.
- **Message requests (Instagram-style):** a first message from someone you've never chatted with goes to **Requests**, unless they're in your "close" groups. You can **Accept**, **Delete** or **Block**. They don't see "Seen" until you accept.
  - "Close" groups: groups with ≤ 50 members by default, and you can mark any group as close.
- **"Who can message me"** privacy setting: *Everyone in my groups* (default, with requests as above) · *Only people I've chatted with* · *Nobody*. Blocking stops their messages everywhere and hides your activity status from them.

**Messaging features (v1 of chat, milestone M6)**
- **Inbox:** tabs for **Chats** and **Requests**, active-now dots on avatars, bold and a dot for unread, "Seen" / "Sent 2h" status lines, search, pin, mute, swipe to archive.
- **Messages:** text, emoji, photos (multiple, with captions), links with server-generated previews.
- **Reactions:** **double-tap a message for ❤️**, or long-press for quick emoji reactions. Long-press also opens Reply, Forward, Copy, Edit, Unsend, Pin and Report.
- **Swipe to reply** with a quoted preview. @mentions in group chats.
- **Edit within 15 minutes**, with an "Edited" label. **Unsend** removes the message for everyone.
- **Status:** "Sent" → "Seen". Group chats show "Seen by Mira, Dev +3". Typing indicator.
- **Activity status** ("Active now" / "Active 2h ago"), Instagram-style:
  - shown only in 1:1 contexts, only between people who share a group and haven't blocked each other, never while a message request is unaccepted (either way), and never older than 48 h;
  - "Show activity status" is on by default and can be turned off; it's reciprocal, so turning yours off also hides others' from you.
  - Read receipts can be turned off separately.
- **Share CIRCLE content into chat (the Instagram feel):** share a Memory, event, poll or album as a tappable card. The picker only offers items that everyone in the chat can see; cards still re-check access when opened. **Reply privately to a Memory**: the conversation opens with that Memory quoted.
- **Polls** in group and 1:1 chats (see §3.4).
- **Chat details:** shared photos, shared Memories/events, members (group), mute, block/report (1:1), jump to the group space.
- **Offline:** messages queue locally and send when back online, with no duplicate sends (client message IDs make sends idempotent).

**Later (after launch):** voice messages, video messages, GIFs and stickers (third-party providers need a privacy review), **vanish mode** (disappearing messages), chat themes and nicknames, **Notes** (a short status shown above the inbox to people in your groups).
**Needs an owner decision before planning:** voice/video calls; ad-hoc group DMs not tied to a CIRCLE group (today, subgroups cover this); stories; end-to-end encryption (v1 encrypts in transit and stores messages privately on the server. E2E for 1:1 chats should be evaluated before public launch).

### 3.3 Events

- **Any member can create an event, but only inside their own group/subgroup.** Only that group's members can see it and RSVP. (A group's admins can restrict event creation to admins.)
- Types: *Family function*, *Wedding*, *Reunion*, *Meetup*, *Birthday*, *Trip*, *Online*, *Other*. These are labels and icons only.
- Details: title, type, cover photo, start/end date and time with **time zone**, venue (text + "open in maps" link) or online link, description, optional co-hosts, optional RSVP deadline and capacity.
- **RSVP:** Going · Maybe · Not going, plus **number of guests** (e.g. "+3 family members"), and an optional note ("Will arrive after lunch").
- Attendee list with counts (Going 42 · Maybe 8 · total guests 97), visible to the group's members.
- Reminders (1 day and 1 hour before, configurable), "Add to my calendar" (.ics), updates/cancellation notify RSVPs.
- Each event has its own discussion thread, and **event photos flow into the group's Albums** afterwards ("Memories from this event").
- Polls can be attached (e.g. "Which date works?", "Veg or non-veg?").
- No payments or contributions in the MVP.

### 3.4 Polls

- Can be created in: a group's **Memories**, **group chat**, **1:1 chat**, and **events**.
- Question plus 2–12 options. Single or multiple choice.
- Settings: anonymous or named votes, end time (optional), whether members can add options, results visibility (*always* / *after voting* / *after closing*), whether votes can be changed.
- Creator (and group admins) can close early. Results show counts, percentages and (if named) who voted.
- Special type for events: **date poll**, where options are date/time slots.

### 3.5 Albums

- Per-group photo albums, an optional "year/era" (e.g. "2005–2009"), cover photo, captions.
- Event albums are created automatically.
- Upload progress, retry, private storage, full-screen viewer, consent-based tagging.

### 3.6 Members and profiles

- **Global profile:** name, photo, short "about". Private by default.
- **Per-group profile fields** suggested by group type, e.g. *college:* nickname, department, batch, section, city. *family:* relationship ("Uncle, Chennai branch"). *office:* team, role. *club:* member since. Members choose what each group sees.
- Member directory per group with search and role badges. You only ever see members of groups you belong to. Admins never see other members' mobile numbers.

### 3.7 Notifications

- **Push (FCM, M5), personal by default:** direct messages, @mentions and replies to you, event changes/reminders for events you RSVP'd to, invitations/approvals for you, join requests (admins only).
- **In-app activity inbox or daily digest, not push:** new Memories, reactions (batched), new events and polls in your groups, poll results, role changes.
- Group chats with more than 50 members default to mentions only. Quiet hours 10 PM–7 AM are on by default. One-tap mute for 8 hours / 1 week / always. Users can turn more push types on. See the calm rules in §4.0.

### 3.8 Moderation and safety

- Report a memory, comment, message, event, poll, member or subgroup.
- Admin queue per group: hide/remove content, remove member, decline/ban from re-joining via link.
- Block user (global). Audit trail of admin actions.
- Account deletion and data export.

### 3.9 Out of scope for MVP

AI photo recognition, face tagging, public discovery/search, ads, payments/contributions, live streaming, reels, plus the "needs owner decision" items in §3.2.

## 4. UI plan

### 4.0 Ease-of-use and calm rules (apply to every screen)

These rules override feature wishes. If a feature can't follow them, simplify the feature.

**Easy: few taps, no learning curve**

| Task | Target |
|---|---|
| Open an invite link → inside the group (new user, mobile + password) | ≤ 30 seconds, ≤ 4 screens |
| Share a memory with a photo | ≤ 3 taps after opening the app |
| Create an event | Only title, date and place required; ≤ 60 seconds |
| Create a poll | Question + 2 options, then post; settings are optional |
| Reply to a message / react | 1 gesture (swipe / double-tap) |
| Find any group, even 10 levels deep | ≤ 2 taps from Groups or search |

- **One clear primary action per screen.** Advanced options sit behind "More options" with good defaults already chosen (approval, link expiry, poll settings, event reminders).
- **Smart defaults over questions, but never a silent wrong default:** the audience defaults to the group you're in, the event time zone to the device's, the group type icon to the type. If there's no safe default (e.g. posting from Home with no group selected), ask once.
- **Nesting stays invisible until needed.** Most people use 1–3 levels. Show the breadcrumb and Subgroups tab, never the tree complexity, on first use.
- **Plain, friendly words:** "Memories", "Ask to join", "Who's coming?". Avoid jargon like "tenant", "approval mode" or "visibility".
- **Undo instead of "Are you sure?"** for reversible actions (unsend, delete memory, leave poll vote). Confirmations are only for destructive or cascading actions (leaving a group with subgroups, deleting a group, deleting the account).
- **No forced setup.** Profile photo, bio and extra fields are optional and never block using the app. No forced tutorial: use short, dismissible hints shown once.
- **Ask for permissions in context,** only when needed (photos when adding a photo, notifications after joining a first group), with a one-line reason. Never on first launch.
- **Elder- and accessibility-friendly:** large touch targets (≥ 48 px), readable default text that scales to 200 %, high contrast, icons always with labels in the bottom bar, no gesture-only actions (every swipe/double-tap also exists in the long-press menu), password-manager friendly sign-in.
- **Works on slow networks:** instant UI with cached content, uploads continue in the background, compressed media by default, clear but quiet offline banner.

**Calm: never annoying**
- **Notifications are personal by default.** Push only for: direct messages, @mentions and replies to you, event changes/reminders for events you RSVP'd to, approvals/invitations for you, and join requests (admins). Everything else (new memories, reactions, poll results) goes to the in-app activity inbox or a **daily digest**, not push.
- **Big groups are quiet automatically:** group chats with more than 50 members default to "mentions only". Reactions are batched ("Mira and 12 others loved your memory").
- **Quiet hours on by default** (10 PM–7 AM local; changeable). One tap mutes any group or chat for 8 hours, 1 week or always.
- **Badges mean something:** red badges only for DMs and things that need *you*. No badge for general activity.
- **No dark patterns:** no streaks, no "people you may know", no re-engagement emails/SMS, no fake urgency, no auto-playing video, no infinite autoplay feeds, no rating prompts more than once per 90 days (and never after an error).
- **No surprise adds or spam:** nobody is added to a group without accepting; message requests filter first contact; invite links expire; members can't be bulk-messaged by strangers.
- **Respect attention inside the app:** no pop-ups on launch, no full-screen promotions, no forced updates except for security fixes. Prototype labels ("Preview") appear once per screen, not on every control.

**How we verify it**
- Every UI phase includes a **task test**: 3–5 real people, including at least one person over 60, try the tasks above without help. Record time, errors and confusion, and fix the confusing parts before moving on.
- Track (later, privacy-safe and aggregated) invite-to-join completion, time to first memory, notification opt-out rate and mute rate. A rising mute rate is a bug.

### 4.1 Information architecture

```text
App
├─ Access ─ Welcome · Create account (mobile + password) · Log in · Invite landing · Pending approval
│           (prototype only: "Explore fictional circles" tour)
└─ Main shell (bottom navigation)
   ├─ Home     — Memories from all my groups (filter chips per group)
   ├─ Chats    — all group chats + 1:1 chats
   ├─ Groups   — my groups as a tree, create/join
   ├─ Events   — upcoming events across my groups, calendar view
   └─ You      — profile, invitations, saved, settings, privacy, notifications
   Top bar: search (within my groups) · activity inbox (bell)

Group space (any level)
├─ Header: cover · name · type icon · breadcrumb (AKCE 2009 › CSE › Sec A) · member count · Invite
├─ Tabs: Memories · Chat · Events · Albums · Subgroups · Members
└─ ⊕ Create sheet: Memory · Poll · Event · Album · Subgroup
```

**Navigation rules**
- Five bottom tabs; each keeps its own back stack (go_router `StatefulShellRoute`, implemented in UI-1).
- The **breadcrumb** in a group header is tappable at every level. **Groups** shows the tree in true parent → child order, so deep groups (up to 10 levels) are always one or two taps away. Recently visited groups are pinned at the top.
- Contextual FAB per tab: Home → *New memory* (pick group), Chats → *New chat*, Groups → *New group*, Events → *New event* (pick group).
- **Tablet/large screens:** two-pane layouts (chat list + conversation, group tree + group space, events list + detail); max reading width 720 px for Memories.
- Deep links: `/i/{token}` (invite), `/g/{groupId}`, `/g/{groupId}/memory/{id}`, `/chat/{id}`, `/event/{id}`, `/poll/{id}`. Every protected link goes through sign-in and membership checks, then resumes.

### 4.2 Screen inventory

| ID | Screen | Key content and actions | Special states |
|---|---|---|---|
| **A. Access** ||||
| A1 | Welcome | Logo + "Private groups. Shared memories.", keepsake collage, "Your people. Your moments. Your circle.", three privacy promises, primary *Create account*, tonal *Log in*, (prototype) *Explore fictional circles*; *I have an invite* once invites resolve for new accounts | — |
| A2 | Create account / Log in | Mobile number with country code, password with show/hide, optional name; password-manager autofill; generic failure messages | Invalid number syntax, password 15–128 chars, rate-limited, offline |
| A3 | Profile setup | Name, photo, about; privacy explanation | Skippable |
| A4 | Invite landing | Group cover, name, type, inviter, member count; *Join* or *Ask to join* | Expired/reset link, already a member, not a member of parent (subgroup) |
| A5 | Pending approval | "Waiting for approval from admins of …", cancel request | Declined |
| A6 | Invitations | Direct-add invitations: Accept / Decline | Empty |
| **B. Home & Memories** ||||
| B1 | Home (Memories) | Group filter chips, memory cards (author, group label, text, photos, reactions, comment count), FAB | Skeleton, empty ("Create or join a group"), offline banner |
| B2 | Memory detail | Full memory, photo carousel, reactions, threaded comments, composer | Deleted/hidden, no access |
| B3 | Create memory | Audience picker (group tree; pre-filled from context, never silently defaulted), text, photos, memory year, place, tag members, add poll | Upload progress/failure, discard draft |
| B4 | Saved memories | Bookmarked memories | Empty |
| **C. Groups** ||||
| C1 | My groups | True tree with unread dots, pinned/recent, pending requests, FAB *New group* | Empty state with *Create* / *Join with link* |
| C2 | Create group / subgroup | Name, type, cover, description, approval setting, link sharing permission, *listed/hidden* (subgroup only), parent shown for subgroups | Depth limit reached (10), name validation |
| C3 | Group space | Header + tabs (§4.1) | No access, pending, removed |
| C4 | Subgroups tab | Listed subgroups: *Join*/*Ask to join*, my subgroups, *Create subgroup* | None listed |
| C5 | Members tab | Search, role badges, owner marker; admin actions: promote/demote, remove (with cascade warning), transfer ownership | Large lists (paged) |
| C6 | Invite people | Share link (system share sheet), copy, QR code, expiry/usage settings, reset link; direct add (contacts in my groups / parent members) | Link sharing disabled for members |
| C7 | Join requests | Approve / decline (single and bulk), requester's shared groups (never their mobile number) | Empty |
| C8 | Group settings | Name/cover/description, type, approval, link sharing, event creation permission, listed/hidden, notifications, *Leave group* | Leave warning lists every subgroup that will also be left; last-admin and owned-subgroup blocks |
| C9 | Reports queue (admins) | Reported items with actions | Empty |
| **D. Chats** ||||
| D1 | Chat inbox | **Chats / Requests** tabs, search, avatars with active-now dot, unread bold + dot, "Seen" / "Sent 2h" status line, pin, mute, swipe to archive | Empty, offline, no requests |
| D2 | Conversation | Grouped bubbles with incoming avatars, time separators, double-tap ❤️, long-press reactions + menu (reply, forward, copy, edit, unsend, pin, report), swipe to reply, shared Memory/event/poll cards, "Seen" / "Seen by…", typing indicator, composer (text, emoji, photo, poll) | Sending/failed/retry, request not yet accepted, blocked, removed from group (read-only) |
| D3 | New chat | People who share a group with me (grouped by group), search | "Can't message this person" (privacy) |
| D4 | Chat details | Shared photos, shared Memories/events, mute, (1:1) block/report, (group) members and jump to group space | — |
| D5 | Message request | Requester's name, shared groups, message preview; **Accept / Delete / Block** | Expired, blocked |
| **E. Events** ||||
| E1 | Events | Upcoming/Past segments, list and month calendar, filters by group, FAB | Empty |
| E2 | Event detail | Cover, type, date/time with time zone, venue + open in maps, hosts, RSVP control with guest count, attendee summary, discussion, polls, photos, add to calendar | Cancelled, past, RSVP closed/full |
| E3 | Create / edit event | Group picker (only groups I'm in), type, details, date/time, venue/online, RSVP options, reminders, co-hosts | Validation (end after start), permission restricted |
| E4 | Attendees | Going/Maybe/Not going tabs with guest counts | — |
| **F. Polls** ||||
| F1 | Create poll (bottom sheet) | Question, options, single/multiple, anonymous, end time, results visibility, date-poll mode | Min 2 / max 12 options |
| F2 | Poll card | Vote, live results bar, voters (if named), closes-in | Closed, already voted, results hidden |
| **G. Albums & media** ||||
| G1 | Albums tab | Album grid with covers, event albums | Empty |
| G2 | Album detail | Photo grid, add photos, captions | Upload queue |
| G3 | Photo viewer | Full screen, swipe, caption, tags, save (if allowed), report | Load failure |
| **H. You & settings** ||||
| H1 | You | Profile, invitations, saved, my events, settings entry | — |
| H2 | Member profile | Global info + fields visible in the shared group, groups in common, *Message* | Limited view by privacy |
| H3 | Privacy | Who can message me, close groups (skip requests), activity status, read receipts, profile field visibility per group, blocked users | — |
| H4 | Notifications | Per type, quiet hours, per-group/chat mute list | — |
| H5 | Account | Appearance (system/light/dark), language, change password, data export, delete account, sign out | Delete confirmation |
| **I. Shared** ||||
| I1 | Activity inbox | Mentions, replies, invitations, approvals, event updates | Empty |
| I2 | Search | Scoped to my groups: groups, members, memories, messages, events | No results |
| I3 | Report flow | Reason picker, optional note, confirmation | — |

### 4.3 Key user flows

1. **New user via invite link:** open link → A4 preview → create account (A2) → join directly or A5 pending → approved → C3 group space (Memories tab).
2. **Create a group and invite:** Groups FAB → C2 → C3 → *Invite* → C6 share link → C7 approve requests.
3. **Build a nested structure:** AKCE 2009 → Subgroups → *Create subgroup* "CSE" → inside CSE create "Sec A" → inside Sec A create "Boys gang" (hidden). Breadcrumb shows the path; the depth limit is enforced at level 10.
4. **Share a memory:** from a group's Memories tab (audience pre-filled), or Home FAB → choose audience → text + photos + year → post → appears in Home and the group's Memories.
5. **Start a 1:1 chat:** Chats FAB → D3 people who share a group → D2 conversation. Or from H2 *Message*, or *Reply privately* on a Memory.
6. **Plan a family function:** group space ⊕ → Event → E3 → publish → members RSVP with guest counts → reminders → afterwards photos go into the event album.
7. **Decide with a poll:** ⊕ Poll (or the poll button in the chat composer) → F1 → members vote on F2 → close → results.
8. **Leave a group:** C8 *Leave* → warning listing every subgroup you will also leave (and any you must hand over first) → confirm.
9. **Report and moderate:** long-press → I3 report → admin's C9 queue → hide/remove → audit trail.

### 4.4 States every screen must handle

Loading (skeletons, not spinners, for lists), empty (helpful next action), error with retry, offline (cached content + banner; queued sends), permission denied / removed from group, content deleted, long names and text, 1000+ members, 100+ subgroups, large photos, dynamic text size (up to 200%), dark mode, RTL-safe layout, slow network.

### 4.5 Visual direction

**Update, 26 Oct 2026 (owner):** use the supplied Warm Keepsake welcome composition, restore lavender/coral/teal accents throughout the shared kit, and default to a pure white/light canvas even on a dark device. This supersedes the monochrome palette described below. Keep the existing optional dark/system appearance choices. See the current-direction section of `docs/design-system.md`.

Warm, calm and premium, suitable for a grandmother, an office team and a college gang alike. Avoid the earlier college-only "nostalgic archive" look and generic social-media clones.
- **"Luminous Pure Minimal"** (owner choice):
  - pure white canvas and cards with `#EAEDF5` hairlines;
  - deep indigo `#1B223C` for actions and selection;
  - slate text (titles `#1A1D2E`, body `#475467`, captions `#667085`) and no saturated accents;
  - Plus Jakarta Sans with tight headlines;
  - 12px buttons, 16px cards, pill chips;
  - lists divided by hairlines.
  - Every Memory shows a lock "audience pill" ("AKCE 2009 › CSE").
- Groups are told apart by icon and name; colour never carries meaning. Everyday reading text stays 16px for ages 15–75.
- **Instagram Direct–style chat:** rounded, grouped bubbles (outgoing in the primary color, incoming on a soft surface), small avatars beside incoming runs, a quiet "Seen" under the last message, double-tap ❤️, swipe-to-reply, and rich cards for shared Memories/events/polls.
- Group identity through cover images and type icons. Breadcrumbs and avatars always tell you *where* you are posting.
- References: `docs/design-system.md` records the adopted "Luminous Pure Minimal" tokens. The earlier "Warm Keepsake" Stitch exports supplied the Home and welcome layouts and the five product corrections (no nagging dot, no "Share" outside the group, one ❤️ control, a single comment count, no audio yet). The concept canvas and the evergreen "CIRCLE Calm" project are superseded.
- Full token and component rules: §16 and `docs/design-system.md`.

### 4.6 UI build phases (mobile, mock data, before backend integration)

Each phase delivers working mock state, tests and goldens, and is labeled as mock in the UI.

| Phase | Scope | Status |
|---|---|---|
| UI-1 | Memories naming; 5-tab shell (Home · Chats · Groups · Events · You); access screens (mobile + password preview); neutral copy; fictional multi-group data (family, nested college batch, office team, club) | **Done** (23 Oct) |
| UI-2 | Groups tree, group space with breadcrumb and tabs, create group/subgroup (depth limit), members and roles, invite link (mock), direct invitations with consent, join requests, approval/listed/hidden settings, leave with cascade warning; remove legacy prototype code | **Done** (23 Oct, mock) |
| UI-3 | Memories: cards, detail, comments with replies, 8-emoji reactions, create with audience picker, photo placeholders (local fictional illustrations) with viewer, polls in Memories, taken-in year/place, edit/delete own Memory | **Done** (23 Oct, mock) |
| UI-4 | Events: Upcoming/Past list with month headers and group filters, detail, create/edit (title + date + place required, rest under More options), RSVP with guests and notes, capacity and deadlines, attendees, date polls, cancel, "who can create events" setting | **Done** (23 Oct, mock; month calendar view deferred) |
| UI-5 | Instagram Direct–style chat UI with local mock messages (explicitly not real-time): inbox with Chats/Requests, group and 1:1 conversations, double-tap ❤️, swipe to reply, unsend/edit, shared Memory/event/poll cards, polls in chat, new chat rules, privacy (who can message me, close groups, blocking) | **Done** (23 Oct, mock; @mentions, forwarding, photos, typing/presence deferred) |
| UI-6 | Albums and viewer, activity inbox (bell), search, member profiles, notification settings (personal push vs digest, quiet hours, mentions-only for big groups), report flows and admin Reports queue with audit trail, tablet two-pane layouts | **Done** (23 Oct, mock) |

## 5. Technology choices

| Layer | Choice |
|---|---|
| Mobile | Flutter 3.44.8 (stable), Dart 3.12.2 |
| State management | Riverpod |
| Navigation | go_router (`StatefulShellRoute` for tabs) |
| HTTP client | Dio (added with the first real API integration, against the reviewed OpenAPI contract) |
| Local cache / offline | To be decided by ADR before M3 (e.g. drift/SQLite) for Memories and chat history |
| Backend | Custom PHP 8.3+ REST API; no Laravel. Draft exists in `backend/` (ADR 0006) |
| Authentication | Mobile number + password (Argon2id), short-lived JWT access tokens + rotating, revocable refresh tokens; OTP later (ADR 0005) |
| Real-time chat | Separate long-running WebSocket service alongside the PHP API (technology chosen by ADR before M6); HTTP polling fallback |
| Database | MySQL 8 |
| Admin console | Vue 3 + TypeScript + Vite + Tailwind CSS (later phase) |
| Media | ADR 0007: `MediaStorage` interface (local folder outside the web root first, S3-compatible later). The server re-encodes every upload (location data stripped, thumb/medium/full sizes). Photos are viewed only via ~5-minute signed links issued after an exact-group check on every request |
| Push notifications | Firebase Cloud Messaging (M5) |
| Development | Ubuntu/Windows, Android Studio/Android device, GitHub, Codex CLI + Codex Web, Claude Code |

**Backend architecture preference:** Task → Entity → SQL (TES), compatible with DataForge concepts. Do not invent or assume access to existing private DataForge packages. Implement minimal self-contained interfaces first; ask for package details only when integration is actually needed. The current draft uses static controllers and repositories. Moving it towards TES is a deliberate refactor for after the contract review, not a side effect of bug fixes.

## 6. Repository structure (target)

```text
circle/
├── README.md                  # Product, UI plan and engineering requirements (this file)
├── AGENTS.md                  # Executable engineering rules
├── CLAUDE.md                  # Claude Code entry point; imports the shared rules
├── .github/workflows/         # CI, added incrementally
├── docs/
│   ├── architecture.md
│   ├── design-system.md
│   ├── decisions.md
│   ├── adr/                   # Architecture decision records (0001–0007)
│   ├── api-contracts/         # openapi.yaml (draft) + overview
│   ├── database.md
│   ├── security.md
│   └── validation.md
├── mobile/                    # Flutter application
│   ├── lib/
│   │   ├── app/               # router, shell, session
│   │   ├── core/              # design system, shared widgets, errors, (later) API client and cache
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── groups/        # groups, subgroups, members, invites, join requests
│   │   │   ├── memories/      # posts, comments, reactions
│   │   │   ├── chat/          # conversations, messages
│   │   │   ├── events/
│   │   │   ├── polls/
│   │   │   ├── albums/
│   │   │   ├── profile/       # profiles, privacy, settings
│   │   │   ├── notifications/
│   │   │   └── moderation/
│   │   └── main.dart
│   ├── test/goldens/
│   └── integration_test/
├── backend/                   # Custom PHP REST API (draft, ADR 0006)
│   ├── public/index.php
│   ├── src/{Core,Controllers,Repositories,Middleware}/   # Tasks/Entities later
│   ├── realtime/              # WebSocket chat service (M6)
│   ├── database/migrations/
│   ├── tests/
│   ├── composer.json
│   └── .env.example
└── admin/                     # Vue 3 dashboard (later phase)
```

These directories are a target structure. Generate actual scaffolding before claiming any command is runnable.

## 7. Data model (minimum)

Authorization is based on **group membership**. Every group-scoped resource carries `group_id`, and every query checks the caller's active membership in that exact group. A user's membership in a parent or child group never implies access.

- `users`: global identity (mobile number, password hash, status, `mobile_verified_at` for later OTP). `refresh_tokens`: hashed, expiring, revocable. `user_profiles`, `group_profile_fields`: per-group profile values and visibility.
- `groups`: `id`, `parent_id` (null for root), `root_id`, `depth` (1–10, enforced), `type`, `name`, `visibility` (`listed`/`hidden`, subgroups), `approval_mode`, `link_sharing` (`admins`/`members`), `event_creation` (`members`/`admins`), `owner_user_id`, timestamps.
- `group_closure`: (`ancestor_id`, `descendant_id`, `distance`) for fast subtree queries, cascade removal and depth checks.
- `group_members`: `group_id`, `user_id`, `role` (`admin`/`member`; ownership lives in `groups.owner_user_id`), `status` (`invited`/`pending`/`active`/`left`/`removed`/`banned`), who added/approved, timestamps. Unique (`group_id`, `user_id`).
- `invite_links`: hashed token, `group_id`, creator, expiry, max uses, use count, revoked_at.
- `join_requests`, `direct_invitations`.
- `memories`, `memory_media`, `memory_tags` (consent state), `comments`, `reactions`, `saves`.
- `albums`, `album_media`, `media_assets` (UUID, group, uploader, private storage key, type, size, dimensions, checksum, status, attached_at; ADR 0007). The draft's `memory_media.storage_path` is replaced, so paths never leave the server.
- `events`, `event_hosts`, `event_rsvps` (`status`, `guest_count`, note), `event_reminders`.
- `polls` (context: memory/chat message/event; settings), `poll_options`, `poll_votes`.
- `conversations` (`type` = `group`/`direct`, `group_id` for group chats), `conversation_members` (request state, mute, archive, pin, last_seen_message_id), `messages` (client_message_id for idempotency, reply_to, edited_at, unsent_at), `message_reactions`, `message_receipts`, `message_shares` (Memory/event/poll/album references).
- `blocks`, `privacy_settings`, `notifications`, `device_tokens`.
- `reports`, `audit_events`.

Use foreign keys, indexes for membership checks, Memories/chat pagination (cursor by time + id) and closure lookups, UTC timestamps, migrations and explicit uniqueness rules. Leaving or being removed from a group runs one transaction that marks membership in the group **and all descendants** (via `group_closure`), cancels pending join requests there, and freezes those group chats for them at that time (history kept read-only; no sending, no new messages delivered).

## 8. API contract guidelines

Base URL: `/api/v1`. JSON requests/responses (multipart for uploads). Stable error shapes, cursor pagination, auth middleware, input validation, idempotency keys for creates, and appropriate HTTP status codes.

**`docs/api-contracts/openapi.yaml` is the source of truth.** It is currently a **draft** describing the endpoints that exist in `backend/`, and it must be reviewed by the owner and both tracks before the Flutter client integrates or new endpoints are added. Planned endpoint areas by milestone:

```text
M2  /auth/register|login|refresh|logout, /me, /groups (+ subgroups, members, roles, leave, transfer-ownership),
    /groups/{id}/invite-links (create, list, revoke/reset), /invites/{token} (preview, join),
    /groups/{id}/join-requests (approve/decline), direct invitations (accept/decline)
M3  /memories (list by group, cursor), /groups/{id}/memories, comments, reactions, saves
M4  /groups/{id}/media/uploads, /media/uploads/{id}/content, /media/{id} (signed link), /media/files/{id}/{size} (drafted, ADR 0007); albums
M5  /groups/{id}/events, /events/{id}/rsvp, /polls, /polls/{id}/votes, notifications, device tokens
M6  /conversations (group/direct), /conversations/requests, accept/decline, messages, reports, blocks
```

Real-time chat events (new message, edit, unsend, reaction, seen, typing, activity status, request received) go over the WebSocket service with the same auth tokens. Every event is authorized against conversation membership. Never let client-supplied IDs alone grant membership or access.

## 9. Security and privacy are non-negotiable

- **Default deny.** Every group, subgroup, conversation, event, poll and media request needs server-side authorization against active membership of that exact group.
- **Nested isolation tests:** prove that parent admins cannot read subgroup content, subgroup links fail for non-parent members, approval re-checks parent membership, removal cascades to every descendant and its chat, no subgroup is left ownerless, and hidden subgroups never appear in listings.
- **Direct messages:** allowed only between users who share a group and whose privacy settings permit it; first contact outside close groups goes to Requests; blocking applies everywhere. A shared Memory/event card in a chat must re-check the viewer's access to that content: sharing never grants access.
- **Passwords (ADR 0005):** PHP `password_hash()` with Argon2id and reviewed cost parameters, `password_needs_rehash` on login, never trimmed or altered, never client-hashed. Generic authentication failures, constant-time behaviour for unknown numbers, and no response that reveals whether a mobile number is registered. OTP codes (later) hashed, short-lived and rate-limited.
- **Tokens:** strong server secret (refuse to boot with an empty or example secret), mandatory expiry, unique token IDs, rotating refresh tokens, account status checked on every request and refresh, logout revokes. Tokens are stored in secure device storage. No committed secrets.
- Validate all input. PDO parameterized statements (native prepares). Limit upload type, size and count; verify actual media content; strip location EXIF unless the user opts in.
- Media is never on guessable public URLs. Use authorization-gated downloads or short-lived signed URLs.
- Rate-limit auth (per IP and per account), invite links, join requests, uploads, posting and messaging.
- Production never returns raw exception or SQL text. Logs redact passwords, tokens, OTPs, **message content** and unnecessary personal data. Admins never see members' mobile numbers.
- Reporting, blocking, account deletion and data export are required before inviting real users.
- No facial recognition or automatic identification. Tagging requires consent and an untag option.
- Use test accounts and fictional content during development.

## 10. Local development prerequisites

- Ubuntu/Linux or Windows with Git
- Flutter 3.44.8 stable SDK and Android SDK/Android Studio
- PHP 8.3+ (with pdo_mysql, mbstring, Argon2) and Composer
- MySQL 8 (use a password for the root account even locally; use a separate `circle_test` database for backend tests)
- Node.js LTS for the future Vue admin dashboard
- Codex CLI / Claude Code and a GitHub repository

```bash
flutter doctor -v
php -v
composer --version
git --version
```

Run instructions: see `docs/development.md`. For Android emulator testing, the emulator reaches the host's localhost via `10.0.2.2`; physical devices need a reachable LAN hostname/IP, and production requires HTTPS.

## 11. Codex Web + local development simultaneously

One **private GitHub repository** is the source of truth. Codex Web, local Codex and Claude Code work directly on `main`. They do **not** automatically share uncommitted changes. Never create feature branches or pull requests.

| Workstream | Tool/branch | Owner files |
|---|---|---|
| Flutter interface | Codex Web / `main` | `mobile/**` |
| API and migrations | Local Codex / `main` | `backend/**` |
| Contracts and security decisions | Shared review on `main` | `docs/**`, `AGENTS.md`, `README.md` |

Rules:
1. Settle the shared API contract and entities on `main` before parallel feature work.
2. One workstream owns a given file at a time. Coordinate ownership before simultaneous Web/local work. Avoid simultaneous edits to lockfiles or shared configuration.
3. Commit completed and verified changes directly to `main`, then push to `origin/main` after successful validation. Never force-push or use destructive Git commands.
4. **Don't leave shared docs uncommitted.** Uncommitted README/AGENTS/docs edits on one machine are invisible to every other machine, and a fresh download elsewhere will look like a revert.
5. Run `flutter analyze` and `flutter test` in `mobile/`; run `composer test` and `composer analyse` in `backend/`.
6. Use `.env.example` for configuration templates and `.env` locally; never commit real secrets.
7. Inspect status and pull the latest `origin/main` before starting. Never overwrite uncommitted changes. If remote changes appear, fetch and reconcile them safely before pushing. Keep tasks small and integration frequent.

## 12. Current status and next milestone

Current pending tasks, dependencies and next-release scope: [execution backlog](docs/pending-work.md). Consult it before starting another feature.

**Done:**
- **M1** (old single-community prototype). It is now retired and its code is being removed.
- **UI-1** (23 Oct): 5-tab shell, access preview (mobile + password, local only), fictional multi-group tour, nested groups with exact-membership checks and the 10-level limit, text Memories, love/save/comment, local RSVP.
- **UI-2** (23 Oct): membership workflows (roles, invites with consent, links, approval, listed/hidden, cascade), with the old prototype removed.
- **UI-3** (23 Oct): Memories with fictional photo placeholders and viewer, replies, 8-emoji reactions, polls, taken-in year/place, edit/delete with Undo.
- **UI-4** (23 Oct): Events with typed dates and time zones, RSVP with guests, notes, capacity and deadlines, attendees, date polls, edit/cancel by hosts and admins, and a per-group "who can create events" setting.
- **UI-5** (23 Oct): Instagram Direct–style chats (local mock, not real-time): group and 1:1 conversations, message requests, reactions, replies, edit/unsend, shared Memory/event/poll cards, privacy settings, activity status and blocking.
- **UI-6** (23 Oct): albums, activity inbox, search, member profiles, notification settings, reporting and moderation, tablet two-pane layouts. **All six UI phases are done as a fictional, session-local mock.**
- **Follow-ups** (23 Oct): skeleton loading, events month calendar, @mentions, message forwarding, photos in chat, album cover and captions.

**Implemented server scope:**
- Accounts, groups/subgroups, membership, invite links, join approvals, Memories, comments, reactions, saves and private Memory photo processing. The owner approved the initial API contract on 23 Oct; later reviewed additions include independent group/Saved pagination and server search. Keep the current contract and release records as the source of evidence.
- Server release builds use the deployed HTTPS API. Explicit preview releases require `CIRCLE_PREVIEW=true`; fictional preview workflows are not persistent live services.

**In progress / gaps:**
- Source checkpoint N1b adds a default-off transactional queue/CLI worker for Memory/comment/reply events, with retries and quiet-hour deferral; see [worker scope and prerequisites](docs/notification-worker.md). No hosted scheduling or native delivery claim.
- Source checkpoint N1a adds session-bound device registration, persistent opt-in category preferences and timezone-aware quiet-hour filtering; see [push foundation](docs/push-foundation.md). Event dispatch, live settings UI and native delivery remain disabled/unverified.
- Firebase/device-token infrastructure was added on 26 Oct, but source review found incomplete event dispatch, foreground/tap handling and lifecycle/error handling. It must satisfy §0.3 before being described as working end-to-end push delivery.
- Real-time chat, live events/polls/albums, server notification preferences and privacy/moderation services are not established by enabling their capability flags. Keep unsupported controls gated under §0.2.
- Recovery/number changes, account deletion/export, additional profile features and other planned families need their reviewed contracts and acceptance checks. Work existing only in another machine's uncommitted checkout is not part of this repository release.
- Physical-device validation and Windows visual approval remain separate from successful cloud tests and widget renders.

**Release correction needed:** the Firebase replacement of `downloads/circle.apk` in commit `8c1f677` reused `1.0.6+7`, changed the signing certificate and left the immutable APK/metadata/site links unchanged. This is a known release defect, not an approved distribution pattern. Correct it using §0.4–0.5 before publishing another runtime release.

**Next:** preserve and reconcile concurrent work, restore truthful capabilities, complete/test the relevant server integration, and package a coherent update with the established signing key. Record actual checks in the release notes and `docs/validation.md`.

Requirements for every UI phase:
- Material 3, responsive phone/tablet, light/dark, accessible contrast, semantic labels, loading/empty/error/offline states.
- Feature folders per §6; Riverpod controllers; go_router; repository interfaces with mock implementations, labeled as mock in the UI.
- Do not fake real-time delivery, uploads or authentication as production behavior.
- Widget tests for navigation, permissions (e.g. depth limit, last-admin rule, cascade warning), state transitions and representative goldens.
- Run `dart format .`, `flutter analyze` and `flutter test`; resolve failures or document environmental blockers.

## 13. Definition of done for MVP

- A new user can register with mobile + password, join a group via invite link (directly or after approval) or accept a direct add, and only access groups they belong to.
- Anyone can create groups and nested subgroups up to 10 levels. Owner/admin/member rules, approval, link expiry/reset, listed/hidden and cascade removal work and are tested server-side.
- Members can share Memories with photos, comment and react, and browse albums.
- Group and 1:1 chats deliver messages in real time with "Seen", offline queuing and no duplicates. Message requests, blocking and DM privacy work.
- Events can be created by members within their group, with RSVP + guest counts and reminders. Polls work in Memories, chats and events.
- Group-only content and private photos are never returned to unauthorized users, including parent-group admins.
- The UI handles offline/network failure and empty states gracefully, and passes the §4.0 task tests.
- Tests cover group isolation, nested-subgroup visibility, cascade removal, DM permissions, token expiry/revocation, invalid uploads and core navigation.
- OTP verification, account recovery, deployment, backup, moderation workflow and privacy notice are documented and in place before inviting real users.

## 14. Roadmap

This is a milestone scope inventory, not proof of live availability. Use §12, the reviewed contract and release validation records for current implementation status; §0 governs feature gates and completion claims.

- **M1 (done, old scope)** and **UI-1 (done)**. **UI-2…UI-6:** rework to the current model with mocks.
- **M2:** OpenAPI contract review, MySQL schema, mobile + password accounts, groups with 10-level nesting, roles, invite links, approval, join requests, direct invitations, cascade removal. *(Draft backend exists; hardening in progress.)*
- **M3:** Memories (posts, comments, reactions, saves), listed/hidden subgroups, member profiles.
- **M4:** Private media storage, photos in Memories, albums.
- **M5:** Events (RSVP + guests, reminders), polls, push notifications (FCM), activity inbox.
- **M6:** Instagram Direct–style chat: group and 1:1, message requests, real-time service, "Seen", typing/activity status, reactions, sharing Memories/events/polls into chat, polls in chat, blocking, DM privacy.
- **M7:** Security hardening (OTP, recovery, E2E decision), moderation tools, private beta, then wider launch.

**Priority rule:** privacy, reliability and a delightful experience for the first real groups matter more than feature count.

## 15. Professional engineering standard (mandatory for every Codex task)

Treat the deliverable as a real consumer-grade social application, **not a collection of disconnected mockup screens**.

### Architecture and maintainability
- Follow feature-first clean architecture in Flutter: `presentation/` (screens/widgets/providers), `domain/` (entities/use cases/interfaces), `data/` (DTOs/repositories/data sources). Avoid adding layers without real purpose. Features must not import another feature's `data/` layer or the `app/` layer; share through domain interfaces or `core/`.
- Make widgets small, composable and strongly typed. Keep business logic (permissions, depth limits, cascade rules) out of widgets. Use Riverpod for asynchronous state with explicit loading, failure, empty and success states; use `go_router` for authenticated navigation and deep links.
- Centralize API client configuration, interceptors, timeouts, retry rules, pagination and typed error models. No HTTP calls inside UI widgets. Model idempotency for create actions and message sends.
- PHP: `declare(strict_types=1)`, PSR-12 formatting, Composer autoloading, DI through explicit constructors, focused Tasks, domain Entities and parameterized SQL repositories. Keep controllers thin. Validate input at trust boundaries. Use transactions when necessary (membership cascades, ownership transfer).
- Define an OpenAPI contract (`docs/api-contracts/openapi.yaml`) as shared truth before concurrently implementing Flutter network clients and PHP APIs. Document WebSocket event schemas alongside it. Do not silently diverge.
- Use database migrations, real FK/index constraints, pagination indexes and safe rollback/migration guidelines. No schema change without a migration.
- Avoid excessive dependencies. Verify current packages and official documentation before installing. Commit dependency lockfiles, but no machine-specific paths or secrets.
- Do not use hardcoded placeholder buttons that appear functional. Either implement the interaction with state and tests, or make its disabled/prototype state obvious.
- Provide meaningful diagnostics, structured redacted logging, tests, reproducible commands and a concise changelog with each milestone.

### Quality gates
- Dart: `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and integration tests where an emulator/device is available.
- UI: widget tests, golden screenshot tests with fixed viewport and fonts, accessibility checks, overflow checks, and manual review on 360×800, 393×852 and tablet layouts; test dark mode and larger text scales. Goldens are rendered on the CI platform (Windows); regenerate them there.
- PHP: Composer validation, PSR-12 linting, static analysis (PHPStan), PHPUnit tests against a dedicated test database, authorization tests for cross-group, nested-subgroup and DM leakage, API integration tests, WebSocket authorization tests.
- Web admin: TypeScript strict mode, lint/type checks, unit tests, Playwright browser smoke tests. Use Playwright **only** for web UI, not as a substitute for native Flutter emulator testing.
- CI: add jobs for Flutter format/analyze/test, PHP lint/static analysis/test and backend security tests; add web jobs when admin is introduced. Validate before committing and pushing directly to `main`; CI reruns checks on `main`.
- Use security reviews for auth, group isolation, nesting, chat, signed media access, rate limits, moderation and retention/deletion. No user-generated media or PII uploaded to external AI/MCP tools without explicit authorization.
- Every delivery reports: scope, screenshots when UI changes, validation commands with real results, risks and known limitations. Do not create pull requests.

## 16. Design system and pixel-perfect implementation

**Visual direction:** see §4.5. Premium, warm and calm for adults of every age and group type. Quiet typography, generous spacing, meaningful empty states, polished transitions and familiar messaging patterns. Not a generic social-media clone.

### Tokens (consolidate in `docs/design-system.md`)
- Spacing: 4-point grid (4, 8, 12, 16, 20, 24, 32, 40).
- Corner radius: 8 (small), 10 (inputs), 12 (buttons, tiles), 16 (cards, menus), 24 (sheets, dialogs), pill (chips, avatars, badges); semantic usage only (`CircleRadius`).
- Typography: Plus Jakarta Sans (bundled, SIL OFL) with the semantic scale in `docs/design-system.md`. **Tamil and other Indian scripts need a fallback font** (e.g. Noto Sans Tamil) once localization is added; test Tamil/English wrapping.
- Colors: semantic `primary`, `surface`, `surfaceVariant`, `textPrimary`, `textSecondary`, `outline`, `success`, `warning`, `error`, plus `bubbleOutgoing`/`bubbleIncoming`, `activeDot`/`unreadDot` and per-group-type accents. WCAG AA contrast. Never scatter hex literals in feature widgets.
- Components: app shell, bottom navigation, top bar, group header with breadcrumb, group tree item, primary/secondary buttons, text field, avatar (+ stacked avatars), member tile, memory card, photo grid/tile, comment, chat inbox tile (active dot, seen status), message bubble (grouping, reply preview, reactions, seen), shared-content card, request card, composer, poll card, event card, RSVP control with guest stepper, role badge, skeleton, empty/error/offline states, dialog and bottom sheet.
- Images: fictional or properly licensed photos in development; no hotlinked remote images. Preserve aspect ratio; show upload progress/fallbacks.
- Accessibility: touch targets ≥ 48 logical px, screen reader labels (including message status and poll results), focus states, keyboard navigation where relevant, text scaling, reduced-motion behavior.

### Visual development workflow
1. Create screen specifications (§4.2) and reusable design tokens **before building every page separately**. Document navigation and critical states.
2. If the user provides a Figma link and has authorized access, use the Figma MCP to read frame/component measurements and variables. Otherwise generate an original design system; **design MCPs do not automatically produce approved product designs or guarantee accuracy**.
3. Build vertical slices in the UI-phase order (§4.6), with functional mock state and tests.
4. Render target screens on an Android emulator/device and capture screenshots at fixed device sizes. Compare them to approved Figma/reference assets or golden baselines; inspect visual differences manually and fix typography, spacing, clipping, alignment, colors and overflow.
5. Maintain golden screenshot tests for stable representative screens and states. Review intentional golden updates instead of blindly accepting diffs.
6. Cover dark theme, keyboard appearance, loading, network failure, long names, deep breadcrumbs (10 levels), zero content, 100+ items, oversized photos, dynamic text size and narrow screens.
7. Run interaction testing in the emulator and on a physical Android device before calling the experience production ready. Verify actual app functionality separately from visual similarity.

**Pixel-perfect definition:** measured agreement with an approved design at a specified viewport and rendering environment, plus functional correctness and accessibility; no promise that arbitrary Android/iOS devices render pixel-identically.

## 17. MCP setup (verified integrations)

MCP gives Codex/Claude access to extra tools; **MCP servers are optional integrations, not replacements for Flutter SDK, Android emulator, static analysis, or human design review**. Install only trusted tools after checking their permissions. Run setup on your own computer; this README does not install tools automatically. Configuration is machine-local (`~/.codex/config.toml` for Codex, `~/.claude.json` for Claude Code) and does not sync with Codex Web.

### Recommended servers

| MCP | Purpose | When to use |
|---|---|---|
| **Figma (official)** | Fetch authorized Figma frame layout, components, tokens and assets for design-to-code work | When an actual Figma design/reference exists; requires login and Figma access |
| **Google Stitch** | Generate original screen designs and variants from prompts, using a project design system | Exploring layouts before a UI phase; results are proposals, not approvals. Authenticates with an API key header; keep the key out of the repo and chat |
| **Mobbin (official)** | Browse real-world mobile app screens and flows (e.g. Instagram DMs, invite flows, event RSVP) as **design inspiration** | Before designing a UI phase; references only, never copy another product's proprietary design or assets. Requires a Mobbin account (OAuth) |
| **Playwright (Microsoft)** | Inspect and exercise the **web** admin dashboard and web UI via browser automation | For Vue admin later and any supported Flutter web target |
| **Context7 (Upstash)** | Fetch current library/framework API documentation | During Flutter/Riverpod/go_router/Dio and PHP dependency implementation |
| **OpenAI Developer Docs (official)** | Read current OpenAI developer documentation | Optional, only for OpenAI-related integrations |

### Local installation commands

```bash
# Prerequisites: installed/authenticated Codex CLI and Node.js/npm.
# Official Figma remote MCP; browser OAuth may be required.
codex mcp add figma --url https://mcp.figma.com/mcp

# Official Mobbin remote MCP (design references); browser OAuth on first use.
codex mcp add mobbin --url https://api.mobbin.com/mcp

# Official Microsoft Playwright MCP (browser testing for web interfaces).
codex mcp add playwright -- npx -y @playwright/mcp@latest

# Documentation MCP (choose this hosted option or follow Context7's current setup).
codex mcp add context7 --url https://mcp.context7.com/mcp

# Optional: official OpenAI developer documentation.
codex mcp add openaiDeveloperDocs --url https://developers.openai.com/mcp

# Inspect registered integrations:
codex mcp list

# Claude Code equivalents (user scope), e.g.:
# claude mcp add --transport http --scope user mobbin https://api.mobbin.com/mcp
# claude mcp add --transport http --scope user stitch https://stitch.googleapis.com/mcp --header "X-Goog-Api-Key: <your key>"
```

For any integration requesting authentication, follow its official login flow (`codex mcp login <name>` or `/mcp` in Claude Code). Avoid storing tokens directly in README, tracked TOML, shell history or repository files; never paste API keys into chats, and rotate any key that was. Figma feature availability is subject to account permissions and plan limits.

**Verified docs:**
- Codex MCP: https://learn.chatgpt.com/docs/extend/mcp?surface=cli
- Figma + Codex: https://help.figma.com/hc/en-us/articles/39888629089175-Codex-and-Figma-Set-up-the-MCP-server
- Mobbin MCP: https://github.com/mobbin/mobbin-mcp-server (client setup: docs.mobbin.com/mcp/clients/overview)
- Playwright: https://github.com/microsoft/playwright-mcp
- Context7: https://github.com/upstash/context7/blob/master/docs/clients/codex.mdx
- OpenAI documentation MCP: https://developers.openai.com/learn/docs-mcp

### Critical limitation for Flutter
Playwright, Figma, Stitch and Mobbin do **not** validate native Flutter pixel rendering. Use Flutter's `integration_test`, golden tests, real Android emulator/device screenshots and Flutter diagnostics for native UI. If an optional Flutter-specific MCP integration is added later, first verify its maintainer, package provenance, compatibility and supported tools in current documentation. Do not fabricate a server name or installation command.

### Codex Web / Cloud caveat
Cloud tasks run in separate environments and should not assume access to local MCP processes, devices, Figma login sessions or local MySQL. Configure permitted tools in the cloud environment separately when supported. Keep design references and nonsecret contracts in Git; never upload private group photos, chats or credentials for build convenience.

## 18. Codex delivery protocol and agent prompt

Codex should read `README.md` and `AGENTS.md` on every new workstream. Implementation must be iterative and validated. Never present scaffolded, nonworking screens as complete. If a tool is unavailable, record the blocker and continue with reliable local tooling.

**Recommended message for the next workstream:** see `CODEX_START_PROMPT.md`.

### Review rubric
For milestone acceptance, check: ease-of-use targets and calm notification rules (§4.0) with task-test notes, coherent end-to-end flows, visual consistency, clean architecture, robust state handling, correct enforcement of group/nesting/privacy rules, meaningful tests, documented setup, safe handling of private data and a reproducible working build. Reject vague "done" claims without a command result or working demonstration.

## 19. Implementation readiness and definition of done

A task is **done** only after acceptance criteria are met, not when code is merely generated.

**Required checks before every Flutter UI commit**
```bash
cd mobile
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

**Required checks before backend commits**
```bash
cd backend
composer validate --strict
composer install
composer test        # needs a local circle_test database (see docs/development.md)
composer analyse
```
All claims of passing tests must be backed by actual command execution. CI should use pinned SDK versions and lockfiles.

**Mandatory code review checklist**
- Every authenticated query checks active membership in the exact `group_id` (never inherited from parent or child groups), including media, search, chat, events and polls.
- Nested-group rules hold: depth ≤ 10, parent membership required to join and at approval, cascade removal without orphaned subgroups, hidden subgroups never listed, parent admins cannot read subgroup content.
- DMs are allowed only between users who share a group and whose privacy settings allow it; blocks are enforced.
- Auth follows ADR 0005: no enumeration, no password trimming, strong secrets, mandatory expiry, status checks.
- Feature modules expose interfaces and typed models; UI widgets never call raw HTTP or SQL directly.
- Use immutable state where practical, dependency injection, pagination and cancellable requests.
- Handle offline/network errors, retries without unsafe duplicate writes, form validation and unknown backend responses.
- Prevent hard-coded credentials, public media access, verbose personal-data or message logging and unbounded file uploads.
- Supply semantic accessibility labels, text scaling, responsive layouts and clear empty/error states.
- Follow §4.0: tap-count targets met, smart defaults, advanced options hidden, undo instead of confirmations for reversible actions, no new push notification types without justification against the calm rules, no dark patterns.
- Include a screenshot or state-specific golden comparison for each meaningful UI change. Report deviations.
- Ensure tests cover business behavior, state transitions, authorization denial and group isolation.

**Repo collaboration policy**
- Always work on `main`; never create feature branches or pull requests. Pull `origin/main` before starting, commit completed and verified work directly to `main`, and push after successful validation. Fetch and reconcile remote changes safely before pushing.
- UI phases own `mobile/`. Backend tasks own `backend/`; changes to `docs/api-contracts/` require review by both tracks.
- Keep commits focused and reviewable. Never use force push or destructive Git commands. Preserve all uncommitted changes and coordinate file ownership between concurrent Web/local workstreams.
- `AGENTS.md` records executable development rules; `README.md` defines product, UI and implementation requirements.
- Record architectural decisions in `docs/adr/` using decision, context, alternatives and consequences.

## 20. First-run setup and execution order

1. Read §0 and `AGENTS.md` (`CLAUDE.md` is the Claude entry point), then check `git status`, the repository structure and available toolchain (`flutter doctor -v`, `dart --version`, `php -v`, `node -v`).
2. Check the MCP list; set up only MCP servers the user authorizes. Credentials, OAuth login and device/emulator interactions require the user's participation when prompted.
3. If no Figma design exists, follow `docs/design-system.md` (§4.5/§16) and create original in-app designs; do not claim a Figma-derived pixel-perfect result.
4. Continue the UI phases (§4.6) with fictional local data; backend work follows the reviewed OpenAPI contract.
5. Run formatter, analyzer and tests; capture emulator screenshots if an emulator is available. Document any validation that could not run.
6. Commit completed and verified changes directly to `main` and push to `origin/main` after successful validation. Include a concise delivery report with checks and screenshots. Never create feature branches or pull requests.

**Do not launch or collect real people's personal information until** invite-only access, nested-group isolation, private media delivery, DM privacy and blocking, abuse reporting, content deletion, account deletion, OTP/recovery, security checks and a simple privacy notice are implemented and reviewed.
