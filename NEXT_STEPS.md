# CIRCLE: next steps (23 Oct 2026)

Copy-paste commands for your laptop. Do the parts in order.

Commands are given for **Windows PowerShell** and **Ubuntu/Linux bash** where they differ. Replace `<…>` placeholders with your own values.

> Today's work exists only on the Linux machine at `/home/mathavan/projects/circle`. That folder is **not** a git repo. Do Part 1 first, or the next download will overwrite the work.

---

## Part 1: Move today's work into your Git repo

### 1.1 On the Linux machine: pack the project
Leaves out secrets (`backend/.env`), build output, caches and vendor folders.

```bash
cd /home/mathavan/projects/circle
tar --exclude=./mobile/build --exclude=./mobile/.dart_tool \
    --exclude=./mobile/test/failures --exclude=./mobile/.flutter-plugins-dependencies \
    --exclude=./backend/vendor --exclude=./backend/storage \
    --exclude=./backend/.phpunit.cache --exclude=./backend/.env \
    --exclude=./.claude \
    -czf ~/circle-2026-10-23.tar.gz .
ls -lh ~/circle-2026-10-23.tar.gz
```

Copy `~/circle-2026-10-23.tar.gz` to your laptop (USB, `scp`, shared drive, etc.).

### 1.2 On your laptop: check the repo is safe to update
Your Windows copy had **uncommitted edits** to README, AGENTS.md and docs. The archive contains newer versions of those files.

```bash
cd <path-to-your-circle-repo>
git status
git switch main
git pull --ff-only origin main
```

If `git status` lists uncommitted changes you want to keep, save a copy of those files somewhere outside the repo first. Don't use `git stash`.

### 1.3 Unpack over the repo
Overwrites files with today's versions.

```powershell
# Windows PowerShell (tar.exe is built into Windows 10/11)
tar -xzf $HOME\Downloads\circle-2026-10-23.tar.gz -C <path-to-your-circle-repo>
```

```bash
# Linux / macOS
tar -xzf ~/Downloads/circle-2026-10-23.tar.gz -C <path-to-your-circle-repo>
```

### 1.4 Delete the 35 files that were removed today
Unpacking can't delete files: these are the retired prototype, the old Roboto font, and old tests and goldens. Run this from the repo root; the command is the same on Windows and Linux.

```bash
git rm --ignore-unmatch -- \
  mobile/assets/fonts/LICENSE.txt \
  mobile/assets/fonts/roboto-bold.ttf \
  mobile/assets/fonts/roboto-medium.ttf \
  mobile/assets/fonts/roboto-regular.ttf \
  mobile/lib/app/app.dart \
  mobile/lib/app/circle_support_screens.dart \
  mobile/lib/app/route_policy.dart \
  mobile/lib/app/session.dart \
  mobile/lib/app/workspace_providers.dart \
  mobile/lib/app/workspace_view.dart \
  mobile/lib/auth_design_preview.dart \
  mobile/lib/features/auth/presentation/welcome.dart \
  mobile/lib/features/community/data/mock_community_repository.dart \
  mobile/lib/features/community/domain/entry.dart \
  mobile/lib/features/community/presentation/community_screens.dart \
  mobile/lib/features/feed/data/mock_feed_repository.dart \
  mobile/lib/features/feed/domain/post.dart \
  mobile/lib/features/feed/presentation/feed_controller.dart \
  mobile/lib/features/feed/presentation/feed_screens.dart \
  mobile/lib/features/groups/data/mock_circle_repository.dart \
  mobile/lib/features/groups/domain/circle_repository.dart \
  mobile/lib/features/groups/presentation/group_visuals.dart \
  mobile/test/app_test.dart \
  mobile/test/repository_test.dart \
  mobile/test/route_policy_test.dart \
  mobile/test/goldens/events.png \
  mobile/test/goldens/feed_dark.png \
  mobile/test/goldens/feed_light.png \
  mobile/test/goldens/friends.png \
  mobile/test/goldens/groups.png \
  mobile/test/goldens/invite.png \
  mobile/test/goldens/memories.png \
  mobile/test/goldens/post_courtyard.png \
  mobile/test/goldens/profile.png \
  mobile/test/goldens/welcome.png
```

