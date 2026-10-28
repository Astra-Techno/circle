# Default-on notifications —29October2026

The owner requested notifications enabled by default, with an option to turn them off in Settings. OpenAPI0.4.3/migration023 implement this account policy without bypassing phone permission, quiet hours, membership/session authorization or the configured delivery worker.

Accounts without saved preferences read enabled=true and all8 current categories=true. The first PATCH initializes the database row with the same complete effective defaults before merging only the supplied changes. Editing a timezone, quiet hour or one category cannot silently switch off unrelated notifications.

Saved choices take precedence: enabled=false and individual category=false remain off through unrelated edits and re-enabling the master switch. Existing partial/malformed category maps fail closed for omitted/invalid categories, so an old opt-out is never inferred as permission. Migration023 updates only the enabled-column default for future rows, leaving existing preferences untouched. Accounts already off remain off; the user can enable them in You→Notifications.

No Android rebuild is needed: APK22 already reads server preferences, supports the Turn off notifications/category controls, and checks OS permission during passive startup. If permission is absent, the existing Connect this phone action requests it in context. A server default cannot grant Android permission or establish actual FCM delivery; native/device acceptance is separate.

This fixes the first-save regression identified in review-notification-defaults.md while preserving the requested default-on policy. Earlier default-off acceptance records are historical. Current validation/publication state is in PROJECT_STATE.md.

Validation: full circle_test228 tests/4,136 assertions pass; PHPStan/composer valid. App/API/settings/session/design28 tests pass; Flutter analyzer and formatting clean. Contract99 operations/549 references resolve. Server-only behavior change; APK22 bytes unchanged. Production deployment is separate: the cloud proxy denies the live-domain connection, so the owner must run the existing hosted deployment link to apply migration023 and this source fix.
