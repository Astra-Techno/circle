# Android 1.0.26+27 — 30 October 2026

Packages the immersive navigation changes and UI audit corrections: route-specific titles, focused forms/photos, stable loading/error headers, invite/search retry, unsaved-form route guards, event/poll validation and reachable actions, honest profile Memory pagination, supported iOS invitation fallback and cleaner settings/link details.

Validation: analyzer clean; final focused50 tests pass (recovery/dirty-form exit, group/profile photos, navigation, polls, profile editing and design rules). Full suite667 pass/1skip/18fail before final corrections:13 Windows golden differences on Linux, one test shader-asset failure and four stale UI/recovery failures. All five non-golden failures were covered by the final focused run and passed. No Windows goldens regenerated. No backend code changed. Physical iPhone/Android acceptance and the production photo-loading root cause remain unverified.

Production APK uses scripts/build-android-release.sh, existing release signing identity, live HTTPS API and push enabled. Immutable artifact and metadata verification recorded below. Git push is separate from hosting deployment. iOS workflow dispatch requests signed TestFlight upload; Apple processing/compliance and external beta approval remain separate.

Artifact: downloads/circle-1.0.26-27.apk; 64735850 bytes; SHA256 `2df36b51ce398a12cbd1f6624e76ccf1e201983da22db6917c5aa73a61e691ac`. Established signing certificate verified. Source commit0cb7aa4. iOS TestFlight workflow: https://github.com/Astra-Techno/circle/actions/runs/41018674534 (initiated, completion not claimed).
