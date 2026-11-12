# November 12 integration and data fixes

This batch addresses the source-backed findings in [the recent review](recent-changes-review-2026-11-12.md). Candidate source is **1.0.39+45**, continuing Social 2.6. Existing production deployment, Android 43 and accepted iOS 1.0.38 are separate from this candidate.

## Implemented

- Search excludes hidden or missing poll Memory/Event contexts, escapes literal wildcard characters correctly, and pages each category with deterministic ordering. Flutter uses the scoped cross-category API with debounce, retry, pagination and actual detail routes.
- Album additions require ready, nondeleted, nonhidden media already attached to an active Memory in the exact Circle. Covers must belong to the album. Listing, photos, counts and covers recheck visibility; cover checks stay inside the listing query. Repeated additions return the existing photo ID under an album row lock. Removing an album preserves original Memories/media.
- Authenticated Albums use the real API, private media IDs and a picker of already-shared Circle photos. New uploads remain in the Memory flow. Fictional scene selection is excluded from signed-in creation/addition. Existing cover/caption/delete actions use server operations; photo Undo re-adds the shared media/caption, under the account performing Undo.
- Capsule messages now retain actual contribution text, author and time. Local mutations serialize, storage failures propagate, corrupt records are not replaced with empty data, and account/server storage scope follows repository/provider dependencies. The original deployment can adopt legacy records while retaining the old recovery copy. Previously discarded text cannot be recovered from counts.
- New Capsules use authenticated server storage; legacy device records remain on their original device and are not silently uploaded or discarded. Absolute UTC unlock dates are accepted alongside the older `unlock_days` API. The server checks entry/contributor limits under the Capsule row lock, hides sealed opening messages, and supplies actual detail counts. Entry reads require server unlock; the client uses the server's unlock state. Automatic publication, photo contributions and unlock notifications are not claimed.
- Activity captures new Memories and comments inside their mutation transaction, independently of push settings/devices. Reads and unread counts recheck recipient, membership, resource visibility, actor status and mutual blocks. Flutter has real paging, mark-read, refresh-on-open/pull-to-refresh, loading/error handling and scoped session checks. This batch does not invent historical entries or additional event producers.
- Comment deletion is connected. Undo is restricted to the removing account, with active Memory/membership checks. Moderation clears Undo ownership; legacy moderated comments cannot be restored through this endpoint. Descendants remain visible.
- Restored TLS verification in the synthetic persona runner; fixed the extra-header argument and PHPStan types. The runner accepts only a loopback target with explicit `DB_DATABASE=circle_test`; dry run sends no requests, unsupported cleanup stops, and private state writes are atomic, mode0600 and ignored by Git. This script was not run to create accounts/data.
- Saved regression: the test disables repeating shimmer while retaining data/navigation assertions. The dock now bypasses AnimatedSize entirely with reduced motion, fixing the newly exposed layout assertion. New network providers do not automatically retry errors forever.
- Removed the website's broken placeholder policy links, following the existing design rule. This is not a substitute for actual legal policies.

## Contract and deployment

OpenAPI **0.4.8** now describes all 20 new operations, including comment restoration, with requests, paging, responses, errors and access rules. The client mappings and backend semantics were checked together; this is not a claim of independent human review. Internal references resolve and operation IDs are unique.

Run the existing hosting deployer after this batch is pushed. It must copy current backend source and apply all pending migrations, including026–029 if absent and new **030_comment_restore_actor.sql**. Do not manually mark missing migrations as applied. Migration030 adds nullable comment removal ownership; existing hidden comments have no Undo owner. No production deployment or live database inspection has been performed here.

## Verification so far

- Full backend: **287 tests / 5221 assertions passed**, dedicated `circle_test` only. PHPStan clean without suppressions. Final read-header/order changes:42 focused tests/462 assertions pass.
- Flutter format, analyzer, bundled-font checks and iOS script checks pass (20 script tests, one existing skip).
- Focused mobile sets:34 pass (new adapters/persistence/Saved/session),25 pass (comment Undo/debounce/Circle recovery),31 pass (Activity/capabilities/search recovery/adapters).
- Broad comparison identified22 Linux/Windows golden differences and seven stale capability/search expectations; those expectations were updated to exercise implemented behavior, with the affected focused sets passing. Final complete non-golden run:817 pass/one existing real-HTTP smoke skip. Subsequent account-isolation(5 tests) and authenticated comment-adapter(13 tests) sets pass, including two new checks. Windows baseline review/comparison remains pending; no all-green release claim yet.

## Remaining release gates

Windows image review and normal comparison must pass before building/publishing. No candidate APK/IPA is published by this document. This restored workspace has no Android signing keystore; retain/restore the existing Android39+ identity rather than generating a replacement. Hosting is unavailable in this environment; staging/live migrations and two-account physical-device acceptance remain owner/operator checks.

Public launch remains blocked by account-deletion, recovery/export and real privacy/community/support policy work. Public operator/support details and the recovery provider have been requested; no provider, retention promise, legal identity or successful SMS delivery is invented.
