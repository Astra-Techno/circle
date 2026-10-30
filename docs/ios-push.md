# iOS push delivery

Owner30Oct requests notification permission on first app launch after installation. OS permission is independent from account opt-in. No token is registered before authentication. Denied permission and optional Firebase errors do not prevent use; notification settings retain the existing explicit connection/retry controls. On iOS subsequent SDK permission requests do not re-show a denied/accepted OS dialog. Reinstallation can preserve Keychain values, so iOS consults the OS rather than trusting the stored Android prompt marker.

Firebase project circle-c6919 / com.circlecommunity.mobile uses the supplied client plist. APNs production key must be installed privately in Firebase; the app config is not that private key. Production aps-environment and remote-notification capability are enabled. Existing signing identity remains unchanged. GitHub environment IOS_PROFILE_BASE64 must be replaced with the regenerated private profile. The signing helper rejects an old profile with no production push entitlement. Never put a provisioning profile or APNs P8 in Git.

Outbox capture and worker delivery now admit android and ios; all existing server preference, quiet-hour, session, exact-group and content authorization checks remain. FCM adds a generic APNs alert (CIRCLE / You have a new update. Open CIRCLE to view it.) without private names, messages or photos; Android stays data-only. OS remote display cannot revalidate access at presentation time, so an already-sent generic alert can arrive after logout or consent changes. Taps still validate recipient/session/content before navigating. This is not end-to-end encryption. Background execution and force-quit behavior are controlled by iOS; no guarantee of immediate delivery.

Foreground remote display is suppressed natively; existing Dart authorization then schedules a generic local notification through the iOS bridge. Native scope binding, delivery deduplication, pending-tap handoff and a process mutex support the existing ledger. Logout removes delivered/pending notifications and invalidates the bound scope. Firebase remote taps and local taps enter the same authorization flow.

Release: production backend must deploy these changes and keep the existing notification worker cron. No schema migration is added. New iOS build uses push enabled. Test with a second eligible account: first launch Allow/Don't Allow, sign-in/registration, foreground/background/closed delivery, taps, denied permission, account switch/logout, category/global opt-out and quiet hours. Provider acceptance and native compilation do not establish actual device delivery.

## Updating the private GitHub profile on Windows

The current integration receives HTTP403 when writing environment secrets. In PowerShell, with the downloaded file in Downloads, copy its base64 without displaying it:

```powershell
Set-Clipboard ([Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\Downloads\CIRCLE_App_Store (1).mobileprovision")))
```

Open GitHub repository Settings → Environments → ios-testflight → IOS_PROFILE_BASE64 → edit. Paste, save, then clear the clipboard. Keep the other signing and ASC secrets. Never paste the value in chat or a public workflow input. If the filename/path differs, use its actual local path.
