# API contracts

**`openapi.yaml` (OpenAPI 3.1) is the source of truth for `/api/v1`.**

**Approved by the owner for implementation on 23 Oct 2026 (0.3.0); now at 0.3.2 with M4 media and reviewed Memory query filters implemented.** It describes the implemented operations the draft backend implements today (ADR 0006):
- accounts and sessions;
- groups and nested subgroups;
- members, roles, bans and ownership transfer;
- invite links: create, list, revoke, reset, preview, join;
- join requests;
- Memories with comments, reactions and saves.

The app may now integrate with the implemented endpoints, and the backend may implement the planned ones (M4 media first). Both tracks (mobile and backend) must review any contract change.

## Contract scope by milestone

| Milestone | Resources | State |
|---|---|---|
| M2 | auth (register/login/refresh/logout), `/me`, groups (root + subgroups, depth ≤ 10), members and roles, bans, ownership transfer, invite links (expiry, max uses, revoke, reset), invite preview and join, join requests (approve/decline), leave (cascade) | **Implemented in draft**; direct invitations with consent still missing |
| M3 | Memories, comments, reactions, saves; listed/hidden subgroups; per-group profile fields | Memories implemented in draft; profile fields missing |
| M4 | private media: upload tickets, content upload with server re-encoding (EXIF/GPS stripped, 3 sizes), short-lived signed view links re-checked per request, unattached cleanup; albums | **Media implemented** (0.3.1): upload ticket, content upload, signed link, signed download, discard, `media_ids` on Memories. Real image processing needs `php8.3-gd`. HEIC is refused until an Imagick processor exists. Albums and chat attachments not drafted |
| M5 | events, RSVPs with guest counts, reminders, polls and votes, notifications, device tokens | Tables exist (migration 004), no endpoints |
| M6 | conversations (group/direct), message requests, messages (cursor pagination, client message IDs, edit ≤ 15 min, unsend), seen receipts, reactions, shared-content references, blocks, DM privacy; WebSocket events `message.new`, `message.edited`, `message.unsent`, `reaction`, `seen`, `typing`, `activity`, `request.new` | Not started |

## Rules every endpoint must specify

- **Authorization:** active membership in the exact `group_id`; parent or child membership never implies access. A missing group and a group you're not in look the same. Conversation membership applies to chat. DM eligibility = shared group + privacy setting + not blocked.
- **Stable error envelope:** `{success:false, error:{code, message, details?}}`. Codes include:
  - `not_member`, `pending_approval`, `depth_limit`, `last_admin`, `owner_protected`, `subgroup_handover_required`
  - `link_expired`, `link_revoked`, `invalid_cursor`, `account_inactive`, `conflict`
  - `dm_not_allowed`, `blocked` (planned)
- **No account enumeration:** registration always returns the same 202 response and issues no tokens. Login failures are generic.
- **Pagination:** cursor-based for Memories, messages, members and events. The cursor is opaque: (created_at, id).
- **Idempotency keys** for creates and message sends. These are planned and not yet implemented.
- **Tokens:** short-lived access token plus single-use rotating refresh token, both tied to a revocable session. Logout ends the session immediately.
- **Rate limits:** per endpoint class, including per-mobile failed-login throttling. Responses include `Retry-After`.
- **Media:** only through authorization-gated downloads or short-lived signed URLs.

## Backend choices (accepted by the owner with the contract, 23 Oct 2026)

1. **Leaving or removal** is blocked while the person owns, or is the last admin of, any subgroup in that subtree (`subgroup_handover_required`). Should a "delete/archive subgroup" option exist?
2. **Removed members** can rejoin only through a link created after their removal. Bans (`?ban=true`) block rejoining until lifted.
3. **Registration** returns 202 without tokens, and the app then logs in. This prevents number enumeration.
4. **An invite-link use** is consumed when a join request is created, not only on approval.
5. **Refresh tokens** are single-use. Access tokens last 1 h; refresh tokens 7 days.
6. **Reactions** are limited to an 8-emoji allowlist: ❤️😂😮😢🙏👍🎉🔥.

Implement the Dio client only against the reviewed contract.

## 0.3.2: independent saved/group timelines and complete Memory search

Both the mobile and backend tracks reviewed additive `GET /memories` filters: `saved=true` selects only the current viewer's bookmarks; `saved=false`/omitted is unfiltered. `q` searches literal body/place substrings, trimmed, valid UTF-8, at most 200 Unicode code points, with empty/whitespace-only unfiltered. `%`, `_` and `!` are literal. Both combine with existing `group_id`, `cursor` and `limit`; active exact-group membership still governs every result. The existing response shape and opaque newest-first cursor are unchanged.
