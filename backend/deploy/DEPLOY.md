# Deploy CIRCLE API to cPanel Shared Hosting

Target: `circle.cloudkart24.com`

## Step 1: Create MySQL Database in cPanel

1. Log in to cPanel
2. Go to **MySQL Databases**
3. Create a new database: `circle` (cPanel will prefix it, e.g. `username_circle`)
4. Create a new user: `circle` with a strong password
5. **Add user to database** with **ALL PRIVILEGES**
6. Note down:
   - Database name: `username_circle`
   - Username: `username_circle`
   - Password: (the one you set)

## Step 2: Set PHP Version

1. In cPanel, go to **MultiPHP Manager** (or **Select PHP Version**)
2. Select `circle.cloudkart24.com`
3. Set PHP version to **8.3** (or highest 8.x available)
4. In **PHP Extensions** (or **Select PHP Version > Extensions**), enable:
   - `gd` (required for photo uploads)
   - `exif` (applies camera orientation)
   - `fileinfo` (content sniffing, usually on by default)
   - `pdo_mysql` (usually on by default)

## Step 3: Upload Files

1. In cPanel, go to **File Manager**
2. Navigate to the `circle.cloudkart24.com` directory
3. Upload `circle-api-deploy.zip`
4. **Extract** the ZIP (right-click > Extract)
5. Files should be directly in `circle.cloudkart24.com/`, NOT in a subfolder
6. Verify you see these at the root level:
   ```
   circle.cloudkart24.com/
   ├── .htaccess
   ├── .env.production
   ├── index.php
   ├── _migrate.php
   ├── composer.json
   ├── src/
   ├── vendor/
   ├── database/
   └── storage/
   ```

## Step 4: Configure .env

1. In File Manager, **rename** `.env.production` to `.env`
2. **Edit** `.env` and fill in the database values from Step 1:
   ```
   DB_DATABASE=username_circle
   DB_USERNAME=username_circle
   DB_PASSWORD=your_database_password
   ```
3. The JWT_SECRET, MEDIA_SIGNING_SECRET, and MIGRATE_TOKEN are already generated. **Do not change them** unless you know what you're doing.
4. Save the file.

## Step 5: Set Permissions

In File Manager:
1. Right-click `storage/` folder > **Change Permissions** > set to `0755`
2. Right-click `storage/media/` folder > **Change Permissions** > set to `0755`
3. Right-click `.env` > **Change Permissions** > set to `0600` (owner read/write only)

## Step 6: Run Migrations

Open this URL in your browser:

```
https://circle.cloudkart24.com/_migrate.php?token=1048c091e29cd7107c2f8d5227797fd3bc51b64f9ddad5a8b0f22d8fa51f7658
```

You should see:
```
OK: Applied 6 migration(s):
  - 001_users.sql
  - 002_groups.sql
  - 003_memories.sql
  - 004_events_polls.sql
  - 005_security_hardening.sql
  - 006_media_assets.sql

SUCCESS. Now DELETE _migrate.php from the server.
```

**IMPORTANT: After migrations succeed, DELETE `_migrate.php` from File Manager.**

## Step 7: Test the API

Visit: `https://circle.cloudkart24.com/api/v1/health`

You should see:
```json
{"success":true,"message":"OK","data":{"status":"healthy","time":"2026-10-24T..."}}
```

## Step 8: Verify Security

Test that private files are blocked:
- `https://circle.cloudkart24.com/.env` → should return **403 Forbidden**
- `https://circle.cloudkart24.com/src/App.php` → should return **403 Forbidden**
- `https://circle.cloudkart24.com/vendor/autoload.php` → should return **403 Forbidden**

If any of these show file contents, your .htaccess is not working. Contact your host to ensure `mod_rewrite` and `AllowOverride All` are enabled.

## Step 9: Connect the Mobile App

Build/run the Flutter app pointing at the live API:

