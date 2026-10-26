# Pending work and release scope

Updated: 26 October 2026. This is the current execution backlog for Claude and Codex. Product scope remains in README; historical audit evidence remains in implementation-roadmap.md. Status must be rechecked against Git and the live server before implementation. “Planned” does not mean implemented or authorized as a finished release.

## Next batch: stable core and complete profiles

Finish this batch before adding another live feature family. Keep existing auth, groups, Memories and photos working. Full push delivery may stay disabled until its later acceptance checks pass.

| ID | Work | Current status | Completion criteria |
|---|---|---|---|
| B1 | Preserve and integrate concurrent work | Integrated in the main-only source checkout; original primary WIP and a separate snapshot are preserved. Profile migration is 008; device migration remains 007 | Reconcile routes/session notifier without losing either workstream; retain account/server guards and serialized mutations; use distinct new migration numbers; update reviewed contracts. No automatic stash or discarded edits. |
| B2 | Restore truthful server capabilities | Corrected in the integration checkpoint: unavailable families are gated until implemented; Chats and Events remain required next-family deliveries | Unsupported chat/events/albums/moderation/privacy controls remain gated; real user data never enters mocks; availability tests pass. |
| B3 | Make Firebase optional and safe | Core regressions fixed: push cannot block auth/startup and private-content logs removed; full scoped delivery/listener/registration work remains | Missing config/SDK/permission/network errors cannot block startup, login, restore or logout; no private-content logs; scoped/idempotent listeners and registration; static analysis and auth regressions pass. This does not require enabling push. Current checkpoint keeps push delivery disabled; see docs/integration-checkpoint.md. |
| B4 | Complete profile feature | Profile API/UI integrated; 134 backend tests, 7 client tests and photo lifecycle widget coverage pass. Visual matrix/native picker and live verification remain | Cover/banner and profile image add/replace/remove; persistent name/bio/city/hometown/work/education; cancellation and failed saves preserve data; loading/retry and narrow/large-text layouts verified. |
| B5 | Correct release identity and publication | Changed signing certificate, reused build7 and inconsistent artifacts in recent remote commits | Established beta signing key, a new build number and immutable filename; matching stable/versioned APK, metadata and site links; hosted checksum and Android update path verified. Never overwrite an immutable release. |

B4 privacy: name/bio follow existing group visibility; profile/cover photos require authenticated ownership or a current exact shared-group membership. City, hometown, work, education and mobile number are owner-only. Mobile-number changes are excluded until verification is designed. Profile files are privately stored and re-encoded; no public photo URLs or originals. Manual photo crop/reposition is a later enhancement, not a hidden requirement of this batch.

Batch exit: required format/analyzer/backend/static and functional checks pass; fictional live API checks clean up fixtures; sign/package/deploy only the verified candidate. Record Windows golden and physical-device results separately. A source push is not deployment evidence. Build one APK after integration unless the owner explicitly requests an intermediate build.

## Next feature families, in order — owner approved execution

The owner approved sequential completion of this backlog, restoration of Chats and Events, and notification coverage across every feature. Each family gets a small reviewed contract, implementation and acceptance batch; no blanket “enable all” change. Chats and Events are required product features, not permanently removed screens. Restore Home · Chats · Groups · Events · You as each real service passes its acceptance checks; never expose a preview as live data.

| Order | Family | Required behavior / exit criteria | Dependencies or decisions |
|---|---|---|---|
| 1 | Real push notifications | Actual eligible events dispatch; persisted preferences/quiet hours; foreground display; safe tap navigation; account-switch/offline logout handling; invalid-token cleanup; real-device background/terminated tests | B3; server Firebase credentials/curl confirmed privately; device access; iOS configuration before claiming iOS support. Start with supported Memory/invitation events. |
| 2 | Safety, privacy and account controls | Reports reach authorized admins; block/privacy rules enforced server-side; secure password change; reviewed account export/deletion and retention | Reviewed contracts and owner decisions on retention/legal content. Recovery, OTP and number changes need ownership verification/provider; no reset bypass. Required before broad public onboarding. |
| 3 | Live chat | Start with group text conversations, persisted history, unread counts, retry/idempotency and message push; then replies, attachments and consent-based 1:1 delivery. Enforce exact membership/privacy and the existing ADR 0003 frozen-history rules after removal | Safety foundation, delivery/transport choice and push integration; preview conversations do not migrate as real data. |
| 4 | Live events and RSVPs | Start with group event cover, description, location, time zone/date/time and Going/Maybe/Can’t go; create/edit/cancel permissions, push updates and scheduled reminders. Then guests/capacity and event albums | Reviewed API, scheduler and notifications. |
| 5 | Live polls | Memory/chat/event container permissions, named/anonymous votes, results visibility, closure and safe repeat requests | Container APIs must exist; deliver supported containers incrementally. |
| 6 | Live albums | Exact-group private photos, create/edit permissions, covers/captions, pagination and cleanup | Existing media lifecycle plus reviewed album API; event albums after event integration. |

