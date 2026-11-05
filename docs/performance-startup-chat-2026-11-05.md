# Startup, photo and chat performance — 5 November 2026

Source version1.0.30+35; Account interface Social1.5.

## Changes

- Workspace hydration requests groups and Memories concurrently. Each group's members and settings also load concurrently; the workspace is still exposed only after authorization, roles and reaction state finish loading. Existing concurrency limits on group hydration remain.
- Preview photos use thumb/medium variants rather than full2048px renditions on high-DPI screens. Decode widths are bounded to1080px and bucketed for cache reuse; expanded viewers retain full resolution and zoom. Signed URL checks remain intact.
- Small group avatars reuse the existing45-second/64-entry session-scoped in-memory LRU. Membership and photo version are checked before cache access; covers are not retained by this cache. No private-photo disk cache added.
- Opening Chats with an empty outbox no longer invalidates and restarts its initial request. Periodic refresh, resume refresh and retrying queued sends remain supported.
- Conversation reactions and attachments use at most two batched metadata reads for the visible page instead of two queries per message. Frozen former-member snapshots and removed-message behavior remain unchanged.
- Inbox candidate conversations are selected through the viewer's memberships/direct pairs, and unread counts are calculated only after page selection. Existing indexes support these lookups.
- Memory list recursive comment visibility/counting is restricted to returned page IDs instead of traversing comments across the accessible workspace before pagination.

## Verification

Complete backend suite:234 tests/4275 assertions pass against circle_test. PHPStan level6 clean. The regression measurement reads MySQL Com_select around authenticated conversation requests:1-message page10 SELECTs;50-message page10 SELECTs. This verifies bounded query count, not production response-time or device cold-start timing.

Focused mobile checks:67 tests pass, covering request overlap, single-request chat entry, preview/full rendition selection, media access, avatar reuse/revocation and repository/design behavior. Dart format and Flutter analysis clean. Full Windows comparisons and signed TestFlight build follow the commit. No API response schema changes or database migration required.

## Deployment

backend/deploy/deploy.php downloads main, copies backend/src and database files, runs pending migrations and rebuilds the classmap. Run the existing configured deployment link after pulling this commit to activate the PHP query optimizations. These changes do not need a new SQL migration file; the optimized SQL is in ChatController.php and MemoryController.php. Keep hosted .env/private storage unchanged. Repository changes and tests do not establish live deployment or measured production timings.

Install the new mobile build for concurrent startup, preview/decode and initial-chat-request improvements. Android signing credentials remain absent from this workspace; existing download publication stays unchanged.
