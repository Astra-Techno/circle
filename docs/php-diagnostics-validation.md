# PHP hosting diagnostics — 26 October 2026

Scope: pre-Composer E_ALL/error logging, fatal runtime/handler logging, token-protected allowlisted version/config page, and deployment copying the updated entry points. Public error display remains disabled. No API contract or authentication policy change. The existing short-password test fixture was corrected from nine to five characters to match the existing six-character minimum.

Validation on Windows / PHP 8.3.16:

- PHP syntax: index.php, Diagnostics.php, diagnostics.php and deploy.php passed.
- Composer strict validation and PHPStan analysis passed.
- Isolated diagnostics tests: 2 passed, 21 assertions (fatal before Composer, no public error text, config page disabled/denied/authorized, token not echoed).
- Initial `composer test` against dedicated `circle_test`: 119 tests, 1771 assertions, 6 failures. One was the stale nine-character password fixture (corrected afterward). Five were in unchanged media code/tests: Windows permissions assertion (0777 versus 0700), original/scratch-file retention and file counts, including the GPS marker remaining in an original scratch file. These media failures are unresolved; this delivery does not claim a green full backend suite or verified media cleanup.
- No Flutter code changed; no new mobile build or screenshots required. The diagnostic page was exercised through subprocess tests, not on the hosted server.

Deployment: see the hosting diagnostics section of `docs/development.md`. Update hosted deploy.php first or upload the entry points and Diagnostics.php manually. Set a unique server-only DIAGNOSTICS_TOKEN (at least 32 random characters), visit /diagnostics.php, submit it through the password form, and remove it after diagnosis. No token is included in Git. The page does not depend on Composer and therefore remains useful when Composer refuses the web runtime version. Hosting deployment and live runtime verification remain outstanding.

Final focused reruns through Composer against circle_test: AuthTest passed (21 tests, 113 assertions); DiagnosticsTest passed (2 tests, 21 assertions).
