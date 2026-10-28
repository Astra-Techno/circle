# Android 1.0.19 build20 — Chats, photo attachments and Events

28 October 2026. Includes the live text Chats/Events integration, private chat photos and event covers while preserving current visual/navigation changes. Chats support up to four JPEG/PNG/WebP photos with optional caption/reply, private inline zoom, immutable send retries and frozen history/unsend controls. Accepted direct requests are required before photo sharing. Event organizers/exact-group admins can add/change/remove covers; members see covers in lists/detail. See [service scope](live-chat-events.md) for limits and authorization details.

OpenAPI0.4.1/migration021. All92 unique operations and514 local references resolve. Full backend218 tests/3,932 assertions pass; PHPStan/composer validation clean. Full Flutter709 passed/1 skipped/13 known Windows-baseline golden mismatches; no functional failures. Final30 focused tests and12 media tests pass (including eight new light/dark phone/tablet200% renders); analyzer/format/design guard clean. Representative media renders inspected; approved golden baselines unchanged. No Android device is attached: native picker, physical installation, two-phone access, actual push and reminder delivery remain owner acceptance checks.

The owner explicitly approved a new dedicated Android release key on28October2026 because the previous private key is unavailable. This release requires uninstalling build18/build19 first, clearing local app data; server accounts/groups/Memories remain. Future APKs must reuse the new key. Release signing reads private `mobile/android/key.properties` and no longer falls back to a generated debug key. The private keystore/password backup is outside Git/public downloads; the owner must save it securely outside this temporary environment. Locally restore both signing files into `mobile/android/`, where they are gitignored.

Production build command (after tests finish):

```sh
flutter build apk --release --dart-define=CIRCLE_API_BASE_URL=https://circle.cloudkart24.com/api/v1 --dart-define=CIRCLE_PREVIEW=false --dart-define=CIRCLE_PUSH_ENABLED=true
```

The current deployer intentionally skips APK binaries. Versioned site links can use `downloads/download.php` through the directory rewrite when the APK is absent: it only redirects the exact current metadata filename to the public repository copy, rejects arbitrary paths/URLs and uses no-store. Earlier immutable APKs remain untouched; the removed stable alias is not restored. Backend migration/deployment and full hosted artifact verification are separate from a Git push.

Verified artifact: 65,851,130 bytes; SHA-256 `2839ded341bf5b35e8111ee1206c99c9fa4dbb17dd6456eec4e06de2c6d5122f`. Package `com.circlecommunity.mobile`; versionName1.0.19/versionCode20/minSdk24/targetSdk36; non-debuggable. `apksigner verify` passes; certificate SHA-256 `157579dd08f44d8aebe9bc5b6e53e778d8ca642d97233d15c206f8f5185df01e`. Production HTTPS API/previewfalse/pushtrue. Previous immutable build19 bytes/hash remain unchanged. Repository publication and live-site verification are recorded separately in PROJECT_STATE.md. Current cloud egress denies a CONNECT tunnel to the live domain (proxy403), so this environment cannot trigger/verify the production deployment. Run the existing hosted deployment link to apply migrations017–021 and refresh the pages/fallback before using the new service endpoints.

Source/APK release commit `0d07fde` is pushed to `main`. The full GitHub-hosted immutable APK was downloaded after the push and matches65,851,130bytes/SHA-256 above. This proves repository publication; the production domain/deployment remains blocked by this environment’s proxy and unverified.
