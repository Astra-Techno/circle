# Private group pictures and banners

27 October 2026. Owners/admins can open a group and add, replace or remove its picture and banner independently. Existing members see them in group details; group pictures also appear in the group list, group search and groups in common. Missing photos keep the existing group-type icon. Refresh group photos fetches current metadata and retries private bytes without signing out. Person avatars in Memories/member lists from build15 remain included.

## Authorization and storage

OpenAPI0.3.10 defines GET/PUT/DELETE `/groups/{id}/photos/{kind}`, with avatar/cover kinds and private binary reads. Only active exact members can read; parent membership, discovery and invite previews do not grant access. Only current exact admins may mutate; owner has admin permission. No public paths/URLs or contact data are exposed. Group index/detail metadata includes opaque versions only for authorized groups. Reads share the bounded photo quota, separate from general API requests.

Migration014 creates group_photos. Uploads reuse the existing image inspector, processor and private storage: JPEG/PNG/WebP, at most5MiB/2048px per side/4,194,304pixels, re-encoded into320/1080/2048 variants with originals/metadata stripped. Versions change on replacement; failed processing retains the previous image. Staged files are purged if permission/session is lost before commit. Group/user/session/membership are rechecked under locks. Replacement/removal purges only the chosen old image. Routine photo changes do not trigger unsolicited push notifications.

The client captures API/account/session/group scope before the sheet/picker; it rechecks admin permission after selection and before upload, and binds the HTTP request to that session. Reads also reject late bytes after membership/version/session changes. Private bytes stay in session-scoped provider memory; no public network-image URL or disk cache. Existing native image picker is reused; no additional Android permissions/dependency.

## Validation and release

Backend full dedicated circle_test:196 tests/3,286 assertions; PHPStan clean. Includes owner/member/stranger/parent-only/promoted/removed/logged-out cases, independent replacement/removal, invalid uploads, unavailable/failing processor and permission loss during processing preserving old files.

Client focused photo/design20 tests pass; final full Flutter659 passed/1 skipped/13 known Windows-baseline golden failures, with no functional failures. Analyzer/format clean. Artifact/hosting results are recorded in PROJECT_STATE.md and the build16 release record. Phone/tablet light/dark at200% text renders checked without overflow; approved Windows goldens unchanged. Native picker, Android installation and two-phone visibility remain owner acceptance.

Frontend/backend contract review: binary methods, kinds, sizes, roles, session guards, optional versions, error responses and private storage boundaries cross-checked against controllers, API client, mapper, providers and widgets. All361 local OpenAPI references resolve;60 operationIds unique.
