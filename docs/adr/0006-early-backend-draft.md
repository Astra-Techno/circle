# ADR 0006: keep the early PHP backend draft, frozen until the contract is reviewed

Status: decided by the owner, 23 Oct 2026 ("do all"). Supersedes the AGENTS.md rule "Phase 1 owns mobile/ only; do not introduce backend services".

**Update, 23 Oct 2026:** the owner approved `docs/api-contracts/openapi.yaml` (0.3.0) for implementation, including the six backend choices listed in `docs/api-contracts/README.md`. **The freeze is lifted.** Backend work now follows the approved contract: M4 private media first (ADR 0007), then client integration. Contract changes still need review by both tracks.

## Decision

- Keep the PHP 8.3 / MySQL 8 backend that appeared in `backend/` on 23 Oct. It covers mobile + password accounts, groups with 10-level nesting via `group_closure`, members, invite links, join requests and Memories. Event and poll tables exist but have no endpoints.
- **Freeze its scope** until the owner reviews `docs/api-contracts/openapi.yaml`. Until then only bug fixes, security hardening (ADR 0005 rules) and tests are allowed. New endpoints (events, polls, chat, media) wait for the review.
- The OpenAPI file describes the endpoints that exist today, marked **draft**. Both the Flutter client and later backend work follow it once it's reviewed.
- Tests run with PHPUnit against a dedicated `circle_test` database only.

## Context

A review on 23 Oct found the draft was written before the contract and had no tests:
- reused PDO placeholders broke group creation and member adds;
- Memory creation always returned 403;
- the JWT secret wasn't validated;
- cascade removal could orphan subgroups;
- suspended users kept access;
- the API leaked whether a mobile number is registered and trimmed passwords, both contrary to ADR 0005.

The access checks themselves were mostly right: exact-group membership, and no inherited access for parent admins.

## Alternatives

- **Delete the backend until after UI-6:** follows the original plan, but throws away a mostly sound schema (closure table, statuses, invite links) and delays finding contract problems.
- **Keep extending it freely:** fastest, but repeats the "code before contract, no tests" pattern that produced the critical bugs.

## Consequences

- The backend counts as an M2 draft, not production. Nothing may be deployed or used with real people's data.
- Moving it to Task → Entity → SQL (README §5) is a separate, deliberate refactor after the contract review.
- The Flutter app does not call the backend until the contract is reviewed. It then integrates through a Dio client and secure token storage, one feature at a time.
