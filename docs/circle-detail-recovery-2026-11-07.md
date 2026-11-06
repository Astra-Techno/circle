# Circle detail loading and actions — 7 November 2026

Owner approved fixing the screenshot audit findings. Safely pulled main and preserved upstream a232a08 header alignment. Updated its old tonal-header expectation to match that upstream design rather than reverting it.

## Fixes

- Circle shortcuts now use a balanced adaptive grid (up to3columns, fewer at large text). Width measurement uses the actual14px shortcut font, the system Bold Text weight, current text scale and rounding allowance. Memory/Settings remain whole words, with48px targets. Existing six routes, permissions and capability gates stay intact.
- Removed the permanent photo-refresh icon and avatar camera overlay. Admins get one Edit Circle photos menu with Circle photo/Cover photo entries and the existing choose/replace/remove flow. It remains accessible when large text hides the cover. Capture/check the account, API, session, group and admin role before and after modal steps; stale permissions cannot upload.
- Cover HTTP and image-decode failures share one labeled Retry state with no type icon overlapping the message. Retry invalidates only that cover provider. Pull-to-refresh still discovers changed photo versions. Explicit refresh shows loading rather than retaining a stale error.
- Workspace and scoped Memories providers no longer silently invoke Riverpod default retry(up to10attempts). Failed reads expose errors until an explicit user retry/refresh. Scoped Memories renders safe CircleFailure/ApiError wording instead of calling every failure a connection problem. Normal token refresh and session/access guards are unchanged.

## Verification

The initial focused run passed40checks after fixing old photo-control locators; final recovery/photo/provider/design run passed25checks. Separate provider tests demonstrate default containers keep failed workspace/timeline reads in error without a second request after300ms; explicit timeline retry makes the second request. New simulated503 checks verify one cover request and one scoped Memories request even after15s, then separate explicit retries recover each. Corrupt image bytes recover after waiting for the replacement image frame. Revoking admin permission while the first photo menu is open prevents proceeding/uploading. Four bold/normal/scaled phone/tablet cases verify full labels and48px targets. Five Flutter renders reviewed; no device acceptance claimed. Format253lib/test files clean; analyzer clean. Windows full verification and visual baselines completing.

[Bold Text](design-previews/circle-recovery-2026-11-07/circle-actions-393-1.0-bold-true.png), [320px/200%](design-previews/circle-recovery-2026-11-07/circle-actions-320-2.0-bold-true.png), [independent failed reads](design-previews/circle-recovery-2026-11-07/circle-loading-error-393-light.png).

## Live delivery limits

Client rebuild required. No backend or SQL changes in this batch. Previous server request-budget fix3eaf891 is already on main and is activated through the existing backend deployment script without a new migration. Its live deployment and the actual production status/error remain unverified: current environment policy excludes circle.cloudkart24.com and no production credentials are configured. Mock failures/recovery prove client behavior, not live server health. The owner's screenshot shows the icon-only footer, but the installed build number has not been identified.
