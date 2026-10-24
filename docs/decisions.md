# Decisions

1. Original Material 3 design because no approved Figma frames exist. Local icon illustrations avoid external media and licensing ambiguity.
2. In-memory repository and explicit demo invitation instead of simulated production accounts. No password is requested or stored. Sign-in/sign-up production forms are deferred; the Phase 1 startup prompt prioritizes mock invitation access.
3. Shared typed community catalogue supports functional supporting screens without artificial repository layers for each static fixture. Feed has its own domain/data/presentation boundary and async state.
4. No Dio dependency until networking exists, as permitted by the startup prompt. No backend or cloud configuration.

Dependency guidance was checked against the primary package documentation: [Riverpod](https://pub.dev/packages/flutter_riverpod), [go_router](https://pub.dev/packages/go_router) and its [API reference](https://pub.dev/documentation/go_router/latest/). The installed SDK resolved compatible versions; pubspec.lock records them. Context7 was unavailable.

5. Resume only allowlisted in-app destinations after invitation entry. Unknown destinations default to the feed, and ending a session discards the return destination. Native app-link registration remains separate. Guidance: [go_router redirects](https://pub.dev/documentation/go_router/latest/topics/Redirection-topic.html).
6. Build timeline cards on demand with stable identity; keep the existing appearance and session state. Repository pagination is deferred until a reviewed API contract exists. Guidance: [Flutter ListView.builder](https://api.flutter.dev/flutter/widgets/ListView/ListView.builder.html).

## Product model update — 22–23 Oct 2026

7. Scope widened from one college community to any private group (family, friends, school, college, office, club). The post stream is called **Memories**, never "feed". See README §1.
8. Groups nest up to 10 levels with identical per-group rules, no inherited access, parent membership checked at join and approval, and cascade removal without orphaned subgroups. See [ADR 0002](adr/0002-any-community-nested-groups.md).
9. Group chat plus 1:1 chat limited to people who share a group, built in M6, following the **Instagram Direct** model (message requests, "Seen", double-tap ❤️, sharing Memories into chat). See [ADR 0003](adr/0003-group-and-direct-chat.md).
10. Member-created, group-scoped events with guest-count RSVPs, plus polls in Memories, chats and events, in M5. See [ADR 0004](adr/0004-events-and-polls.md).
11. Accounts use mobile number + password, OTP later; registration never grants membership. See [ADR 0005](adr/0005-mobile-password-authentication.md).
12. **Ease of use and calm notifications are the top UX priority.** README §4.0 sets tap-count targets, smart (never silently wrong) defaults, personal-only push by default, quiet hours, auto-quiet large groups and no dark patterns, and these override feature wishes. Every UI phase includes a short task test with real users, including someone over 60.
13. The early PHP backend is kept as an M2 draft, frozen to fixes, hardening and tests until the owner reviews the draft OpenAPI contract. See [ADR 0006](adr/0006-early-backend-draft.md).
14. UI is rebuilt in phases UI-1…UI-6 (README §4.6). UI-1 is done; the retired first prototype (feed, CIRCLE-DEMO, single community) is removed in UI-2.
15. **Visual direction: "Warm Keepsake Minimal"** from the owner's Stitch design (23 Oct 2026). It replaces evergreen with deep indigo on linen, plus lavender/coral/teal accents and bundled Plus Jakarta Sans. Five corrections keep it within the product rules: no nagging dot, no Share outside the group, one ❤️ control, a single comment count, no audio yet. Text uses darker accent variants for WCAG AA. See `design-system.md`.
16. **Visual direction changed to "Luminous Pure Minimal"** (owner, 23 Oct 2026; `~/Downloads/DESIGN.md`). It replaces Warm Keepsake (decision 15):
    - pure white canvas and cards, indigo actions, slate text, cool hairlines and no saturated accents;
    - 12px buttons, 16px cards, divider-separated lists.

    One deviation: everyday body text stays 16px for readability (§4.0). Token names in code are unchanged, so screens didn't need rewriting.
17. **UI-3 Memories behaviour** (confirmed by the owner, 23 Oct 2026):
    1. Tapping Love when you reacted with another emoji removes your reaction rather than switching it.
    2. Poll settings live under their own "More poll options".
    3. Votes get Undo only when vote changes are allowed; closing a poll asks for confirmation.
    4. Poll results follow the visibility setting strictly; the creator gets no early view.
    5. "+N more" counts the photos beyond the three shown.
18. **UI-4 Events behaviour** (confirmed by the owner, 23 Oct 2026):
    1. Online events need a link (place optional); other types need a place and can add a link.
    2. With a date poll, the date can be left empty; the earliest slot is used until a host edits it.
    3. Date polls are named, show results to everyone, are multiple choice by default, have no end and allow changing your vote.
    4. RSVPs close when the event starts; "past" means after the end (or the start if no end).
    5. Cancelled events stay under Upcoming with a "Cancelled" pill.
    6. New events default to type "Other".
    7. Lowering capacity never removes people already going; it only blocks new "Going" answers.
19. **Leaving a group's chat** (owner, 23 Oct 2026): messages are never deleted. When someone leaves or is removed, that group chat (and the chats of descendant subgroups they leave) is disabled for them: history up to that moment stays readable, sending is blocked, and no new messages are delivered. Rejoining restores access. This updates ADR 0003.
20. **UI-5 Chats behaviour** (owner, 23 Oct 2026):
    - **Activity status:** "Active now / Active 2h ago" is shown in 1:1 contexts, with a "Show activity status" privacy setting (on by default).
      - Reciprocal: hiding yours hides others' from you.
      - Only between people who share a group and haven't blocked each other.
      - Never shown in group chats or member lists; nothing older than 48 h.
      - Hidden both ways while a message request is unaccepted, consistent with "Seen".
    - **Sharing into chat:** only items everyone in the chat can see.
    - **Confirmed as built:**
      - "Nobody" blocks all incoming 1:1s, including existing ones.
      - "Chatted with" means they messaged you or accepted your request.
      - Blocking hides their group-chat messages too.
      - Groups over 50 members start muted.
      - Northbank 2009 has 57 fictional members.
      - A single tap shows Love / Reply / More.
      - The group Chat tab opens in Chats.
      - A deleted request has Undo and returns on a newer message.
21. **UI-6 behaviour kept as built** (owner, 23 Oct 2026). This includes the visible Report button under comments, and chat mute staying separate from group notification levels. See validation.md for the full list.
22. **Private media storage** (owner, 23 Oct 2026). See [ADR 0007](adr/0007-private-media-storage.md).
    - Upload tickets; server-side validation and re-encoding (location data stripped, three sizes).
    - Private random storage keys behind a `MediaStorage` interface.
    - Retrieval only via ~5-minute signed links issued after an exact-group (and chat "frozen" rule) check on every request.
    - Orphan cleanup after 24 h; purge within 7 days after deletion.

    The endpoints are drafted in `openapi.yaml` as **planned (M4)** and are not implemented until the contract is reviewed (ADR 0006).
23. **API contract approved** (owner, 23 Oct 2026): `openapi.yaml` 0.3.0 is approved for implementation, together with the six backend choices in the API overview. ADR 0006's freeze is lifted. Order of work: M4 media backend, then app–backend integration, then the remaining UI items.
