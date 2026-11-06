# Maestro setup — 6 November 2026

Maestro CLI2.12.1 is installed in this execution environment. The supplied installer host `https://get.maestro.mobile.dev` returned403 under the enforced network policy. Installation instead used the official allowed GitHub release, without changing network policy or disabling TLS:

https://github.com/mobile-dev-inc/Maestro/releases/tag/cli-2.12.1

The349,832,427-byte maestro.zip matches the release's checksums_sha256.txt:

`54dbb0716425626604973cbb374c585ca30272375d9ce15177a1152765ddd9d7`

The CLI startup script was inspected before execution. `maestro --version` completed successfully and reported2.12.1. Local wrapper: `/workspace/toolchain/bin/maestro`; extracted distribution: `/tmp/circle-maestro-2.12.1/unpacked/maestro`, linked from `/workspace/toolchain/maestro`. It uses the local Java21 runtime, Android platform-tools and a writable task-specific Java user directory. The standard HOME variable is unchanged. Analytics and the CLI's analysis-notification banner are disabled in the wrapper. This is temporary local tooling, not a vendored tool or an installation on the owner's phone/computer.

## Current test limit

`adb devices` reports no attached devices. No emulator installation or hardware-acceleration device is available here. No Circle APK was installed, no Maestro test was executed, and no app state or production account was changed. CLI version validation is not UI-test coverage.

An actual Android device/emulator and an approved test account/backend are needed before app-flow verification. Use fictional accounts for tests. Do not automate registration, deleting data or clearing app state against the live production service as an incidental setup check. Existing Android installations signed with the old key require a one-time reinstall for release39; preserve unsent drafts before any owner-directed uninstall.

Check the local setup with:

```bash
/workspace/toolchain/bin/maestro --version
/workspace/toolchain/android-sdk/platform-tools/adb devices
```

Application source, signing keys, APK and release metadata were unchanged by this setup. Installation must be repeated if this temporary environment is replaced.
