# Poll vote HTTP parsing correction — 7 November 2026

A selected option on a Home Poll card could fail with “Choose valid options.” The mobile client correctly sends `PUT /polls/{id}/votes` with integer `option_ids`. `Request::fromGlobals()` skipped JSON decoding for every PUT because it assumed they were all raw photo uploads. The vote controller therefore received an empty request body and rejected it before reading the poll.

The parser now distinguishes the existing raw photo endpoints from JSON PUT endpoints. Votes, withdrawals, Event RSVPs and Chat reactions retain their JSON payloads. Profile/Circle photos, Memory upload content, Chat photos and Event covers retain bounded raw-body reads, including requests with an incorrect JSON MIME type. Existing strict vote validation, membership/privacy checks and mutation rules remain unchanged. There is no contract or schema change.

## Verification

- Added real local HTTP ingress tests through PHP’s built-in server and `php://input`, rather than injecting already-decoded request arrays. Cover single/multiple/empty option lists, MIME case/charset, API prefix and trailing slash/query, Event/Chat JSON PUT, existing POST/PATCH, malformed/non-object JSON and all five raw-photo route families.
- Negative control: the original parser fails the new JSON PUT regressions (two failures); restoring the fix passes all three ingress tests/189 assertions.
- Mobile Poll suites:20 checks pass, including inline selection/submission on Home, Circle, Profile, Saved, Memory detail and Poll list; layouts include narrow/tablet, dark/light and200% text.
- PHPStan512MB passes. Full backend suite:245tests/4759assertions passed against dedicated `circle_test` only. No live user account or production database used.

## Deployment

This is a backend-only change. The existing `backend/deploy/deploy.php` deployment copies application `src/` from `main`, including `Core/Request.php`, and runs any pending migrations as usual. No new SQL migration or APK/TestFlight rebuild is needed for this fix.

Live deployment cannot be executed from this environment: `circle.cloudkart24.com` is excluded by its current network allowlist and no production deployment credential is configured. Run the existing private hosting deployment link after this change is pushed, then select an option and submit in the installed app. Repository/test success is not a claim that production has updated.
