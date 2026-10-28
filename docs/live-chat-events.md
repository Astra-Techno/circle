# Live Chats and Events — integration record

28 October 2026. Implemented against current main; previous UI polish and floating dock retained. Source, server deployment, APK publication and device acceptance are separate facts.

## Implemented

- Chats tab with persisted exact-group conversations, direct-message requests, unread/read markers, pin/archive/mute and bounded history/contact pagination.
- Idempotent text sends and durable session-scoped encrypted pending intents; replies,15-minute edits, unsend/Undo and idempotent reactions/clear. Selected actions automatically stay in the viewport, including the existing preview forwarding row.
- Direct contact checks shared membership, recipient All/Accepted/Nobody policy and blocks. First contact requires acceptance after one introduction. Direct reporting and blocking are available without accepting a request; old history stays private to the pair.
- Events tab and exact-group event list; create/edit/cancel, type, description, place or HTTPS meeting link, UTC/IANA date/time, optional end/deadline/capacity, Going/Maybe/Can’t go, guests, private own notes and attendee pagination. Group admins can restrict event creation. Updates use versions and send ids for safe retries.
- Generic chat/event push references, current-state authorization, foreground/headless category handling and safe internal destinations. No message/event text appears in lock-screen payloads. Quiet hours, current devices/sessions, read/mute/block/privacy/membership and obsolete event versions are rechecked. One-hour reminders use the existing notification-worker cron, including late device registrations.

Backend/client contract mapping: OpenAPI0.4.0,87 unique operations/489 local references checked. Group ids resolve through /groups/{id}/chat; clients never substitute group ids for conversation ids. Event bodies and UTC formatting match the contract. Frontend request/session scopes and backend authorization/version/locking boundaries reviewed together.

## Private direct-message report review

Only an authorized server operator with private database access runs:

```sh
php src/Core/direct_reports.php
php src/Core/direct_reports.php details REPORT_ID
php src/Core/direct_reports.php reviewed REPORT_ID
```

The default list contains report ids/reasons/times only. Details contain personal data: never copy to public logs. Direct report records are not exposed to shared-group admins or through HTTP; the script exits404 outside CLI. The UI promises private saved review, not an invented safety-team response time. Group-member reports continue through the existing group-admin queue. Case review, staffing, legal retention and platform escalation policy are operational responsibilities, not automated by this feature.

## Explicit capability limits

Chat transport is foreground polling, not WebSocket or E2E. Notifications are optional and can be delayed by worker cadence, quiet hours and device/provider conditions. The pending-send queue retries only while Chats is active; permanent rejections wait for review. Names/roles remain subject to existing shared-group rules. Photo attachments and event covers are implemented in the build20 source extension below. Video/general document attachments, content forwarding/sharing, activity indicators, chat search, date polls, cohosts and event albums need subsequent service extensions and stay out of the live screens. The corresponding existing rich preview UI remains fictional.

## Validation and publication

Full integration: backend214 tests/3,832 assertions pass; final focused41 tests/961 assertions and PHPStan/composer validation clean. Flutter705 passed/1 skipped/13 known Windows golden failures, with26 final focused tests passing. Analyzer/format and design guard clean. Twelve light/dark phone/tablet200% renders captured and representative layouts inspected. No golden baseline regenerated. Actual source/deployment state is recorded in PROJECT_STATE.md. No Android device is attached: two-phone consent, blocks, frozen history, offline/restart send recovery, actual push/taps and event reminders remain acceptance checks.

Source implementation commit17d1156 is pushed to main. The working checkout is /workspace/circle; no production deployment was triggered. This source batch does not replace a published APK. Current repository artifact is1.0.18+19,65,277,758 bytes, SHA2563c844920fe94fd0f5a17efc5e6bb13c8dc42f9d1760d7efdf50e36cef4d24506. Its certificate SHA256e38a9bf147b621ee468a1abdda916239663810346aa9f104c956e089bbebbf61 differs from earlier build18. The refreshed environment lacks Android SDK and that signing key; an update-compatible APK requires restoring the installed app's matching key, never generating a replacement. No signing files were added to Git.


## Build20 photo extension

OpenAPI0.4.1/migration021 adds private photo attachments and event covers. Chats accept up to four JPEG/PNG/WebP photos with optional caption/reply. Each staged UUID belongs to its uploader and exact conversation and can attach to only one message; identical send retries preserve the same immutable attachment IDs. Direct photos require an accepted request. Photos follow the viewer's frozen version cutoff, unsend/Undo and normal pair history rules; no public image URLs, original metadata or storage paths are returned. Private operator report details include only the selected message's photo IDs.

Uploads are bounded to5MiB,2048pixels per side/4194304pixels and60/account/hour. Content sniffing, decoding and re-encoding strip original metadata. Session/authorization are rechecked after processing. Access failures leave no newly stored files. The existing hourly `composer media:cleanup` removes staged/replaced orphan photos after24h; pending photo intents older than that need reselecting if expired. Offline queueing retains already-uploaded IDs, not raw photos; initial upload needs a connection. The private inline viewer expands/zooms and removes its bytes from the UI when authorization changes.

Event detail provides add/change/remove cover for the organizer or exact-group admin; current members see covers in lists/detail. Cover edits require the current event version, increment it and replace obsolete notification/reminder references. Cancelled events cannot be edited. Earlier event covers become inaccessible immediately and are reclaimed by the same cleanup cron.

Owner approved generating a new dedicated release key on28October2026, accepting a one-time uninstall that clears local app data. Server account/group/Memory data remains. The key and passwords are kept outside Git; the owner must save the private signing backup for future upgrades. Release signing no longer silently falls back to a newly generated debug key.
