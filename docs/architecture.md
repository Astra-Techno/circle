# Architecture

Product rules and the target system: README §2–9. This file describes how the code is built today.

## Mobile app (`mobile/`, UI-2 state, 23 Oct 2026)

Flutter 3.44.8 with Riverpod and go_router. About 6,100 lines in `lib/`.

```text
lib/
  main.dart                     ProviderScope(CircleExperience)
  app/circle_experience.dart    router: public access routes, /invite/:token, /compose,
                                5-tab StatefulShellRoute (home, chats, groups, events, you)
  core/                         design tokens (Space, CircleRadius, circleTheme), shared
                                components, CircleFailure, theme mode controller
  features/
    workspace/                  domain: CircleWorkspace + split repository interfaces
                                (all Future-based); data: MockCircleRepository (fictional,
                                session-local); application: viewer/session/workspace
                                providers; presentation: async WorkspaceView, group visuals
    groups/                     domain: CircleGroup, InviteLink, JoinRequest,
                                DirectInvitation, MembershipRules, group tree ordering;
                                presentation: groups tree, group detail (tabs), members,
                                invite, settings, invite-link landing
    memories/                   domain + presentation (cards, compose with explicit audience),
                                Home filter state
    events/  chat/  profile/    group-scoped events with local RSVP; chat directory
                                placeholder; You screen (invitations, saved, appearance)
    auth/                       mobile + password validation and access screens (preview only)
```

- **Dependencies point one way:** `groups → memories/events → workspace → core`. Features never import `app/`.
- **Rules live in the domain.**
  - `MembershipRules` (pure functions) decides:
    - who may invite, approve, promote, demote, remove, transfer or leave;
    - cascade sets;
    - discoverability (hidden and root groups are never listed);
    - parent membership at join *and* approval;
    - the 10-level depth limit.
  - The mock repository re-checks every mutation through the same rules. Widgets only ask the rules which actions to show.
- **Viewer and session:** `circleViewerProvider` replaces hard-coded ids. The preview session is an in-memory flag. Registering or logging in starts an empty workspace; "Explore fictional circles" loads the showcase.
- **Mutations** are awaited through a calm-failure helper that shows a snackbar on error.
- **Not yet:** persistence, HTTP, real authentication, chat messages, polls, albums, or event creation. The repository interfaces are shaped so a Dio-backed implementation can replace the mock after the OpenAPI review.

## Backend (`backend/`, draft, ADR 0006)

PHP 8.3, MySQL 8 (tests currently run on MariaDB 10.4), no framework.

- **`public/index.php`** loads `.env` and calls `App::handle(Request::fromGlobals())`.
- **`src/App.php`** holds the route table:
  - Middleware: CORS allowlist → auth (JWT + open session + active user) → rate limits (general, auth, per-mobile failed-login).
  - Unexpected errors become a generic 500 with redacted logs. Duplicate keys become a 409 `conflict`.
- **`src/Core/`:** Router (numeric ids), Request (raw password access, clamped ints), Response (JSON envelope; capture mode for tests), Database (PDO, native prepares, typed binding, UTC, transactions), JWT (HS256, mandatory exp, jti/sid, strong-secret guard), Passwords (Argon2id 64 MiB/t3/p1, dummy-hash timing, rehash), Validator, Log (redaction), Migrator.
- **Controllers** (Auth, Group, Member, Memory) and **repositories** (Group, Member) are static classes. Moving to Task → Entity → SQL is a planned refactor after the contract review.
- **Schema:** `database/migrations/001–005`.
  - `groups` with `parent_id`, `root_id` and `depth`, plus a `group_closure` table.
  - `group_members` statuses, `invite_links`, `join_requests` (unique per pending request), `refresh_tokens` with sessions.
  - Memories, comments, reactions, saves.
  - Events and polls tables (no endpoints yet).
- **Authorization:** active membership in the exact group on every endpoint. Leave/remove cascades through the closure table in one transaction, blocked while the person owns or is the last admin of a descendant. Approval re-checks parent membership.
- **Tests:** `tests/` (PHPUnit 11, in-process through `App::handle`) against a dedicated `circle_test` database. `composer test` gives 74 tests; `composer analyse` runs PHPStan level 6.
- **Contract:** `docs/api-contracts/openapi.yaml` (draft).

## Integration (done, 23 Oct 2026): preview mode and server mode

- **Preview mode (default):** the fictional `MockCircleRepository`, used for the tour and tests.
- **Server mode:** built with `--dart-define=CIRCLE_API_BASE_URL=…`.
  - `core/api/`: Dio client, auth interceptor with single-flight refresh (refresh tokens are single-use), typed `ApiError` with calm messages, secure `TokenStore` bound to the server URL, `AuthApi`.
  - `features/workspace/data/api/`: API repositories behind the same domain interfaces, plus JSON mappers.
  - Media pipeline: picker → type sniff → SHA-256 → ticket → PUT → `media_ids`; display via `CircleSignedImage`, which takes only `SignedMediaUrl`.
  - Features without server support are gated by `CircleFeatures` / `FeatureGate`: one honest "Not on the server yet" card and no dead buttons.
- Widgets never call HTTP; tests use a fake Dio adapter. An opt-in real-HTTP smoke test (`--tags smoke`) runs against a local `php -S` with a `circle_dev` database.
