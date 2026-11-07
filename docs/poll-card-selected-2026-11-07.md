# Shared live poll cards — 7 November 2026

Owner selected the third generated poll concept and requested it as a card in all listings, then removed the Choose one / Names visible instruction line. LivePollCard implements flat white ballot rows, fine separators, regular labels, radio/checkbox controls, lavender selection, real counts and a clear explicit vote button. Counts stack at large text. Empty progress bars are omitted; visible nonzero results retain compact progress. A small privacy note remains below the button. Existing anonymous/hidden results, multiple selection, vote retraction/change locks, closing, adding options and scoped voter lists are retained.

The same card now renders in Poll detail/list and the shared Memory card used by Home, Circle, own/other Profile, Saved, Search and Memory detail. Embedded cards avoid repeating the outer Memory audience/caption. Six integration tests verify inline voting on Home/Circle/Profile/Saved/detail/Polls, with zero initial per-card GET /polls/:id calls. New creation refreshes the workspace and scoped lists; successful votes/close/options refresh the associated Memory. Session-bound snapshots synchronize visible ballots and are discarded on a fresh server payload. Pending menu actions keep their original API scope.

## Backend and deployment

Migration `024_poll_memory_cards.sql` creates a unique nullable publication identity, then backfills standalone polls into real Memories with original group, creator and timestamp. Existing Memory links are preserved. New standalone poll creation publishes/links one Memory in the same transaction; original request hashes/idempotency protect retries. This preserves chronological keyset pagination, Profile authorship, search, save/comment/reaction behavior and exact-group privacy through existing endpoints. Hidden/removed Memory contexts stay inaccessible and are not republished.

GET /memories and detail now include a `polls` array containing the existing caller-projected poll payloads. Page projection reuses batched option/vote/totals queries; one versus ten Memory cards has bounded query count. Results and voter counts remain absent/null according to the original rules, and anonymous voter identities remain forbidden. Contract0.4.6 records the additive field/publication behavior. Backend review covered transaction/idempotency, scoping, migration/backfill and visibility; client review covered typed Memory translation, shared rendering, pagination, freshness and guarded writes. No independent external review claimed.

Run the existing backend deployment script so migration024 and updated PHP are installed, then install a new app build. Neither live deployment nor native-device acceptance is verified in this environment. Previous latest migration023 is not sufficient for this feature. No deployment secrets belong in chat.

## Validation

- Backend full suite240tests/4497assertions passes; PHPStan clean512MB. Final focused Poll suite9tests/305assertions passes, including the additional bounded Memory-page checks.
- Final mobile integration/poll/layout/design/provider checks26passed; freshness-only12passed. Format and analyzer checks recorded separately. Windows [42332187248](https://github.com/Astra-Techno/circle/actions/runs/42332187248) passed812tests/1skipped, font/format/analyzer clean. All22generated baselines are pixel-identical to the reviewed repository images, so none were replaced. This was update-goldens with explicit pixel comparison, not a separate normal comparison run. Format254files clean.
- Fictional renders cover six listing surfaces, normal selection, narrow/tablet200% text and dark/light. Selected source and comparison are in `design-previews/poll-card-selected-2026-11-07/`.
