# Development

## Mobile app (`mobile/`)

Prerequisites: Flutter 3.44.8 stable / Dart 3.12.2, Android SDK and a configured emulator or physical device. Debug builds without an API override use a fictional, session-local mock; release builds connect to the deployed HTTPS API by default.

```bash
cd mobile
flutter pub get --enforce-lockfile
flutter run -d <android-device-id>      # web fallback: flutter run -d chrome (does not validate Android)
```

In a debug/explicit preview build, on the welcome screen:
- **Explore fictional circles** loads sample groups: family, a college batch nested 4 levels deep, office and club, with pending invitations and join requests.
- **Get Started / Log in** accepts well-formed fictional mobile details and a password (6–128 characters for registration). Input is validated and discarded, and the workspace starts empty.

Nothing is sent or stored. Everything resets when the preview ends or the app restarts.

Invite links are mock `circle://invite/<code>` values. Use **Groups → Open an invite link**; during the tour, example codes are offered.

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test -d <android-device-id>
```

**Goldens** use bundled Plus Jakarta Sans and Material Icons at 393×852 and are rendered on **Windows** (CI runs on windows-latest).
- On Linux/macOS, golden tests report pixel differences; treat those as platform noise, not regressions.
- Regenerate on Windows with `flutter test --update-goldens`, inspect the PNGs, then run `flutter test` without updating.
- Generated baselines are provisional and need product review.

## Server mode (app ↔ backend)

Release installations use `https://circle.cloudkart24.com/api/v1` unless overridden. A release should show **Create account**, not **Preview registration**. For an explicitly fictional release, pass `--dart-define=CIRCLE_PREVIEW=true`.

The initial appearance is white/light even on a dark device. The calling code starts at India +91. **Use my location for country code** asks for one-time foreground location on Android/iOS; no background permission or CIRCLE-side coordinate storage is used. Denial and lookup failures preserve manual country selection. Web/desktop use manual selection.

Run the backend (below), then build the app against it:

```bash
flutter run -d <device> --dart-define=CIRCLE_API_BASE_URL=http://10.0.2.2:8080/api/v1   # Android emulator
# physical phone: use your computer's LAN IP; production must use HTTPS
flutter test --tags smoke    # optional real-HTTP smoke test (needs a running php -S and circle_dev)
```

Details: `mobile/README.md` (server mode).

## Backend (`backend/`, see ADR 0006)

Prerequisites: PHP 8.3+ with `pdo_mysql`, `mbstring` and Argon2 support, Composer, and MySQL 8. Tests currently also pass on MariaDB 10.4. Give the database root account a password, even locally.

```bash
cd backend
composer install
cp .env.example .env        # then set DB_* and a random JWT_SECRET:
php -r 'echo bin2hex(random_bytes(32)), PHP_EOL;'
php src/Core/migrate.php    # or: composer migrate
composer serve              # php -S on localhost
```

The server refuses to start requests if `JWT_SECRET` is empty, shorter than 32 bytes or a known placeholder. Keep `APP_DEBUG=false` except on your own machine.

**Tests** use a dedicated database and never touch your main one:

```bash
# once: CREATE DATABASE circle_test;  (the test bootstrap refuses any other database name)
composer test       # PHPUnit: drops and re-runs all migrations in circle_test
composer analyse    # PHPStan level 6 over src/ and tests/
```

If `composer install` fails with HTTP 401 from GitHub, your global Composer auth token (`~/.config/composer/auth.json`) is stale. Refresh or remove it.

API reference: `docs/api-contracts/openapi.yaml` (draft for review).

## Native screenshot and smoke checklist

- Accept Android licenses with `flutter doctor --android-licenses`, then configure an emulator or connect a development phone.
- Walk through:
  1. Welcome → explore tour → Home → filter chips → compose from a group (audience pre-filled) → Memory appears.
  2. Groups tree → nested group → breadcrumbs → Members (approve a request, promote with Undo, remove with cascade warning) → Invite (reset link) → Settings (approval, listed/hidden, leave guidance).
  3. Open an invite link: valid, expired, reset and "join the parent first" cases.
  4. Invitations on You: accept and decline.
- End the preview, then register with fictional details and confirm the workspace is empty.
- Capture `flutter screenshot -d <id> --out=<screen>.png` at 360×800, 393×852 and tablet sizes. Check light/dark, 2× text, keyboard, TalkBack, reduced motion, edge-to-edge insets and tap targets. Record device, OS and pixel ratio.
- Run a §4.0 task test with 3–5 people, including someone over 60.
- Physical Android interaction and approved native screenshots are mandatory before calling the app production ready.

## Main-only collaboration workflow

1. Inspect `git status` and pull `origin/main` before starting. Never create other branches or pull requests.
2. Preserve all uncommitted changes. Coordinate file and lockfile ownership between concurrent Web/local sessions.
3. **Commit shared docs as well.** Uncommitted docs on one machine look like a revert everywhere else.
4. Validate completed work, commit it directly to `main`, fetch and safely reconcile any remote changes, then push `origin/main`.
5. Never force-push or use destructive Git commands.

## Hosting PHP error diagnostics (26 October 2026)

The API entry point now enables `E_ALL` and `log_errors` before Composer loads, including when its PHP platform check fails. Public `display_errors` and `display_startup_errors` remain off. Check cPanel **Metrics → Errors** or the hosting-configured PHP error log after requesting `/api/v1/health`. A fatal failure adds a `[CIRCLE] fatal: PHP=… SAPI=…` entry with a redacted message and source basename/line. This identifies the runtime actually serving the request, independently of the panel's selected version. PHP also writes its normal error entries to the host's configured log; keep that log private and do not share credentials or unredacted request data.

Deploy the updated `public/index.php` as the hosting root `index.php` **and** `src/Core/Diagnostics.php` (alongside the existing `src/Core/Log.php`). The Git push alone does not update the hosting files. No new public diagnostic endpoint or API contract change is introduced. Errors occurring before PHP can execute the entry point still require the hosting error log. Reapply the domain's PHP handler after extracting deployment files if `.htaccess` was replaced; do not bypass Composer's platform check.

### Protected version/config page

Upload `backend/public/diagnostics.php` as `/diagnostics.php` in the hosting root (the repository's `deploy.php` now copies it and updates the root entry point). Set a fresh random `DIAGNOSTICS_TOKEN` of at least 32 characters in the server `.env`; never commit it or reuse JWT/database/migration secrets. Visit `https://circle.cloudkart24.com/diagnostics.php` and submit that token in the password form over HTTPS. The token is sent by POST, never in the URL. Unset/short tokens disable the page with 404; unauthenticated access shows only the access form. The allowlisted report works without Composer and shows PHP version/SAPI, PHP 8.3 compatibility, selected limits/error settings and required extension availability. It does not call `phpinfo()` or expose credentials, environment dumps, full filesystem paths, cookies or request headers. Remove the token after diagnosis to disable the page. Update the hosted `deploy.php` from this commit before using it to pull these changes; an older copy does not copy these new entry points.