```bash
cd mobile

# Android emulator
flutter run --dart-define=CIRCLE_API_BASE_URL=https://circle.cloudkart24.com/api/v1

# Release APK
flutter build apk --release --dart-define=CIRCLE_API_BASE_URL=https://circle.cloudkart24.com/api/v1
```

## Step 10: SSL Certificate

If not already done, enable free SSL in cPanel:
1. Go to **SSL/TLS Status** or **AutoSSL**
2. Ensure `circle.cloudkart24.com` has a valid certificate
3. In **Domains** or **.htaccess**, force HTTPS redirect

Add to the top of `.htaccess` (after `RewriteEngine On`):
```apache
RewriteCond %{HTTPS} off
RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
```

---

## Future Updates (One-Click Deploy)

After the initial setup, push code to GitHub and deploy with one click:

**Option A — Browser:**
```
https://circle.cloudkart24.com/deploy.php?key=99dbb6661c8b687a583f5bf83d455a418a61930663d15fddd627df21a60a532d
```

**Option B — Command line:**
```bash
curl -H "X-Deploy-Key: 99dbb6661c8b687a583f5bf83d455a418a61930663d15fddd627df21a60a532d" \
  https://circle.cloudkart24.com/deploy.php
```

This will:
1. Download the latest code from GitHub
2. Update all PHP files in `src/` and migration files in `database/`
3. Regenerate the autoloader classmap
4. Run any pending migrations

**Never overwrites:** `.env`, `storage/`, `vendor/composer/`, `deploy.php`

---

## Troubleshooting

### 500 Internal Server Error
- Check cPanel **Error Log** (Metrics > Errors)
- Most common: wrong PHP version, missing pdo_mysql extension, bad .env values

### 403 on API endpoints
- `.htaccess` may not be processed. Check with host that `mod_rewrite` is enabled

### Photos not uploading (503)
- `gd` extension not enabled. Check Step 2.

### "Server is not configured correctly"
- JWT_SECRET or MEDIA_SIGNING_SECRET is missing/too short in `.env`

### Database connection refused
- Verify DB credentials in `.env` match exactly what cPanel shows
- Some hosts use `127.0.0.1` instead of `localhost`

## Deployer update: streamed downloads and visible failures

Replace the hosted `deploy.php` with the current `backend/deploy/deploy.php` before running another deployment. Keep the hosting `.env` and its existing DEPLOY_KEY/GITHUB_TOKEN values; the script contains no credentials. It does not update its own hosted copy.

The replacement streams the repository archive from GitHub codeload directly to a private temporary file instead of retaining the APK-sized ZIP in PHP memory. It keeps HTTPS certificate verification enabled, checks required PHP extensions before deployment, validates ZIP paths, prevents overlapping deployments, checks copy failures, removes temporary files and sends non-cacheable deployment reports. Authenticated exceptions and fatal runtime failures produce a report with the last completed steps rather than an empty response. Detailed PHP errors still belong in the private hosting error log. Existing root `.htaccess` is preserved so the host's PHP handler is not replaced; apply routing-template changes separately if needed.

Validation in the cloud machine: a complete deployment of the real repository archive succeeded with `memory_limit=32M` against the dedicated `circle_test` database; copied APK SHA-256 matched release metadata, existing `.htaccess` stayed unchanged, unauthorized requests returned 403, and disabling extensions produced the missing-ZIP diagnostic. This establishes local behavior; the hosting failure cannot be confirmed fixed until the replacement is uploaded and run on that host.

Authenticated deployment failures now include the PHP exception/error message, file and line. Exception reports also include a stack trace without argument values. Values configured under password/secret/token/key/credential names in the hosting `.env`, the supplied deployment key, URL credentials and common secret query parameters are redacted before display. Database/migration errors and download transport errors retain their diagnostic messages through the same redaction. Unauthorized requests still show only Access Denied. Errors that prevent PHP from executing this file at all (such as a syntax error in this file or a broken PHP handler) still require the hosting error log.