PowerShell users: put the whole command on **one line** without the `\`, or replace each trailing `\` with a backtick `` ` ``.

### 1.5 Look before committing
```bash
git status
git diff --stat
```
Expect about 195 new files, many changed files, and the 35 deletions above. Check that `backend/.env` and `backend/vendor` are **not** listed; both are gitignored.

**Don't commit yet.** First regenerate the goldens and run the checks (Parts 2–4), then come back to Part 5.

---

## Part 2: Mobile app (Flutter 3.44.8 / Dart 3.12.2)

### 2.1 Install packages and run the checks
```bash
cd mobile
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test -j 2
```
Expected on Linux: about **476 passed, 1 skipped, 13 failed**. The 13 failures are golden screenshots, because the baselines were made on Windows. On **Windows**, those 13 should become the only failures until Step 2.2.

### 2.2 Regenerate the golden screenshots (Windows only, because CI runs on Windows)
```powershell
cd mobile
flutter test --update-goldens
flutter test
```
Then **open and look at** every PNG in `mobile/test/goldens/`. Creating a golden doesn't mean it's approved. Expect the new "Luminous Pure Minimal" look:
- white background, indigo buttons, the indigo pill on the selected tab;
- search and bell icons in the header.

### 2.3 Run the app on an Android phone or emulator
```bash
flutter devices
flutter run -d <device-id>                        # preview mode (fictional data, no server)
```
Try:
- Welcome → **Explore fictional circles** → Home, Groups, Chats, Events, You;
- create a group, then a subgroup;
- share a Memory with photos and a poll;
- RSVP to an event, and open the month calendar;
- in a chat: double-tap ❤️, swipe to reply, forward a message;
- the bell, Search, an album.

Check these on the phone:
- dark mode, and 200% text (system font size);
- TalkBack;
- the keyboard covering inputs;
- a small screen.

---

## Part 3: Backend (PHP 8.3 + MySQL 8 / MariaDB)

### 3.1 Install the PHP image library (needed for real photos)
```bash
# Ubuntu
sudo apt install php8.3-gd
php -m | grep -i '^gd$'          # should print: gd
```
```powershell
# Windows: open php.ini (find it with `php --ini`), remove the ';' from this line, save:
#   extension=gd
php -m | Select-String '^gd$'
```

### 3.2 Give the database root account a password (recommended)
```bash
# Ubuntu with MariaDB/MySQL
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '<a-strong-password>'; FLUSH PRIVILEGES;"
```
Better still, create a separate user just for CIRCLE:
```bash
sudo mysql -e "CREATE USER 'circle'@'localhost' IDENTIFIED BY '<another-strong-password>';
GRANT ALL PRIVILEGES ON circle_dev.* TO 'circle'@'localhost';
GRANT ALL PRIVILEGES ON circle_test.* TO 'circle'@'localhost';
FLUSH PRIVILEGES;"
```

### 3.3 Install dependencies and run the backend tests
```bash
cd backend
composer install
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS circle_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```
Tell the tests how to log in (only needed if you set a password or user in 3.2):
```bash
export CIRCLE_TEST_DB_USER=circle CIRCLE_TEST_DB_PASSWORD='<password>'
```
```powershell
$env:CIRCLE_TEST_DB_USER='circle'; $env:CIRCLE_TEST_DB_PASSWORD='<password>'
```
Then run the tests:
```bash
composer test        # expect: OK, 118 tests. With GD installed, the 4 photo tests should run instead of being skipped
composer analyse     # expect: [OK] No errors
```
If `composer install` fails with **HTTP 401 from GitHub**, your saved Composer token is stale. Fix it:
```bash
composer config --global --unset github-oauth.github.com
```

