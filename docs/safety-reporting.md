# S2a — private reporting and group moderation

27 October 2026. This is the first safety/privacy delivery after the existing password/session controls. It implements supported live reports, not the entire safety backlog.

Members can report another member, Memory or comment from existing report menus. Reports persist on the server. The same account can report an item once; retries succeed without duplicate reports/alerts. At most10 new reports per account/hour across groups. Parent membership grants no access. Unsupported event/chat/subgroup reporting remains gated. No fictional reports enter real groups.

Owners/admins open Group → Reports (also under group settings). The server-only queue offers30 targets/page, Previous/Next and Refresh; open reports and hidden targets remain visible. Reason counts, a bounded current-text summary and recent50 admin audit actions are shown. Reporter accounts, report-row IDs, optional notes and mobile numbers are excluded from all admin responses and notifications. Optional notes remain private write-side data; no platform escalation workflow is claimed. Audit identifies the acting admin only. Queue metadata is private,no-store; offset pagination is not a frozen snapshot.

Hide/restore works for Memories/comments; member removal stays in the existing Members controls, with owner protection/cascade rules. Hiding a Memory removes it from ordinary Home/group/Saved/search/detail and mutations, including for admins; already-issued signed photo URLs return404. Queue text inspection/restoration is the admin path. Restore does not resurrect deleted content/assets. Hiding a comment suppresses its entire descendant branch/counts/new replies; restoring a parent preserves independent child hides. Visibility CTEs are scoped to the current user's active exact groups and bounded at32 levels; deeper reply parents are rejected before inserting to prevent recursion failures. Author-deleted content cannot be restored through moderation. Reports on comments under a deleted Memory can be dismissed without leaving stranded hidden cases in the queue.

All actions capture API/account/session scope. Mutations recheck user/session/exact-admin under database locks, compare target version and append an audit entry atomically. New reports/actions increment version; stale/replayed requests return409 and require refresh. Dismiss affects reports, not visibility; the client offers version-checked Undo to reopen. This is not a blind last-write-wins toggle.

OpenAPI0.3.11 and migration015 add moderation_targets/reports/moderation_audit plus group.report outbox support. Contract/client/backend review checked IDs, kinds/reasons, limits, version errors, roles, hidden media/branches, response privacy and scoped UI/actions. All377 local references resolve;63 operationIds are unique.

## Notifications and remaining safety work

New reports capture a generic group.report alert for current opted-in exact admins, excluding the actor, at most once per reported target/device. Preferences use Groups and safety; sender and foreground/headless display/tap recheck opt-in, quiet hours, session and active admin access. Payload has exactly seven scoped routing fields; no content, note, reason or reporter identity. The client fetches the authorized private queue before display/open. Demotion, empty queue, logout or disabled preferences prevents presentation. Dismissed cases cancel pending delivery. No reporter-status or platform-escalation notifications are claimed.

Native delivery, Android installation and two-phone acceptance remain device tests. Global blocking, DM/profile privacy, platform escalation, subgroup/event/chat reports, account deletion/export, retention decisions and account recovery are separate batches; their server capability gates remain closed. The preview remains fictional and unchanged.

Validation and artifact/hosted evidence are recorded in PROJECT_STATE.md and docs/mobile-release-1.0.16.md. Approved Windows goldens are not regenerated on Linux.
