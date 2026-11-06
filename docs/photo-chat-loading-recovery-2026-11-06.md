# Photo traffic and cross-page Retry failures — 6 November 2026

Owner reports images, Chats and other pages failing to load. Safely pulled main; no remote changes. Production cause remains unconfirmed: this managed environment has no production credentials and its enforced allowlist excludes circle.cloudkart24.com. No signed/private URLs or account credentials were collected.

## Reproduced defect and fix

Memory photo-link GETs and signed byte GETs each consumed the same per-IP general 60/minute quota as Chats, workspace and other page reads. Thirty uncached photos can consume the entire default budget even before page requests. Shared-network users also share the IP quota. Existing avatar/group-photo reads already had independent protection; Memory and Chat photos and Event covers did not.

A new in-process HTTP regression fails on the old routes: the photo byte request receives429 after the link consumes the available general quota. Read-only Memory links/bytes, Chat photo bytes and Event cover bytes now use the independent bounded media_read bucket, default240/minute, configurable through RATE_LIMIT_MEDIA_READS_PER_MINUTE. The existing general/auth/profile and upload limits remain. Private link authorization, exact membership, signed HMAC/expiry, moderation visibility and removal checks are unchanged. The bucket is still per-IP and bounded, not unlimited.

Tests also exercise the reverse direction (page quota exhausted while authorized photo reads still work), deliberate photo throttling with Retry-After, continued general throttling and unauthorized/tampered requests. Existing private-media access regressions are included.

## Delivery and limits

Backend-only fix: no SQL migration or mobile binary change. The current deploy.php recursively copies backend/src and regenerates the autoloader; run the existing authenticated deployment script against main to activate the updated App.php and RateLimitMiddleware.php. An unchanged final SQL migration number is expected for this fix. No deployment-script replacement is required. The environment example documents the new optional setting; preserved production .env automatically uses the240 default when absent.

Repository publication is not a live deployment result. After deployment, confirm previously failing image/Chat requests in the installed app. If errors continue, capture their actual status/error code and redacted hosting error details before attributing500/503, network/TLS, missing images or storage faults to this quota defect. No live-host or physical-device success is claimed.

## Verification

- Old route reproduction:1test failed as expected (photo request429).
- Targeted media/profile suite:22tests/566assertions passed.
- PHPStan: clean with512MB and local loopback access (initial128MB worker exhausted memory; sandboxed parallel listener also required network-enabled execution).
- Full backend suite:237tests/4433assertions passed. The additional reverse-budget test was added after that run began and passed in the final MediaLink suite:12tests/328assertions, including both directions of quota isolation, independent media throttling and tampered HMAC rejection.
