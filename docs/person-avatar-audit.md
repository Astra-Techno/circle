# Person-avatar audit and integration

27 October 2026. The build14 fix connected profile pages only. The owner reported initials still appearing on Memories and group members. This batch audits all avatar constructors and connects identity-based person avatars through a single component without changing group/category icons or mixing real identities into preview data.

| Surface | Result |
| --- | --- |
| Memories cards/detail author | PersonAvatar using authorId; real private thumbnail |
| Latest comment/detail comments/replies | PersonAvatar using comment.authorId; preview geometry unchanged |
| Group member rows | PersonAvatar using membership user id; server rendering in batches of30 with Show more and Refresh members |
| People search and Memory search | PersonAvatar using stable person/author ids; search already capped20 per section |
| Mention suggestions | PersonAvatar using candidate id; existing bounded suggestions retained |
| Other-member profile/avatar/banner | Existing private surface retained; shared thumbnail provider/cache reused; Refresh photos clears cache |
| Own You/profile/header/app-bar | Existing own-photo surfaces remain; list avatars use the same own-photo provider/version |
| Chat inbox/forward/header/details/participants/senders/shared Memory/new contact/blocked list | Stable ids wired into reusable avatars; currently preview capability stays gated and makes no real-photo requests |
| Event attendees and person invite choices | Stable ids wired; fictional preview remains initials without HTTP |
| Group/type/activity/event/album/scene icons | Intentionally stay category/content icons |
| Preview poll voters and moderation audit names | Existing name-only view DTOs do not expose person ids; never infer identity from a display name or enable a live service |
| Authentication/fictional profile placeholders | Intentionally remain initials/icons; no real identity to fetch |

OpenAPI0.3.9 adds nullable opaque avatar_version to active exact-group Member responses. Private paths remain null; photo UUIDs are not URLs or credentials. No migration is needed. Workspace refresh rebuilds the version map from authorized member lists; absent photos never trigger speculative requests in list avatars. Private endpoint ownership/exact shared-membership and active-account checks are unchanged. No broader directory, parent inheritance, public photo URLs or image upload is added.

PersonAvatar preserves size/tone/active dot and semantic behavior via the core avatar's optional MemoryImage. Initials remain for missing/error/inaccessible photos. Bytes are deduplicated per person/kind by Riverpod across rows and screens. A64-entry in-memory LRU with45-second lazy expiry reuses recently viewed thumbnails without background timers or disk persistence; explicit photo refresh clears it. Account/API changes isolate the cache; session revision changes clear its namespace. Version updates invalidate photo providers so replacements/removals cannot remain as stale row images. A previously subscribed provider may confirm removal with one404; initial known-absent rows fetch nothing. No display-name matching is used, including duplicate names.

Authenticated private avatar/cover GET routes use a separate bounded per-IP quota RATE_LIMIT_PROFILE_PHOTOS_PER_MINUTE (default240/minute) instead of spending the normal60/minute API budget. Upload/delete/other APIs keep their existing quotas. Auth still precedes private reads; missing authentication does not consume that authenticated read budget. The default works without changing hosted .env. Members load visible batches of30 to avoid downloading an entire large group's photos at once; Home remains lazily built and search/suggestions bounded.

Validation: dedicated circle_test192 tests /3,193 assertions, PHPStan clean. New tests verify member photo-version presence/replacement/removal, null private paths, outsider rejection and isolated/bounded photo quota. Client focused tests cover duplicate names, cross-screen request deduplication, same-account session change, cache expiry/LRU bounds, replacement/removal, large-group request bounds and phone/tablet light/dark200% layouts. Eight screenshots rendered and inspected. Full Flutter/release results are in PROJECT_STATE.md and the build15 release record. Backend/client contract review cross-checked Member fields, private routes and quota changes; authorization is not inferred from widget rendering. All fixtures are fictional; physical-device display remains owner acceptance.

After installing build15 on both phones, refresh Memories by pulling down or use Refresh members. No re-upload is needed. Check own and another member's avatar, repeated Memories, comments/replies, mentions and people search, then replace/remove a photo and refresh. Shared profile banners continue to use build14's private implementation.
