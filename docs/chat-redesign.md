# Live Chats visual refresh — 29 October 2026

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
