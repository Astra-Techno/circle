# Live Chats visual refresh — 29 October 2026

## WhatsApp layout (owner, 29 October 2026)

The owner asked for Chats to look exactly like WhatsApp. Live (server) Chats now follow WhatsApp's layout in CIRCLE's colours:

- **Inbox:** large photo, name, last message ("You: …", "Mira: …" in groups, Photo/unsent notes) and its time (time today, Yesterday, weekday, then date); unread count, muted and pinned marks. Sorted by latest activity, pinned first. No page heading or "New message" button: the header + starts a chat; pull down to refresh. Messaging privacy stays as a quiet link.
- **Conversation:** full screen (the tab dock hides), its own bar with back, photo, name and ⋮ options (mute, pin, archive, group polls, refresh, block). Warm wallpaper, day chips (Today/Yesterday/date), white incoming and indigo-tinted outgoing bubbles with a tail on the first of a run, sender names in groups, quoted replies, photos inside the bubble, reactions under it and the time (and "Edited") tucked into the bubble's corner. Long-press a message for Reply, heart, Copy, Edit, Unsend/Undo, Report; screen readers get the same through a custom action.
- **Composer:** rounded input with the camera inside and a round send button, pinned at the bottom; at very large text it scrolls with the conversation, and choosing Reply scrolls back to it.
- Opening the latest messages marks them read automatically. The read position only feeds the viewer's own unread count and is never shown to anyone, so nothing is revealed (message requests included).
- Not copied from WhatsApp: green branding, delivery/read ticks (the API has no per-message receipts and none are fabricated), online/last-seen, calls, voice notes and emoji keyboard.

Server: `GET /chats` adds `other_id` and `last_message` and orders by latest visible message (OpenAPI 0.4.4). A member who left a group keeps a preview frozen at their cutoff; unsent messages expose no text.

## Earlier refresh

Owner requested a WhatsApp/Instagram-inspired message module. This refresh applies to authenticated live Chats; fictional preview behavior stays separate.

- Inbox uses flat avatar-led conversation rows, real unread counts and mute/pin indicators instead of stacked cards. The current inbox contract has no last-message preview, timestamp or other-person id; do not fabricate snippets/online status or resolve profile photos by display name. Group photos reuse the existing scoped group-photo pipeline and fall back to icons; direct inbox rows use initials until the API supplies the other person’s identity.
- Conversation has a compact identity header, opposing neutral/indigo bubbles, localized message times and sender names for incoming group messages. Own messages do not repeat the account name.
- Photo, message and send controls share a pinned row. At large text they stack and scroll with the conversation. Photo restrictions, retry ids and session guards remain unchanged.
- Mute, pin, archive, block, refresh and group polls are under Conversation options. Requests and accept/decline remain visible outside that panel. Existing mark-read action remains explicit.
- Accessible message menus expose reply, heart, edit, unsend/undo and selected-message reporting; choosing an action dismisses the menu first. The selected-message privacy explanation is unchanged.

Use the shared Editorial tokens and private profile-photo pipeline. No new networking in widgets, API changes, fabricated receipts or new messaging permissions.

Validation and APK publication are recorded in the release notes and PROJECT_STATE.md. Native-device acceptance remains separate from widget renders.

Review renders (fictional fixtures, not approved Windows golden baselines):

- [Phone, light](design-previews/chat-refresh/phone-light.png)
- [Tablet, dark, 200% text](design-previews/chat-refresh/tablet-dark-large-text.png)

Verification: Flutter analyzer/format clean. Focused chat/retry/reporting/design regressions: 97 passing. Final live-chat/media/group-photo/design regressions: 51 passing. Full suite: 739 passing, one skipped, 13 existing Windows-baseline golden mismatches on Linux (no functional failures); baselines were not regenerated. Eight populated chat renders cover light/dark, 320/900 logical pixels and 100/200% text. No physical Android device was available.
