# iOS 1.0.35 (1056.1) — Social 2.3

[Signed workflow42188155025](https://github.com/Astra-Techno/circle/actions/runs/42188155025) completed successfully in **15minutes58seconds**. Apple reported `UPLOAD SUCCEEDED with no errors, 1 warning`, and the fail-closed upload checker confirmed acceptance. **Apple processing, tester availability and physical-device acceptance remain separate.**

Packages app source `6b15a72d41da19964ddf2c7d6fc7fd551b892aaa`, the [complete screen audit fixes](screen-audit-fixes-2026-11-06.md). The later baseline/APK publication commit2785a2a does not change runtime source.

- Exported IPA:25,807,857bytes; SHA256 `af7c099afc8bb8ba2bca66040251d1e6ccdb4b1efa402c18cdc9520e1f7fc597` matches its SHA256SUMS manifest.
- Actual Info.plist: bundle `com.circlecommunity.mobile`, version1.0.35, build1056.1, minimum iOS13.0.
- AOT contains Social2.3, native CupertinoSystemText alias and production API. Obsolete password-recovery roadmap copy is absent. All three Inter font assets match source and have distinct, correct PostScript names/weights400/500/600.
- Workflow signature/installation checks passed before upload; temporary signing material cleanup succeeded. No private signing inputs were added to the repository.
- Windows full refresh42188148877 and normal comparison42189622241 each passed773 tests/1skip with clean format/analyzer.22 baselines reviewed;7 expected visual changes,15 unchanged.

Apple's accepted warning90068 says the existing iOS13 deployment target must become at least15 before April2027 uploads. It did not reject this upload; no OS-support policy change was made in this screen-design task.

[Machine-readable receipt](mobile-release-1.0.35-ios.json). Binary markers/widget renders confirm packaged source, not native visual acceptance, actual production photos, push receipt or Apple processing. Install this build and check Account → Interface version:Social2.3 for the updated UI.
