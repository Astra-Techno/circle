# Android1.0.23+24 — 29 October2026

Fixes a confirmed missing time-zone alias defect in notification quiet-hours checks. The previous dataset omitted UTC/GMT/Asia/Calcutta, despite default UTC preferences and PHP accepting aliases. Valid background notifications could be caught as errors instead of displayed outside quiet hours. Notification and Events initializers now share the alias-preserving dataset. Consent, current-session/group authorization, quiet-hour policy and saved opt-outs remain enforced.

Connection help now distinguishes missing build support, Firebase startup, phone permission, Google token retrieval, server registration (numeric HTTP status only) and native setup. The connected label refreshes after passive registration, and active quiet hours are visible. No private token, provider error body or credential is displayed/logged.

- Immutable APK: `downloads/circle-1.0.23-24.apk`
- Size: 66,605,182bytes; SHA256 `6eab8373df8e4a8b188cdb971a44490e06101a4dbc6ed331c7d3b265acae8561`
- APK v2 signature verified; certificate SHA256 `157579dd08f44d8aebe9bc5b6e53e778d8ca642d97233d15c206f8f5185df01e` matches builds20/22/23. Update without reinstall for that signing identity; historical different-key builds require reinstall.
- Verified package `com.circlecommunity.mobile`, versionName1.0.23/versionCode24, minSdk24/targetSdk36, non-debuggable.
- Actual build command: `./scripts/build-android-release.sh`, explicitly sets production HTTPS API, `CIRCLE_PREVIEW=false`, **`CIRCLE_PUSH_ENABLED=true`**. Normal Flutter release build completed in201.3s after tests; no test-only integration plugin in release registration. No dependency or backend changes.
- Full Flutter746 pass/1skip/13 existing Windows golden differences on Linux, no functional failures; analyzer/format clean. Regression coverage includes UTC daytime/overnight, GMT/India aliases, Events database initialization, permitted background display with default UTC quiet hours, safe failure stages and live connection-label updates. Baselines unchanged.
- Previous APK23 hash remains `f920dc155b1036f0f873d33665ab534675749966b71273c1b630945a56f6e15f`.

Metadata and both site buttons agree on build24. A source push does not prove live hosting deployment. No physical Android device was attached; production-domain CONNECT remains blocked403 here. Real two-phone foreground/minimized/closed delivery and server worker/configuration remain acceptance checks. No broadcast/test push or production message was sent here. See [phone and hosting checks](android-push-troubleshooting.md).
