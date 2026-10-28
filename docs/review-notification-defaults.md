# Review of1d0f298 —29October2026

Safely pulled1d0f298 onto main while preserving the previously interrupted poll hardening. The commit changes only backend/src/Core/NotificationPreferences.php; no APK or production deployment is established by that pull.

## Findings

- **Settings regression:** a fresh account reads enabled=true with8 categories enabled. Its first PATCH changing only timezone inserts a preference row using the unchanged database/controller defaults (enabled=false/categories=false), then loads that row. The response becomes enabled=false with0 categories enabled. Reproduced through the actual API on circle_test (1 probe/7 assertions). Initialization must preserve the effective defaults and explicit choices during partial updates.
- **Scope is broader than new accounts:** every account without a saved preference row uses the new defaults, regardless of creation time. Missing categories in saved JSON also become true. Explicit saved false values are preserved. Decide/document whether the broader behavior is intended; it is not a registration-only change.
- **Delivery claim needs qualification:** Android permission, Firebase configuration, session/device registration and worker delivery remain necessary. Passive app startup checks permission without prompting; server defaults alone cannot guarantee immediate push.
- **Contract/test drift:** two PushFoundationTest assertions still expect opt-in/off defaults. The OpenAPI preference defaults and opt-in documentation were not updated by the commit. These failures are separate from the reproduced first-save bug; do not change tests merely to hide the latter.

Review validation: notification/worker/poll run46 tests produced2 notification assertion failures and1 error in the pre-existing unfinished poll regression. The poll error has since been fixed and all8 poll tests/178 assertions pass; PHPStan is clean. No production deployment or physical push delivery is claimed.

## Recovered poll follow-up

Poll writes now check current locked membership, parent status, admin role, selections and option totals after lock waits. Group/poll notification lock order is consistent. MariaDB1020 snapshot conflicts and1213 deadlocks roll back and retry with fresh reads, at most3 attempts; exhaustion returns409. Tests use two real circle_test connections to verify removal, Memory hiding and admin demotion after an older snapshot, plus the12-option cap/idempotent duplicate. No APK changes or rebuild are required for this server-only patch.

The default-on commit is preserved. Notification initialization/policy alignment remains unresolved; do not call the complete branch deployment-verified.
