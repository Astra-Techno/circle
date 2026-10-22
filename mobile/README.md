# CIRCLE mobile

Fictional, session-local Phase 1 prototype. See [developer setup](../docs/development.md), [architecture](../docs/architecture.md), and [design system](../docs/design-system.md).

Run `flutter pub get`, then `flutter run -d <device-id>`. Enter the visible mock code `CIRCLE-DEMO`. No real account or backend is used.

Validate with `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, and `flutter test`. Native integration testing requires an Android device or emulator.
