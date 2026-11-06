# iOS 1.0.36 (1058.1) — Social 2.4

[Signed workflow42213961079](https://github.com/Astra-Techno/circle/actions/runs/42213961079) completed successfully in **24minutes55seconds**. Apple reported `UPLOAD SUCCEEDED with no errors, 1 warning`; the fail-closed checker confirmed acceptance. Apple processing, tester availability and physical-device acceptance remain separate.

Packages corrected app source `6ba65b97b6e50104e26bc70bd85928a3a2321602`: the [reference-inspired Memories design](memory-reference-design-2026-11-06.md), reviewed Windows baselines and unsent-comment identity fix. Earlier candidate41 was not published; its iOS run42212335842 was cancelled before upload.

- Exported IPA:25,812,144bytes; SHA256 `b4e33b70ed1a9141865c1333c975a6623897bd242c1940ff067536b0ef0324d9` matches SHA256SUMS.
- Actual Info.plist: bundle `com.circlecommunity.mobile`, version1.0.36, build1058.1, minimum iOS13.0.
- AOT contains Social2.4, native CupertinoSystemText alias, production API and Memory-scoped composer identity key. All three Inter assets match source and have correct distinct PostScript names/weights400/500/600.
- Workflow signature and installation-metadata checks passed before upload. Temporary signing-material cleanup succeeded. No private signing inputs were committed.
- Corrected source passed783 tests/1skip on normal Windows comparison42213906765, including all22 reviewed image comparisons and the draft regression; format/analyzer clean.

Apple accepted warning90068: existing iOS13 deployment target must become at least15 before April2027 uploads. This upload succeeded; OS-support policy was not changed in this design task.

[Machine-readable receipt](mobile-release-1.0.36-ios.json). Install this build after Apple processing and check Account → Interface version: **Social2.4**. Binary/widget verification does not establish physical-device appearance, production-image availability or actual push delivery.
