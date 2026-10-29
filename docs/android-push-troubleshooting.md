# Android push connection and build24

Owner reported missing Android notifications on29 October2026. Build23 was already produced with `CIRCLE_PUSH_ENABLED=true`; the APK also contains the Firebase gateway/coordinator and registration path. The compile flag alone does not prove registration, hosting worker execution, provider acceptance or phone display.

## Confirmed defect and correction

The installed timezone0.11.2 `latest.dart` dataset lacks backward-compatible names including `UTC`, `GMT` and `Asia/Calcutta`; `latest_all.dart` contains them. CIRCLE's default preference is `UTC`, and PHP explicitly accepts backward-compatible IANA names. With quiet hours enabled, `pushQuietNow` previously threw for those saved zones. The background processor intentionally catches operational failures, so a valid push could stay undisplayed even outside quiet hours. The new quiet-hours status exposed this defect in tests before publication.

Notification and Events initialization now both use `latest_all.dart`. Both are necessary because the time-zone database is process-wide: opening Events must not reset it to the alias-free dataset after notification initialization. New regressions cover UTC daytime/overnight policy, GMT, Android's legacy India alias, device-zone choices, Events initialization and a valid background notification with default UTC quiet hours. The background fixture verifies authorization still occurs before showing, with no credential refresh or consent bypass.

## App changes

Build24 keeps the explicit push-enabled production build, and distinguishes disabled build/unsupported device, Firebase initialization, Android permission, Google token acquisition, CIRCLE registration and native delivery setup failures. Server registration errors expose only their numeric HTTP status, never a token, provider message, API credential or server response body. Logout/account changes clear the previous connection problem; session guards and serialized SDK cleanup remain enforced.

The connection label now refreshes when passive registration finishes, rather than showing an old value until another settings edit. You → Notifications → **Connection help** shows whether the running build includes push and the phone's connection state. Quiet hours show an explicit note while active. This does not silently change saved opt-outs, time zones or Android permission.

Production build command, from the repository root after loading the established Flutter/Android toolchain:

```sh
./scripts/build-android-release.sh
```

It always invokes `flutter build apk --release` with:

```text
--dart-define=CIRCLE_API_BASE_URL=https://circle.cloudkart24.com/api/v1
--dart-define=CIRCLE_PREVIEW=false
--dart-define=CIRCLE_PUSH_ENABLED=true
```

Keep the established private release signing key. Bump pubspec version/build for changed releases; never replace immutable APKs. No Android APK, Android keystore or Android signing input belongs in iOS workflows.

## Phone check

1. Install build24, sign in, then open You → Notifications → Connect this phone. Accept Android's permission request if shown. If connection fails, share the safe message and HTTP status; do not share tokens.
2. Open Connection help: support should say **Included in this app build**. Registered means the CIRCLE API accepted this phone; it does not prove FCM delivery or server worker execution.
3. Choose the desired categories. Set **Use device time zone** and confirm it, or temporarily switch quiet hours off while testing. Fresh defaults currently use22:00–07:00 UTC until a zone is saved. For India this is03:30–12:30 IST, so morning tests can legitimately be deferred.
4. Ensure Android's app permission and the **Circle updates** channel are allowed. Unmute the relevant chat/group as applicable.
5. Ask another active member of the same exact group to create a new Memory or send an eligible message after registration. Own actions do not notify their author, and old events are not replayed for a newly registered phone. Repeat foreground/minimized/closed tests. Force-stop, missing Google Play services, offline/Doze states and expired background authorization need separate diagnosis; no device delivery is claimed here.

The old `backend/public/push-test.php` broadcasts an unsupported, unscoped `type=test` payload which the current client correctly rejects. It also omits normal .env loading. Do not use it as a valid app delivery test or trigger a broadcast as part of this check; use an authorized real feature event instead. That legacy helper was not invoked or changed in this batch.

## Hosting check

The web deployer preserves existing .env files; committing an APK does not enable these private server switches. Confirm with the hosting owner:

```dotenv
PUSH_QUEUE_ENABLED=true
PUSH_DELIVERY_ENABLED=true
PUSH_API_BASE_URL=https://circle.cloudkart24.com/api/v1
FCM_PROJECT_ID=circle-c6919
```

`FCM_SERVICE_ACCOUNT_PATH` must point to the matching project's private, readable service-account file outside the web root. PHP CLI needs curl/OpenSSL; cron must run `composer notifications:work -- --limit=50` from the private backend directory approximately once per minute. Worker output is aggregate only. `disabled=1` means delivery is switched off; `unconfigured=1` means origin/provider setup failed; `deferred` can be quiet hours; `sent` means provider accepted it, not that the phone displayed it. See notification-worker.md and current feature docs for capture/eligibility rules.

If Google's token stage fails, check Google Play services/network and the Firebase project's API restrictions; the production Android application ID is `com.circlecommunity.mobile`. If certificate restrictions are configured, they must permit the established release certificate. Do not publish service-account files or raw Firebase/token errors.

## Verified checks

Full Flutter:746 passing,1 skipped,13 existing Windows-baseline golden mismatches on Linux; no functional failures. Analyzer and format clean. The earlier full run exposed six settings failures from the missing UTC alias; those are resolved in the final full run. Initial focused connection/safety/native/presentation suite55 pass; alias/regression-focused suite60 pass before the additional cross-Events test; the final full suite includes it. No backend code or contract changes.

## Verification limits

This environment's proxy still rejects CONNECT to the production domain with403, and no Android phone is attached. The owner was asked which installed build is in use and what Connect this phone reports. No server configuration change, production event, broadcast, real FCM receipt or physical-device acceptance is claimed by this batch. Release notes record actual test/signature/artifact results.
