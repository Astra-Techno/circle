# iOS push delivery

Owner30Oct requests notification permission on first app launch after installation. OS permission is independent from account opt-in. No token is registered before authentication. Denied permission and optional Firebase errors do not prevent use; notification settings retain the existing explicit connection/retry controls. On iOS subsequent SDK permission requests do not re-show a denied/accepted OS dialog. Reinstallation can preserve Keychain values, so iOS consults the OS rather than trusting the stored Android prompt marker.

Firebase project circle-c6919 / com.circlecommunity.mobile uses the supplied client plist. APNs production key must be installed privately in Firebase; the app config is not that private key. Production aps-environment and remote-notification capability are enabled. Existing signing identity remains unchanged. GitHub environment IOS_PROFILE_BASE64 must be replaced with the regenerated private profile. The signing helper rejects an old profile with no production push entitlement. Never put a provisioning profile or APNs P8 in Git.

Outbox capture and worker delivery now admit android and ios; all existing server preference, quiet-hour, session, exact-group and content authorization checks remain. FCM provides action-specific APNs alert text; owner-approved private name/content previews are available behind PUSH_PREVIEWS_ENABLED after client updates. Android stays data-only. OS remote display cannot revalidate access at presentation time, so an already-sent generic alert can arrive after logout or consent changes. Taps still validate recipient/session/content before navigating. This is not end-to-end encryption. Background execution and force-quit behavior are controlled by iOS; no guarantee of immediate delivery.

Foreground remote display is suppressed natively; existing Dart authorization then schedules a local notification through the iOS bridge, using the bounded owner-approved preview when present. Native scope binding, delivery deduplication, pending-tap handoff and a process mutex support the existing ledger. Logout removes delivered/pending notifications and invalidates the bound scope. Firebase remote taps and local taps enter the same authorization flow.

Release: production backend must deploy these changes and keep the existing notification worker cron. No schema migration is added. New iOS build uses push enabled. Test with a second eligible account: first launch Allow/Don't Allow, sign-in/registration, foreground/background/closed delivery, taps, denied permission, account switch/logout, category/global opt-out and quiet hours. Provider acceptance and native compilation do not establish actual device delivery.

## Updating the private GitHub profile on Windows

The current integration receives HTTP403 when writing environment secrets. In PowerShell, with the downloaded file in Downloads, copy its base64 without displaying it:

```powershell
Set-Clipboard ([Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\Downloads\CIRCLE_App_Store (1).mobileprovision")))
```

Open GitHub repository Settings → Environments → ios-testflight → IOS_PROFILE_BASE64 → edit. Paste, save, then clear the clipboard. Keep the other signing and ASC secrets. Never paste the value in chat or a public workflow input. If the filename/path differs, use its actual local path.

## Delivery acceptance notes

There is no notification sound/banner before the user grants OS permission. Android and iOS device preference screens remain independent from server global/category switches. To revoke, use CIRCLE notification settings or iOS Settings → Notifications → CIRCLE. First-launch prompting does not override a previous OS denial. With iOS notifications enabled, Firebase's APNs token can arrive asynchronously; registration waits briefly, then exposes a safe retry if unavailable.

## Token diagnostics (2 November 2026)

Connection help retains safe token-acquisition codes after a failed connection. APNS_TOKEN_MISSING means Apple registration has not returned a token within the current five-second wait. FCM_TOKEN_EMPTY means Firebase returned no token; FCM_NETWORK, FCM_SERVICE_UNAVAILABLE and FCM_CONFIGURATION classify reviewed SDK codes; FCM_TOKEN_ERROR hides other SDK details. These identify the failure stage, not a confirmed fix. Install the diagnostic TestFlight build, tap Enable notifications, then read Connection help. Never share tokens, credentials or raw SDK messages.

Owner device reported APNS_TOKEN_MISSING on 3 November. The connection path now explicitly requests Apple remote registration after notification permission and forwards the AppDelegate token to Firebase in addition to forwarding Flutter callbacks. This supports retry after startup registration and implicit-engine forwarding. FlutterFire already requests startup registration, so this is a hardening change, not proof of the original cause. Xcode compile and device acceptance remain required; persistent failure also needs native registration-error/entitlement/network diagnosis.

## Owner-approved previews (3 November 2026)

Owner explicitly requested person/circle names and message previews on the lock screen. Worker builds bounded title/body previews after existing eligibility/content checks. Reports never include report notes or reporter identity. Previews may remain visible after logout/access changes, and are not end-to-end encrypted. All recipient/session/expiry checks and authorized tap navigation remain required. Update the native app before deploying the worker change: older strict clients reject the new optional preview fields. Deployment alone updates background iOS alert text, but current app decoding is required for foreground alerts and taps.

Rollout: keep PUSH_PREVIEWS_ENABLED=false while installing updated clients. After supported phones are updated, set PUSH_PREVIEWS_ENABLED=true in production .env to include private previews. Default false preserves older strict data-only decoders; type-specific iOS alert text remains available without previews.
