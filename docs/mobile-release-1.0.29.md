# Mobile 1.0.29+34

Fixes scoped pagination to request each cursor only when visible and provide retry after errors. Group-chat deep links use full-screen conversation chrome. Entrance delays are capped at 250ms and reduced motion is respected. Subgroup creation scrolls above the keyboard. Invitation link entry opens its actual dialog; invented member counts and avatars were removed. The group-tree regression now reveals its off-screen lazy row before asserting presence.

The TestFlight target runs analysis, style/push guards and Python release checks before a single signed compilation, verification and upload. The unsigned validation target remains separate. Previously run45 spent16 minutes in unsigned compilation and19 minutes in the signed job; the duplicate compilation/runner allocation is removed. Actual new duration must be measured after completion; runner queues and Apple processing remain external.

Android release pending: this environment lacks the established private keystore/android/key.properties and Android SDK. No replacement identity generated and no download metadata changed. Restore the established signing inputs securely before building via scripts/build-android-release.sh and checking certificate/package/version/checksum. Previous immutable releases remain intact.

Windows visual baselines are rendered by explicit Flutter quality workflow dispatch, uploaded for review and never auto-committed. Linux differences are not accepted as replacement Windows baselines.

Local checks: format240 files unchanged; analyzer clean; Python iOS checks19 tests/1 skipped. Full suite699 passed/1 skipped/25 failed:22 visual differences and3 functional/stale-test failures. The latter were corrected; focused reruns11 viewport/chrome/motion,6 safe-area/motion and1 Save-menu checks pass. Windows full-suite and visual review follow; this is not a current all-green full-suite claim.
