# Android beta 1.0.2 (build 3)

Rebuilt the latest application source from main at 73322660454829a77c3316cbe8bbd3fea03211da with Flutter 3.44.8 / Dart 3.12.2. This release increments the version and refreshes the APK and download metadata; it introduces no application behavior changes. It connects to https://circle.cloudkart24.com/api/v1 with CIRCLE_PREVIEW=false.

The release APK passed Android signature verification. Manifest: com.circlecommunity.mobile, version 1.0.2, versionCode 3, minimum Android SDK 24, target SDK 36. Its size and SHA-256 are recorded in downloads/release.json.

This beta uses a newly generated Android development signing key. Its certificate SHA-256 is 6c78be13d88b19587e4c37edb9012e3f2eb37fee34f6850084dd069d78f9b66c. It differs from build 2: existing installations must be uninstalled before installing this APK. The key is retained outside Git in the cloud environment; it is not included in this commit.

Validation: frozen-lockfile dependency installation passed; Dart formatting checked 154 files with zero changes; Flutter analysis reported no issues. The full test suite completed with 484 passed, one opt-in HTTP smoke test skipped, and 13 golden-image comparisons failed on Linux against the Windows baselines. A sampled golden difference was concentrated around text/icon rendering, consistent with the documented platform limitation. No baselines were regenerated. APK release packaging passed after installing the missing JDK compiler. No Android device was attached, so native installation and behavior were not tested. No live registration or other production-data mutation was performed.

Build command (from mobile/):

```sh
flutter build apk --release --dart-define=CIRCLE_API_BASE_URL=https://circle.cloudkart24.com/api/v1 --dart-define=CIRCLE_PREVIEW=false
```

Publishing: downloads/circle.apk, downloads/index.html and downloads/release.json are consumed by the existing shared-host deployer. A Git push alone does not deploy them. At preparation time the cloud proxy blocked circle.cloudkart24.com, so hosting deployment and hosted checksum verification remain unconfirmed. Apply the saved network domain addition, run the existing authenticated deployment flow, then compare the hosted APK with downloads/release.json. The deployer also updates backend files and runs pending migrations; preserve the host's PHP handler configuration as documented in backend/deploy/DEPLOY.md.
