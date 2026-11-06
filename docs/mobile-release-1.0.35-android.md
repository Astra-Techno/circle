# Android 1.0.35 (40) — Social 2.3

Packages the [complete screen audit fixes](screen-audit-fixes-2026-11-06.md) from source `6b15a72d41da19964ddf2c7d6fc7fd551b892aaa`. Built once with the official production script in167.7seconds. No backend/SQL changes.

- Immutable APK: `downloads/circle-1.0.35-40.apk`, **65,108,193bytes**, SHA256 `726913aef9d0455a0ffb8f9444f7abeea7b843ceba4635460d769994cf75dbec`.
- Package `com.circlecommunity.mobile`, version1.0.35/build40, minSdk24, targetSdk36, non-debuggable, ARM32/ARM64/x86_64.
- apksigner verifies v2; certificate `bcd5a9dcd2262be9f445f2d52892f574054e8616fbf0df66f226d88b263b9966` matches established build39. **Build39 updates directly.** Builds before39 require the previously disclosed one-time reinstall; finish/copy local drafts first. No new key generated.
- ZIP integrity passes. All three AOT libraries contain Social2.3 and the production API; obsolete recovery-roadmap text is absent. Bundled Inter faces match source. No private signing files bundled.
- Actual build uses production HTTPS API and CIRCLE_PUSH_ENABLED=true. No physical installation, production authentication or notification receipt is claimed.

[Machine-readable verification](mobile-release-1.0.35-android.json). Artifact, release.json and both download pages are prepared together; previous immutable APKs are preserved. Windows full refresh42188148877 passed773 tests/1skip; all22 baselines reviewed (7 expected changes,15 unchanged). Normal comparison and public repository download verification follow publication. Live hosting deployment remains separate and cannot be inferred from a Git push.
