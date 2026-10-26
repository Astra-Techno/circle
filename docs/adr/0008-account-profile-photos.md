# ADR 0008: account profile details and photos

Status: implementation requested by the owner, 26 October 2026. Additive contract 0.3.3 reviewed by backend and Flutter tracks. This extends ADR 0007 for account identity only; Memory media rules do not change.

The owner requested a familiar cover banner, profile photo and editable personal details. Name and bio keep their existing visibility to active group members. Current city, hometown, work and education are optional owner-only fields. Mobile-number changes remain outside this update and require the secure verification design in ADR 0005.

Avatar and cover images belong to the account rather than one group. Their audience is the owner and authenticated people who currently share at least one exact active group membership with that owner. Parent/child ancestry alone never grants access. Suspension, loss of the final common membership, replacement or deletion is checked at the next photo request. This is not a public profile or publicly shareable image link.

Owner uploads are raw PUTs, maximum 5 MiB and 2048px per side. The shared inspector validates actual JPEG/PNG/WebP content, pixel limits and declared type. GD re-encodes the bytes, strips metadata and creates private size variants. Random storage prefixes stay under existing private media storage and never leave the server. Bearer-authenticated reads have no-store and nosniff headers; no signed public byte URL is issued. The mobile client scopes in-memory photo results to account and opaque photo revision, and clears images when the session ends.

A locked account row serialises photo replacement/deletion. A replacement stages new variants before the database swap; failure keeps the previous record and purges staged files. Old variants are purged after commit. A cleanup failure is redacted/logged and must not report a committed photo save as failed; operational garbage collection for orphaned profile prefixes remains a future maintenance task.

Crop/reposition tools, profile-detail visibility choices and public profile discovery are not introduced. Photos use the UI's declared centre crop; original metadata and source bytes are not retained. Group-level media authorization remains unchanged.
