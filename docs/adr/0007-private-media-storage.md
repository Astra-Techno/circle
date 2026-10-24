# ADR 0007: private media storage and retrieval

Status: accepted by the owner, 23 Oct 2026. **Implemented in `backend/`** (contract 0.3.1). Real image processing needs the GD extension (`sudo apt install php8.3-gd`); without it, uploads fail closed with 503.

## Decision

Photos (and, later, videos) are **private to the exact group they were shared in**. They are never reachable through public or guessable URLs.

### Upload
1. **The app prepares the photo.** It asks for photo access only when the person taps *Add photos*. It downsizes to at most 2048 px on the long edge and compresses (JPEG/WebP, about 80% quality) before sending, to save data on slow networks.
2. **The app asks for an upload ticket** (`POST /groups/{id}/media/uploads`) with the type, size, SHA-256 and a client upload id (for idempotency). The server checks active membership of that exact group, the type allowlist, size and count limits, and the per-user rate limit. It returns a short-lived upload ticket.
3. **The app sends the bytes** (`PUT /media/uploads/{uploadId}/content`). The server then:
   - checks the **real content**, not the file name: magic bytes, decodable image, dimensions;
   - **re-encodes** the image, which removes all metadata, including GPS/EXIF location, and anything hidden in the file;
   - converts HEIC to a web-safe format;
   - generates three sizes: `thumb` (≈ 320 px), `medium` (≈ 1080 px) and `full` (≤ 2048 px);
   - marks the asset `ready`.
4. **The app attaches the asset.** It creates the Memory, album photo or chat message with the returned media ids. An asset can only be attached inside the group it was uploaded to.
5. **Unattached uploads** are deleted automatically after 24 hours.

### Storage
- **Interface:** a `MediaStorage` interface in the backend (Task → Entity → SQL style) with two implementations:
  - `LocalDiskStorage`: a folder **outside the web root**, for development and version 1;
  - `S3CompatibleStorage`: AWS S3, Cloudflare R2 or self-hosted MinIO, later.

  Switching between them needs no app change.
- **Object keys** are random and unguessable: `media/{group_id}/{uuid}/{size}.webp`. The bucket or folder is never public.
- **Database:** a new `media_assets` table with id (UUID), group_id, uploader_id, storage_key, kind, mime_type, byte_size, width, height, sha256, status (`pending` / `ready` / `failed` / `deleted`), created_at and attached_at.
  - Memories, albums and chat messages reference assets by id.
  - The existing `memory_media.storage_path` design is replaced, so storage paths never leave the server.
- **Limits:**
  - types: JPEG, PNG, WebP, HEIC;
  - 15 MB per upload before processing;
  - 10 photos per Memory, 50 per album, 10 per album pick;
  - per-user and per-group quotas to be set before beta.

### Retrieval
1. **The app gets media ids, never file URLs.**
2. **The app asks for a link:** `GET /media/{mediaId}?size=thumb|medium|full`. The server re-checks **on every request**:
   - active membership of the asset's exact group, never inherited;
   - for chat attachments, conversation access, including the "frozen at the time you left" rule (ADR 0003);
   - that the content hasn't been hidden by moderation.
3. **The server returns a signed link** valid for about **5 minutes**: an HMAC over media id, size and expiry, using a server secret that is separate from `JWT_SECRET`. The bytes are then served from storage (PHP with `X-Sendfile`/`X-Accel-Redirect`, or the provider's signed URL).
4. **Caching on the phone:** the app loads thumb → medium → full progressively and caches images locally. The cache is cleared on logout and when the preview or account ends.
5. **Sharing never grants access.** A Memory card shared into chat still requests media through the same check, for each viewer.

### Deletion and retention
- Deleting a Memory or album photo keeps the asset only for the Undo window. After that it becomes `deleted` and its files are purged within 7 days.
- Account deletion purges that person's uploads under the same schedule, except where a legal hold applies (to be defined before launch).
- Backups are encrypted, and deleted media leaves the backups when they rotate.

### Later (not in M4)
- Video, which needs transcoding.
- Member tagging with consent.
- Per-photo captions in compose.
- Album cover choice.
- An image-safety check (e.g. hash matching for known abusive material) before public launch.

## Context

The app currently uses fictional illustrated "scenes" and stores nothing. README §3.1, §3.5 and §9 require private media, gated or short-lived signed URLs, real-content validation, location stripping and upload limits. The backend draft has only an unused `memory_media` table with a raw `storage_path`.

## Alternatives

- **Public bucket with random file names:** simple and fast, but anyone with a link keeps access forever, even after leaving the group. Rejected.
- **Always streaming through PHP with a bearer token:** strong control, but heavy on the PHP workers and awkward for image caching. Signed short-lived links give the same per-request check at lower cost.
- **Keeping the original files:** better quality, but carries GPS and other metadata. Rejected; we keep only the re-encoded sizes.
- **Client-only metadata stripping:** can't be trusted. The server always re-encodes.

## Consequences

- New backend pieces: `MediaStorage`, a `media_assets` migration, upload, processing and link Tasks, a cleanup job, and a signing secret in `.env`.
- Image processing needs GD or Imagick (with HEIC support) on the server. Check hosting before M4.
- The app needs a photo picker, a client-side resize step, upload progress and retry, and an authenticated image loader with an on-device cache.
- Tests must cover:
  - non-member, left-member and removed-member denial;
  - parent admins denied subgroup media;
  - expired and tampered signatures;
  - wrong file type disguised by name;
  - EXIF stripped;
  - limits;
  - orphan cleanup.
- **Rough cost:** about 1 MB per photo after processing (three sizes). For example, 1,000 members × 200 photos ≈ 200 GB, which is cheap on R2 or S3.

## Implementation notes (23 Oct 2026)

These are the differences from the plan above, all in the stricter direction:
- **Hidden media** (moderation) returns 404 for everyone, admins included. The download step carries no identity, so this fails closed.
- **Unattached uploads** are visible only to their uploader.
- **Memory deletion** marks its media deleted immediately (there's no server-side Undo window). Files are purged after `MEDIA_PURGE_AFTER_DAYS` (7).
- **Orphans** (unattached for more than 24 h) have their files removed at once; rows are kept so `client_upload_id` replays stay consistent.
- **A bad or missing `MEDIA_SIGNING_SECRET`** (empty, short, placeholder or equal to `JWT_SECRET`) disables only the media endpoints.
- **Image checks:** dimensions are verified before decoding, with a 40 MP decompression-bomb guard (`MEDIA_MAX_PIXELS`). Only re-encoded variants are stored, with private 0700/0600 permissions.
- **HEIC is refused (415)** until an Imagick processor exists, so the app must convert HEIC to JPEG before uploading.
- **Downloads** add `Content-Security-Policy: default-src 'none'; sandbox`, `nosniff` and `Cache-Control: private`.
- **Cleanup:** `composer media:cleanup` must be scheduled with cron.
- **Still to do:** S3-compatible storage, album and chat attachments, per-group quotas, and an account-deletion purge.
