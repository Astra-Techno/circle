# Live API validation — 26 October 2026

Latest result: GD is enabled and the photo workflow passed 25/25 checks, including cleanup. The first table below records the earlier run before hosting enabled GD; the successful retest is recorded at the end.

Server: https://circle.cloudkart24.com/api/v1. PHP 8.3.36 and Argon2id are available. Fictional data only; no existing user data was accessed or changed.

| Area | Result |
|---|---|
| Registration and login | Passed for three fictional accounts |
| Profiles | Read and Unicode update passed |
| Groups and subgroups | Create, list, read, update, leave and ownership transfer passed |
| Membership | List, promote, demote, remove, ban and unban passed |
| Invite links | Create, list, preview, join, revoke and reset passed |
| Join approvals | Request, list, decline and approve passed |
| Group privacy | Nonmember access and child-group isolation correctly denied |
| Memories | Create, list, read, update and delete passed |
| Comments, reactions and saves | Passed |
| Sessions | Refresh rotation, logout and rejection of logged-out sessions passed |
| Photo upload ticket | Failed with HTTP 503: GD image processor unavailable |
| Photo bytes, signed links/download, media discard | Successful workflows blocked by upload prerequisite |

The initial test sequence reused old invites after removal, which the API intentionally rejects. Fresh invites were created and all 33 follow-up checks passed. Those initial dependency failures are not counted as application defects.

Cleanup: test Memories deleted, test invitation links revoked, sessions logged out, and the original test owner left after ownership transfer. Three fictional accounts and two labelled fictional groups remain because the implemented API has no account/group deletion operation. No media upload was created because the processor check failed before ticket creation.

Remaining action: enable GD for the PHP 8.3 web runtime, including JPEG/PNG/WebP decoding and WebP encoding, then retest all five media operations. An APK rebuild is not needed for this server configuration change.

## Follow-up checks

| Check | HTTP | Result |
|---|---|---|
|Login Owner|200|Passed|
|Login Member|200|Passed|
|Login Visitor|200|Passed|
|Create fresh post-removal invite|201|Passed|
|Rejoin with new invite Member|200|Passed|
|Rejoin with new invite Visitor|200|Passed|
|Create fresh child invite|201|Passed|
|Rejoin subgroup after cascade|200|Passed|
|Leave group|200|Passed|
|Create Memory|201|Passed|
|Read Memory as member|200|Passed|
|Comment as member|201|Passed|
|React as member|200|Passed|
|Remove reaction as member|200|Passed|
|Save Memory as member|200|Passed|
|Unsave Memory as member|200|Passed|
|Delete test Memory|200|Passed|
|Deleted Memory inaccessible|404|Passed|
|Transfer child ownership|200|Passed|
|Transfer root ownership|200|Passed|
|Mark test root complete|200|Passed|
|Mark test child complete|200|Passed|
|List links for cleanup|200|Passed|
|Revoke test invite for cleanup|200|Passed|
|Revoke test invite for cleanup|200|Passed|
|List links for cleanup|200|Passed|
|Revoke test invite for cleanup|200|Passed|
|Revoke test invite for cleanup|200|Passed|
|Leave after ownership transfer|200|Passed|
|Logout Owner|200|Passed|
|Logout Member|200|Passed|
|Logout Visitor|200|Passed|
|Revoked session denied|401|Passed|

## GD enabled — live media retest

After hosting enabled GD on PHP 8.3, all **25 live media checks passed** using an existing fictional test account and group. No new accounts or groups were created.

- Uploaded a generated 2400 × 1200 PNG with a fictional metadata marker.
- Server returned WebP variants: thumb 320 × 160, medium 1080 × 540 and full 2048 × 1024. The marker was absent from all downloaded variants.
- Signed link creation and downloads passed for all three sizes; unauthenticated link requests returned 401.
- Attaching the image to a fictional Memory, reading it, and deleting it passed. The media and an already-issued signed URL returned 404 after deletion.
- A second unattached image uploaded and discarded successfully, then returned 404.
- All newly created Memories/uploads were cleaned up and the fictional account session was logged out.

Evidence: `/tmp/circle-live-api-check/media-results.json` (25/25 checks passed). This verifies the live PNG-to-WebP workflow, resizing and metadata marker removal; it does not substitute for physical Android camera/gallery validation.
