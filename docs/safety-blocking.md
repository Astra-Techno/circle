# S2b — direct-contact blocking

27 October 2026. Owner chose: stop direct contact; keep group content visible. OpenAPI0.3.12/migration016 implement this policy for supported live services. Chats and broader profile-field privacy remain gated.

Block a shared person from their profile or a sender from a received invitation. A sent invitation alone does not grant target lookup. You → Privacy and blocking lists only your outgoing blocks, 30 per page. Labels are private snapshots taken when blocked. Unblock works after shared membership ends; there is no reverse-block list or block/unblock alert.

| Surface | Behaviour |
|---|---|
| Direct Circle invitations | Stop in both directions. Pending invitations expire atomically; inbox/detail/acceptance deny blocked pairs. Unblock does not revive old invitations. |
| Personal comment/reply alerts | Suppressed in both directions at capture and worker delivery, including previously queued alerts. |
| Ordinary group Memory updates | Continue under existing preferences, quiet hours and membership checks. |
| Shared-group profiles/photos, Memories/Saved/search, comments/reactions | Remain visible under existing exact-group access rules. No photo-link format change, directory redaction or content filtering. |
| Membership, roles, branding, reports and moderation | Continue under existing group rules and exact-admin authorization. |
| Future direct messaging | Must enforce the pair block check when implemented; live Chats are not enabled by this batch. |

PUT/DELETE are idempotent and disallow self targets. New blocks require an active target with shared exact active membership or a received invitation. Sorted user locks and current-session checks serialize block creation with invitation acceptance. Only the caller's own block can be removed.

The client captures API/account/session before confirmation dialogs and guards request and completion scopes. Invitation cards retain the scope that loaded them and clear after a blocking action so expired detail cards cannot remain actionable. Group content and image caches remain available, consistent with the chosen policy. Unsupported privacy settings remain gated.

Regression coverage checks group content/media remain accessible, private snapshots/state, invitation expiry and eligibility, personal alert suppression versus ordinary group updates, stale sessions, and narrow/tablet light/dark large-text layouts. Final validation and publication evidence are recorded in the build18 release record. Physical Android installation and two-phone invitation/notification checks remain owner acceptance.

Device acceptance (pending): install build18 over build17; block a shared person and confirm both people still see shared profiles/photos/Memories/comments. Verify direct Circle invitations and personal comment/reply alerts stop in both directions, while ordinary group Memory updates continue. Check You → Privacy and blocking, unblock after leaving a shared group, and confirm an expired invitation does not revive. Actual Android/FCM delivery is not established by server or widget tests.
