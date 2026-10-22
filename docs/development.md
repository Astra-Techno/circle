# Run the prototype

Prerequisites: Flutter 3.44.8 stable / Dart 3.12.2, Android SDK and a configured emulator or physical device. No backend is required.

```powershell
cd mobile
flutter pub get --enforce-lockfile
flutter run -d <android-device-id>
```

Use the visible **CIRCLE-DEMO** invitation. This is public demo input, not a credential. No account is created. All data is fictional and session-local. Web is a fallback: `flutter run -d chrome`; it does not validate Android behavior.

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test -d <android-device-id>
```

Golden baselines use bundled Roboto and Material Icons and a 393x852 viewport on Windows with the pinned SDK. Review intentional changes with `flutter test --update-goldens`, inspect the PNGs, then run `flutter test` without updating. Generated baselines are provisional and require product review.

## Native screenshot and smoke checklist

- Accept Android licenses interactively with `flutter doctor --android-licenses`, configure an emulator, or connect a development phone.
- Exercise welcome → invalid invitation → CIRCLE-DEMO → feed → detail → comment. Toggle reaction and save, create text, navigate away and confirm state remains.
- Visit groups, album detail, member search/profile and reunion detail; toggle RSVP twice. Change appearance and end the demo; confirm session mutations clear.
- Capture `flutter screenshot -d <id> --out=<screen>.png` at 360x800, 393x852 and tablet dimensions; inspect light/dark, 2x text, keyboard, TalkBack, reduced motion, edge-to-edge insets and tap targets. Record device/OS/pixel ratio.
- Check long text, empty feed, injected repository error/retry, 100+ posts and unknown routes in automated tests. Feed cards are now built on demand with stable post keys; repository pagination remains required before real feeds.
- Physical Android interaction and approved native screenshots are mandatory before calling the app production ready. CI runs on pushes to `main`; validation must pass before pushing.

## Main-only collaboration workflow

Inspect `git status` and pull `origin/main` before starting. Never create other branches or pull requests. Preserve all uncommitted changes; coordinate file and lockfile ownership between concurrent Web/local sessions. Validate completed work, commit it directly to `main`, fetch and safely reconcile any remote changes, then push `origin/main`. Never force-push or use destructive Git commands.

Protected in-app routes now retain their destination through mock invitation entry. For example, `/post/courtyard` opens its detail after entering CIRCLE-DEMO. Invalid or external `next` URLs fall back to the feed. Ending a demo removes the old destination. Native Android app-link intent filters, verified domains and iOS universal links remain unconfigured.
