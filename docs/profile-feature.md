# Profile photos and personal details

This increment adds a personal cover/banner, an overlapping profile picture and an editor for name, bio, current city, hometown, work and education. It extends the signed-in profile; it does not create public profiles, public image URLs, a Facebook-style public timeline or a mobile-number-change flow.

## Visibility

| Information | Who can read it |
|---|---|
| Display name and bio | The owner and existing group-member views, as before |
| Profile and cover photos | The owner, or another active account that shares at least one active exact group membership with the owner |
| Current city, hometown, work, education and mobile number | The owner through `/me` only |

A parent/child relationship between two different groups is not enough to share a profile photo: both people must be active members of the same exact group. A missing photo, inaccessible account and nonmember photo request return the same 404 response. Authentication and membership are checked on every new byte request. The photos are account identity images, deliberately separate from Memories, whose media stays private to the exact group in which it was posted.

The edit UI must explain the visibility split before a person adds information or uploads a photo. Mobile numbers remain read-only under ADR 0005; number changes require a reviewed verification design. Optional personal fields can be cleared without changing other fields. Registration and group membership behavior do not change.

## Storage and image processing

Owner uploads use `PUT /me/photos/avatar` or `PUT /me/photos/cover`, with raw JPEG, PNG or WebP bytes. Each upload is limited to 5 MiB, 2,048 pixels per edge and 4,194,304 pixels in total. MIME declarations are checked against real content, dimensions and successful decoding. The existing server processor re-encodes the image and drops metadata rather than keeping the original. Thumbnail, medium and full variants are private objects at random keys; filesystem paths never leave the server.

A successful replacement switches the profile record to a new opaque version and then removes the old object prefix. Failed validation, staging, processing or database updates preserve the previous photo. Avatar and cover are independent: removing one does not remove the other. Authenticated image responses use `private, no-store` and safe image headers. Client-side fetching remains in service/provider code, with no `Image.network` or HTTP in widgets. In-memory photo state is scoped to the account and API server, and must not survive an account switch or logout.

## Acceptance checks

- Own profile reads and updates persist Unicode text, enforce type/length limits, clear optional fields and retain unchanged fields.
- Other users cannot retrieve the new private fields through group/member/Memory responses.
- Both photo kinds support upload, replacement, all three image sizes and deletion; invalid kinds/sizes, unsupported content, excessive dimensions/bytes and processor failure are handled without overwriting the existing image.
- Unauthenticated, unrelated-account, inactive-account and removed-member requests cannot fetch profile photos. Sharing only a parent/child ancestry grants no access.
- Real image re-encoding removes a fictional metadata marker and returns decodable variants; storage paths and originals remain private.
- Byte-request authentication refresh, stale async completions, rapid saves, account changes, cancellation, upload failures and retry are covered by focused client checks.
- Render narrow and tablet widths, light/dark mode, empty photos and long names at 200% text; preserve the audience explanation and labelled edit/remove actions.

Implementation and test execution results are recorded in the release notes. Widget tests and server checks do not establish physical-device photo-picker validation or Windows golden approval.
