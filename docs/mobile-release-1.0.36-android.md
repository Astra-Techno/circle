# Android1.0.36 (42) — Social2.4

Packages the [reference-inspired Memories timeline](memory-reference-design-2026-11-06.md), including the verified unsent-comment identity fix, from source `6ba65b97b6e50104e26bc70bd85928a3a2321602`. The earlier candidate41 was never published. Corrected build42 took158.3seconds with the official production script.

- APK `downloads/circle-1.0.36-42.apk`:65,092,153bytes; SHA256 `39d045fb7df87395e2f66031a2bab61f28f76f06d7319dfd482cba2586548b63`.
- Actual package `com.circlecommunity.mobile`, version1.0.36/build42, minSdk24, targetSdk36, non-debuggable, ARM32/ARM64/x86_64.
- apksigner v2 verification succeeds. Certificate `bcd5a9dcd2262be9f445f2d52892f574054e8616fbf0df66f226d88b263b9966` matches build39/40. Builds39 and newer update directly. Earlier builds need the previously disclosed one-time reinstall; copy/finish local drafts first. No new signing identity generated.
- ZIP integrity passes. All three AOT libraries contain Social2.4, See more, production API and the new Memory-scoped composer identity key. Bundled Inter files match source; no private signing inputs are bundled.
- Build uses production API and CIRCLE_PUSH_ENABLED=true. Native installation, actual push and physical-device appearance remain unverified.

[Verification receipt](mobile-release-1.0.36-android.json). The immutable APK, release.json and both buttons are prepared together, with previous immutable artifacts preserved. Normal Windows comparison42213906765 passed783 tests/1skip with clean formatting/analysis. Public full-download verification follows publication. Live hosting deployment is separate from Git publication.