### 3.4 Run the backend locally for the app (server mode)
```bash
cd backend
cp .env.example .env
php -r 'echo bin2hex(random_bytes(32)), PHP_EOL;'   # run twice: one value for JWT_SECRET, a different one for MEDIA_SIGNING_SECRET
```
Edit `backend/.env`:
- `DB_DATABASE=circle_dev`, plus your DB user and password;
- `JWT_SECRET=<first value>` and `MEDIA_SIGNING_SECRET=<second value>`;
- keep `APP_DEBUG=false`.

**Never commit `.env`.**
```bash
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS circle_dev CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
composer migrate
composer serve                 # http://localhost:8080/api/v1/health should answer
```

### 3.5 Run the app against the real backend
In a second terminal:
```bash
cd mobile
# Android emulator (10.0.2.2 = your computer):
flutter run -d <device-id> --dart-define=CIRCLE_API_BASE_URL=http://10.0.2.2:8080/api/v1
# Physical phone on the same Wi-Fi: replace 10.0.2.2 with your computer's LAN IP
# and start the server with: php -S 0.0.0.0:8080 -t public
```
Try:
- **Create account** (mobile + password) → it logs you in automatically;
- create a group, share a Memory with real photos (needs GD from 3.1);
- create an invite link, then log out and log back in.

Optional automatic check against the running server:
```bash
flutter test test/smoke --run-skipped --tags smoke \
  --dart-define=CIRCLE_SMOKE_API=http://127.0.0.1:8080/api/v1
```

### 3.6 Schedule the photo cleanup (on any server you keep running)
```bash
crontab -e
# add (path to your repo):
# 15 3 * * *  cd /path/to/circle/backend && composer media:cleanup >> /var/log/circle-media-cleanup.log 2>&1
```

---

## Part 4: Security housekeeping

1. **Rotate the Stitch API key.** It was pasted in a chat. Create a new key in Google Stitch, delete the old one, then:
   ```bash
   claude mcp remove stitch -s user
   claude mcp add --transport http --scope user stitch https://stitch.googleapis.com/mcp --header "X-Goog-Api-Key: <NEW_KEY>"
   ```
   Do the same in `~/projects/git/op-new`, which has its own local copy: `claude mcp remove stitch -s local` from that folder.
2. **Database password:** see 3.2.
3. **Composer GitHub token:** see the end of 3.3.
4. **Optional:** connect the Mobbin design reference. Run `claude`, then `/mcp` → mobbin → Authenticate.

---

## Part 5: Commit and push (main only, per AGENTS.md)
After Parts 2–3 pass:
```bash
cd <path-to-your-circle-repo>
git add -A
git status                      # check again: no .env, no vendor, no build folders
git commit -m "CIRCLE: UI-2..UI-6, Luminous Pure Minimal design, M4 private media, app-backend server mode"
git fetch origin
git status                      # if origin/main moved, reconcile safely (git pull --ff-only, or merge) before pushing
git push origin main
```
Then watch the GitHub Actions "Flutter quality" run on `main`. It should pass once the goldens from 2.2 are committed.

---

## Part 6: Before inviting real people
- **Task test (README §4.0):** 3–5 people, including at least one person over 60, each tries to:
  - join with an invite link;
  - share a Memory with photos;
  - RSVP with guests;
  - reply in a chat.

  Note anything that confused them.
- **Answer the open questions** listed in `docs/validation.md`: 6 from connecting the app and 6 from the last UI items.
- **Next milestones:** M5 (events, polls and notifications on the server), M6 (real-time chat), M7 (OTP, security review, private beta).

---

### Where things are
| What | File |
|---|---|
| Product and UI plan | `README.md` |
| Rules for AI agents | `AGENTS.md`, `CODEX_START_PROMPT.md` |
| Decisions | `docs/decisions.md`, `docs/adr/0001–0007` |
| Design system | `docs/design-system.md` |
| API contract (approved, 0.3.1) | `docs/api-contracts/openapi.yaml` |
| How to run | `docs/development.md`, `mobile/README.md` |
| What was actually tested | `docs/validation.md` |
