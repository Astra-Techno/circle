# Android push device acceptance — build 9 test candidate

27 October 2026. The owner confirmed that they can test an APK and that hosting sender configuration is ready. Those statements do not yet establish provider acceptance, device delivery, matching Firebase projects or a running cron job. No Android device is attached to this cloud workspace. Do not mark push verified until the following observations are recorded.

## Candidate scope

Android 1.0.8+9 is an opt-in test candidate, using the production API and `CIRCLE_PUSH_ENABLED=true`, preview false. Publish it at a separate immutable test APK path; do not change either stable site button, circle.apk, stable release.json or the build8 artifact. Install over the existing beta with the original signing key. Server global/category preferences remain off for every account until that owner explicitly chooses them. Source client/backend defaults remain false. This is a deliberate acceptance build, not approval for broad rollout.

Supported events are new Memories to other exact-group members, comments to the Memory owner, and replies to the Memory owner/parent-comment author (excluding actor, deduplicated). Reactions, group/invitation actions, Chats and Events are not implemented delivery hooks. No iOS delivery is included.

The app uses a generic native notification for both foreground and background so both engines share atomic OS handoff/deduplication. It contains no names, private text, image URLs or credentials. Taps reauthorize the target through the configured API. Foreground in-app banner presentation from N1c2 is superseded by this shared native path. Offline/expired background access tokens are never refreshed by the headless isolate; persistent pending reception waits for foreground restoration.

## Required owner checks

Use two consenting test accounts, A and B, in the same exact group. Both install the candidate, sign in, open You → Notifications, select New Memories and Comments/replies, choose the correct timezone, disable quiet hours temporarily, then Enable → Continue and allow Android notification permission. Verify the phone reports connected. Do not send private keys or FCM device tokens in chat.

1. With A's app open, B shares a Memory. A receives one generic notification; B receives no self notification. Tap opens the correct Memory.
2. Repeat with A minimized and then dismissed from Recents. Record Android version/manufacturer and observed delay. Android Force stop, restricted battery/data modes and Doze can suppress/defer normal-priority FCM; swiping Recents is not the same as Force stop. Test again after manually reopening if the OS stops delivery.
3. B comments on A's Memory; A gets the comment notification. A replies to B's comment; B gets the reply notification. Tap each to the correct Memory.
4. Turn a category off, turn all notifications off, and deny permission/channel access in phone settings. Each must suppress visible notifications and leave authentication/ordinary app use working. Re-enable explicitly, then repeat delivery.
5. Enable quiet hours spanning now in the correct timezone; send a Memory and observe no immediate alert. After quiet hours end, let the cron run and reopen/resume the app to process pending reception. No exact delivery time is promised.
6. Receive an alert, then delete its Memory/remove recipient membership before tapping. It must not reveal content or open another group's content; the app should show a calm unavailable message.
7. Log out while offline, then reconnect. Old-session messages/taps must not navigate or display private content. Log into another account and into a new session of the same account; old notifications should be cancelled and ignored. Repeat permission revoke/re-enable and restart.
8. Repeated delivery of the same event must not create multiple OS entries. Test a terminated cold-start tap, a warm tap, and interruption/restart during a tap. Pending opens must be retained until securely staged or expired.

Report pass/fail per case, package version, Android version/manufacturer and approximate send/receive times. Screenshots may show generic notification/error text; redact personal data. Passing mock tests and a release compile are not substitutes for these observations.

## Hosting verification (private)

Confirm the same Firebase project as the Android configuration, private service-account JSON outside the web root, PHP CLI 8.3+ with curl/OpenSSL, migration010, `PUSH_API_BASE_URL` matching the production API, and a cron invoking `composer notifications:work -- --limit=50` approximately every minute. The sender capture/delivery flags must be enabled by the hosting owner for this opt-in test; ready credentials alone do not send events. Keep operational output aggregate-only. Record worker counts for pending/sent/deferred/retried/cancelled, not credentials, payloads or device tokens.

Cloud access does not include hosting SSH/.env/cron inspection. A healthy HTTP API or a deployment response does not verify any of those private settings. Owner-confirmed configuration and actual device results remain necessary before stable release enablement.

## Contact invitation device checks (build12)

Enable notifications and Group invitations in the recipient's saved settings. As a different fictional test account with invite permission, choose one registered non-member contact and confirm sending. Verify the recipient inbox with push both enabled and denied; verify foreground, minimized and closed delivery/tap separately. Confirm acceptance joins only after consent and obeys manual approval for member-issued invitations. Decline, expired invitations, sender removal, parent exit, logout/account switching and duplicate sends must not revive or disclose stale invitations. Confirm non-registered contacts offer WhatsApp/SMS drafts and Copy works after cancelling the picker. No physical-device result has been recorded by cloud tooling.