## Cross-feature notification delivery — required in each family

“Every feature” means relevant recipient-facing actions, not a push for every tap, private edit or read. Implement the shared delivery foundation first, then add each feature's events with that feature. Maintain one reviewed event/recipient matrix and test it with the API contract.

| Feature | Notification scope |
|---|---|
| Groups and invitations | Direct invitation, join-request decisions, authorized admin approval requests, role/access changes; no child-group content leaked to parent members. |
| Memories | New Memory under the recipient's group preferences; comments/replies and reactions to relevant participants, aggregated to avoid spam; no actor self-notifications. Saving/searching does not notify others. |
| Profiles and account | Security/account changes only where useful and supported; private bio/photo edits do not broadcast. Do not reveal owner-only fields. Security communication cannot depend solely on the device being changed. |
| Chats | Eligible new group/direct messages with per-conversation mute, deduplication, unread reconciliation and privacy-safe lock-screen previews; no blocked or removed recipients. |
| Events | Invitations, relevant RSVP updates for organizers, material edits/cancellation and timezone-correct reminders; cancel obsolete reminders after changes. |
| Polls | Eligible new polls, closing reminders and available results under container preferences; preserve anonymous-vote privacy and avoid a push for every vote. |
| Albums | New album/relevant photo additions with batching; exact-group media permissions and safe deep links. |
| Safety and operations | Report/status notifications only to authorized participants/admins; protect reporter identity. No push for appearance, offline reads or routine background maintenance. |

Shared acceptance: transactional persisted delivery/outbox with retry and idempotency; recheck recipient access/preferences at send time; persisted category/group/conversation mute and quiet hours; foreground/background/terminated behavior; authorized tap destinations and deleted-content fallback; account/server-scoped tokens, logout/account switching and confirmed-invalid-token cleanup; no private payload logs. Device permission refusal never blocks features. Use minimal lock-screen content by default and deduplicate across delivery retries. Scheduled jobs and private server credentials must be verified before claiming delivery works. Each batch records mocked provider tests separately from real-device results; unsupported iOS configuration remains explicit. No promise of push for events that do not yet exist.

## Core improvements retained in the backlog

| ID | Work | Acceptance |
|---|---|---|
| C1 | Home group selector and compact group detail | Searchable full paths and duplicate-name disambiguation; compact ancestry/header; usable with many groups and 200% text. |
| C2 | Offline reading and durable upload recovery | Account/server-scoped cache; clear stale/access-lost state; interrupted photo uploads retry safely after restart. Existing text drafts do not establish background uploads. |
| C3 | Startup/member scalability | Load summaries before all member/settings data; explicit member pagination; no silent completeness claim at 2,000 members; measure request count and first-content latency. |
| C4 | Delete/Undo across process death | Reproduce kill during Undo; agree durable-operation or rollback behavior; no unexplained resurrection/duplicate deletion. |
| C5 | Accessibility, Tamil and visual validation | Licensed Tamil fallback, agreed translations, TalkBack/focus/contrast/reduced motion, large text; Windows golden approval and representative low-end Android frame measurements. |
| C6 | Verified invitation links and sharing | HTTPS app/site associations, browser fallback, native share entry, signed-out return and explicit join/approval verified on a device. Existing custom-link widget tests are not verification of these. |
| C7 | Remaining smaller account/group operations | Reviewed direct-invitation consent and listed-subgroup joins; comment edit/delete permissions; expanded member profile visibility only when explicitly implemented. |
| C8 | Legal and operational readiness | Approved privacy/community documents, support path, backups/restore, media orphan cleanup, redacted monitoring and retention. Do not publish invented policies or inactive links. |

C1–C8 can be selected as focused follow-ups when needed; they must not silently expand B1–B5 or delay a verified core fix without a concrete dependency.

## Already delivered; preserve and regression-test

Accounts/groups/membership/invite links; Memory create/read/edit/delete, comments/reactions/saves; private Memory upload/resizing/signed reads; independent group/Saved/search queries; persistent appearance and scoped text drafts; original brand, soft-depth theme, compact Home, invitation summary and large-text create footer. These have historical test/release evidence; current regressions still need fixing. ZIP/GD were previously confirmed on the hosting web runtime, not an outstanding library request.

## Execution discipline

Take one batch and 3–5 observable acceptance checks at a time. Read only relevant files/contracts; use one agent by default. Keep the short PROJECT_STATE.md handoff current. Run focused checks during edits, required broader checks at integration, and one verified release build. Report implemented/tested/deployed/device-verified states separately.

Open decisions are deferred to the batch that needs them: recovery/SMS provider and number verification; deletion/export retention and policy text; chat transport/history rules; native test access and iOS credentials. Never fill these with pretend services or bypasses. This document sets the recommended work order; it does not claim the larger families are finished.
