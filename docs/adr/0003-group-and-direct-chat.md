# ADR 0003: group and 1:1 chat

Status: scope accepted by the owner, 22 Oct 2026. Real-time technology to be chosen in a follow-up ADR before M6.

## Decision

- Every group and subgroup has a group chat whose membership always mirrors the group's.
- **1:1 direct messages** are allowed between users who share at least one group, subject to the recipient's "who can message me" setting and blocks. There is no global user search and no contact upload.
- The experience follows **Instagram Direct** (owner decision, 22 Oct 2026, replacing the earlier WhatsApp-style plan):
  - message **requests** for first contact outside close groups;
  - "Seen" instead of delivery ticks;
  - double-tap ❤️ and quick reactions, swipe to reply, edit within 15 min, unsend;
  - activity status (can be turned off);
  - **sharing Memories/events/polls into chat** and replying privately to a Memory;
  - polls (README §3.2).
- Chat is built in **M6**, after membership, Memories, media and push notifications exist. UI-5 builds the screens with a local mock stream.
- **Leaving or being removed from a group** (owner decision, 23 Oct 2026): the person's copy of that group chat, and of every descendant subgroup chat they also leave, becomes **read-only and frozen at the moment they left**.
  - Earlier messages are **not deleted** and stay readable to them.
  - They **cannot send** and **receive nothing new**: messages sent after they left are never shown to them.
  - Rejoining restores normal access.
- v1 encrypts in transit and stores messages privately on the server. End-to-end encryption for 1:1 chats must be decided before public launch (M7).

## Context

The README originally excluded chat. The owner now requires both group and 1:1 chat. Chat depends on reliable membership and notifications, and it adds real-time infrastructure beside a PHP REST API.

## Alternatives

- **WhatsApp-style chat (ticks, delete-for-everyone windows, phone-number reachability):** familiar, but invites a feature-for-feature comparison with WhatsApp and is less connected to CIRCLE's Memories. Replaced by the Instagram Direct model.
- **Group chat only:** less abuse surface, but doesn't meet the owner's requirement.
- **Open DMs to anyone:** maximum reach, but strangers and spam break the privacy promise.
- **E2E from day one:** strongest privacy, but large effort (key management, multi-device, groups) that would delay launch. Revisit in M7.

## Consequences

- A long-running WebSocket service with token auth, per-event membership checks and an HTTP polling fallback.
- Client message IDs for idempotent sends, cursor pagination, per-user receipts and offline queues.
- Shared content cards must re-check the viewer's access; sharing a Memory never grants access to its group.
- Logs must never contain message content. Reporting and blocking must ship together with DMs.
- Removing or leaving a member immediately stops sending and new-message delivery in that group's chat and its descendants' chats. Their history up to that moment stays readable to them.
  - The server must filter messages by the member's `left_at`/`removed_at` time.
  - Shared Memory/event cards inside that history still re-check current access, so leaving revokes access to the group's content even where a card remains in the old chat.
