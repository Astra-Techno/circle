# CIRCLE — Private Communities, Shared Memories

> **Current branch policy (owner instruction):** Use `main` only for all work and pushes. Do not create feature/topic branches. This supersedes older branching/PR workflow recommendations below and in the startup prompt. Preserve user changes and never force-push.

> **Project status:** Phase 1 Flutter prototype implemented with fictional, session-local data. See `docs/validation.md` for verified behavior and remaining device/backend work.
>
> **First launch:** A private social network for one college-friends community. **Future vision:** Multiple independently administered private communities.

## 1. Product vision

CIRCLE helps close-knit groups preserve shared memories and stay connected without public profiles, strangers, or an engagement-maximizing feed. The first community will be a college batch. Members can reconnect, share media, comment on memories, create smaller groups, and coordinate reunions.

**Core principles**
- **Private by default:** no public community data, posts, or member lists.
- **Invitation and approval:** only approved members can view community content.
- **Own your memories:** respectful media controls, export/delete paths, and clear sharing visibility.
- **Mobile first:** Flutter Android/iOS client; native Android development and testing first.
- **Multi-tenant readiness:** hard separation between communities, even while the first release uses one.
- **Simple first release:** social feed, groups, memories, member directory, events. Avoid unnecessary AI, chat, and video features initially.

## 2. Technology choices

| Layer | Choice |
|---|---|
| Mobile | Flutter (stable), Dart |
| State management | Riverpod |
| Navigation | go_router |
| HTTP client | Dio |
| Backend | Custom PHP 8.3+ REST API; no Laravel |
| Database | MySQL 8 |
| Admin console | Vue 3 + TypeScript + Vite + Tailwind CSS (later phase) |
| Media | Private local object storage abstraction initially; S3-compatible storage later |
| Push notifications | Firebase Cloud Messaging (later phase) |
| Development | Ubuntu, Android Studio/Android device, GitHub, Codex CLI + Codex Web |

**Backend architecture preference:** Task → Entity → SQL (TES), compatible with DataForge concepts. Do not invent or assume access to existing private DataForge packages. Implement minimal self-contained interfaces first; ask for package details only when integration is actually needed.

## 3. Initial feature scope (MVP)

1. **Authentication & onboarding** — email/password or OTP-ready abstraction, invitation codes, membership approval, logout and session refresh. Choose a secure email/password flow for initial local development with mock email delivery; do not hardcode credentials.
2. **Community & membership** — one community on day one; admins approve requests and manage roles (`owner`, `admin`, `member`).
3. **Member directory** — name, nickname, college, batch, department, optional city; privacy-aware profile access.
4. **Posts & feed** — text posts, photo attachments, chronological feed, comments, reactions.
5. **Groups** — smaller invite-only groups inside a community, each with independent memberships and visibility.
6. **Memories** — image galleries, albums, optional original photo year, captions and permitted member tagging.
7. **Events & reunions** — create events, RSVP, browse attendees (according to privacy settings).
8. **Basic moderation** — report content, admin hide/remove, member removal, audit trail.

**Out of scope for v0.1:** real-time chat, AI photo recognition, face tagging, public content discovery, ad system, payments, live streaming, and automatic cross-platform native builds.

## 4. Proposed repository structure

```text
circle/
├── README.md
├── AGENTS.md                  # Strict engineering and visual QA instructions
├── .gitignore
├── .github/
│   └── workflows/            # CI workflows, added incrementally
├── docs/
│   ├── design-system.md
│   ├── mcp-setup.md
│   ├── architecture.md
│   ├── api-contract.md
│   ├── database.md
│   ├── security.md
│   └── milestones.md
├── mobile/                    # Flutter application
│   ├── lib/
│   │   ├── app/
│   │   ├── core/
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── feed/
│   │   │   ├── communities/
│   │   │   ├── groups/
│   │   │   ├── members/
│   │   │   ├── memories/
│   │   │   └── events/
│   │   └── main.dart
│   ├── test/
│   │   └── goldens/
│   └── integration_test/
├── backend/                   # Custom PHP REST API
│   ├── public/index.php
│   ├── src/
│   │   ├── Core/
│   │   ├── Tasks/
│   │   ├── Entities/
│   │   ├── Repositories/
│   │   ├── Controllers/
│   │   └── Middleware/
│   ├── database/migrations/
│   ├── tests/
│   ├── composer.json
│   └── .env.example
└── admin/                     # Vue 3 dashboard (later phase)
```

These directories are a target structure; generate actual project scaffolding before claiming any command is runnable.

## 5. Minimum data model

All community-specific resources must include and enforce `community_id` at the API/query layer, not merely in the UI.

- `users` — identity/account data
- `communities` — private community settings
- `community_members` — user, community, role, approval status
- `invitations` — hashed invite tokens, expiry, uses, creator
- `groups`, `group_members` — subgroup membership
- `posts`, `post_media`, `comments`, `reactions` — community activity
- `albums`, `album_media`, `media_assets` — memories
- `events`, `event_rsvps` — gatherings
- `reports`, `audit_events` — moderation and accountability

Use foreign keys, indexes on tenant and feed queries, UTC database timestamps, migrations, and explicit uniqueness rules. The `users` table is global; access to a user profile must be authorized by membership and profile privacy settings.

## 6. API contract guidelines

Base URL: `/api/v1`. JSON requests/responses unless uploading files. Use stable error shapes, pagination, auth middleware, input validation, and appropriate HTTP status codes.

Proposed endpoints (refine in `docs/api-contract.md` before implementing both clients):

```text
POST   /auth/register
POST   /auth/login
POST   /auth/logout
GET    /me
GET    /communities
POST   /communities/{communityId}/join-requests
GET    /communities/{communityId}/members
GET    /communities/{communityId}/feed
POST   /communities/{communityId}/posts
GET    /communities/{communityId}/groups
GET    /communities/{communityId}/albums
GET    /communities/{communityId}/events
POST   /communities/{communityId}/events
```

Additional admin and upload routes require written contracts and backend authorization rules before use. Never allow client-supplied IDs alone to grant membership or group access.

## 7. Security and privacy are non-negotiable

- Default deny. Every community/group resource request needs server-side authorization.
- Passwords: PHP `password_hash()` with a secure supported algorithm; never store plaintext.
- Token-based mobile authentication with revocation/expiry and safely stored tokens; do not commit secrets.
- Validate all input. Use PDO parameterized statements. Limit upload type, size, and count; verify actual media content.
- Uploaded photos/videos must not be publicly accessible through guessable static URLs. Use authorization-gated downloads or short-lived signed URLs.
- Rate-limit authentication, invitations, uploads, and posting.
- Logs must redact passwords, tokens, private message content, and unnecessary personal data.
- Provide member blocking/reporting capabilities and plan account/content deletion and export.
- Protect against cross-tenant and cross-group access; write tests specifically for these cases.
- No facial recognition or automatic identification of people. Member photo tagging requires consent and an untag option.
- Use test accounts and fictional content during development.

## 8. Local development prerequisites

- Ubuntu/Linux with Git
- Flutter stable SDK and Android SDK/Android Studio
- PHP 8.3+ and Composer
- MySQL 8
- Node.js LTS for the future Vue admin dashboard
- Codex CLI and a GitHub repository

Verify installed dependencies:

```bash
flutter doctor -v
php -v
composer --version
mysql --version
git --version
```

### Initialize the repository

If starting from this README in an otherwise empty repository:

```bash
mkdir -p ~/projects/circle
cd ~/projects/circle
git init
# Copy README.md into this directory if not already present
flutter create --org com.circlecommunity mobile
cd mobile
flutter pub get
flutter run
```

Use a connected Android device or emulator for `flutter run`. The first backend setup will be generated in a separate commit after API contract and database design.

For Android emulator testing, the emulator normally reaches the host's localhost via `10.0.2.2`; physical devices need a reachable LAN hostname/IP, and production requires HTTPS.

## 9. Codex Web + local development simultaneously

One **private GitHub repository** is the source of truth. Codex Web and local Codex both work directly on `main`. They do **not** automatically share uncommitted changes. Never create feature branches or pull requests.

**Preferred ownership split:**

| Workstream | Tool/branch | Owner files |
|---|---|---|
| Flutter interface | Codex Web / `main` | `mobile/**` |
| API and migrations | Local Codex / `main` | `backend/**` |
| Contracts and security decisions | Shared review on `main` | `docs/**`, `AGENTS.md` |

Rules:
1. Settle shared API contract and entities on `main` before parallel feature work.
2. One workstream owns a given file at a time. Coordinate ownership before simultaneous Web/local work. Avoid simultaneous edits to lockfiles or shared configuration.
3. Commit completed and verified changes directly to `main`, then push to `origin/main` after successful validation. Never force-push or use destructive Git commands.
4. Run `flutter analyze` and `flutter test` in `mobile/`; run PHP tests from `backend/` once configured.
5. Use `.env.example` for configuration templates and `.env` locally; never commit real secrets.
6. Inspect status and pull the latest `origin/main` before starting. Never overwrite uncommitted changes. If remote changes appear, fetch and reconcile them safely before pushing. Keep tasks small and integration frequent.

## 10. First implementation milestone: a runnable Flutter prototype

**Deliverable:** The Flutter app runs locally with realistic **fictional** data and no production backend dependency.

Screens:
- Welcome / invitation onboarding
- Sign in and sign up UI
- Home feed
- Create post
- Communities / groups list and group detail
- Friends directory and profile
- Memories / albums
- Events / reunion details
- Profile / settings

Requirements:
- Material 3 with a premium, warm, nostalgic but modern feel; responsive layout.
- Light/dark themes, accessible contrast, semantic labels, proper loading/empty/error states.
- Feature-based folders; Riverpod, go_router and Dio abstractions.
- Repository interfaces with mock implementations. Do not fake network completion as real backend data.
- Navigation works between all MVP screens; basic user interactions work using mock state.
- Widget tests for navigation and feed/group rendering.
- Run `dart format .`, `flutter analyze`, and `flutter test`; resolve failures or clearly document environmental blockers.
- Commit logical milestones. Do not overwrite user changes.

### Exact initial Codex CLI instruction

Open Codex in the repository root:

```bash
cd ~/projects/circle
codex
```

Paste:

```text
Read README.md first. This repository is the CIRCLE private college community app.

Your immediate assignment is Milestone 1 only: build a runnable Flutter prototype under mobile/ using fictional mock data, following the technology, UI, structure, privacy, and testing requirements in README.md.

1. Inspect the repo and existing changes before modifying anything.
2. If the Flutter project has not been scaffolded, create it under mobile/.
3. Build the navigation and MVP screens in small coherent steps.
4. Use Riverpod, go_router, and repository interfaces with mock implementations.
5. Create AGENTS.md with repository-specific guardrails, and document how to run the prototype.
6. Add widget tests.
7. Run formatting, static analysis and tests; fix failures where possible.
8. Report created files, commands run, test results, and remaining tasks.

Do not add a real API, cloud credentials, Firebase configuration, payments, or AI features yet. Do not modify unrelated files or claim something is tested when it isn't.
```

After the first Flutter prototype is reviewed, begin backend/API work on `main` with coordinated file ownership.

## 11. Definition of done for MVP

- A new invited user can join (after backend integration), await approval, and only access their authorized community.
- Members can view/create posts, comment, react, browse groups, and upload/revisit memories.
- Group-only posts and private photos are never returned to unauthorized users.
- Reunions can be created and joined by RSVP.
- UI handles offline/network failure and empty states gracefully.
- Tests cover community isolation, subgroup visibility, token expiry, invalid uploads, and core app navigation.
- Basic deployment instructions, backup plan, and moderation workflow are documented before inviting real users.

## 12. Roadmap

- **M1:** Flutter mock UI + navigation + tests.
- **M2:** API contract + MySQL schema + local PHP auth/membership.
- **M3:** Feed, comments, reactions, and groups integration.
- **M4:** Private media storage + memories/albums.
- **M5:** Events, membership moderation, notifications.
- **M6:** Security hardening, small private beta, then wider launch.

**Priority rule:** privacy, reliability, and a delightful experience for the first real college community matter more than feature count.


## 13. Professional engineering standard (mandatory for every Codex task)

Treat the deliverable as a real consumer-grade social application, **not a collection of disconnected mockup screens**.

### Architecture and maintainability
- Follow feature-first clean architecture in Flutter: `presentation/` (screens/widgets/providers), `domain/` (entities/use cases/interfaces), `data/` (DTOs/repositories/data sources). Avoid adding layers without real purpose.
- Make widgets small, composable and strongly typed. Keep business logic out of widgets. Use Riverpod for asynchronous state with explicit loading, failure, empty, and success states; use `go_router` for authenticated navigation and deep links.
- Centralize API client configuration, interceptors, timeouts, retry rules, pagination, and typed error models. No HTTP calls inside UI widgets. Model idempotency for create actions where needed.
- PHP: `declare(strict_types=1)`, PSR-12 formatting, Composer autoloading, DI through explicit constructors, focused Tasks, domain Entities and parameterized SQL repositories. Keep controllers thin. Validate input at trust boundaries. Use transactions when necessary.
- Define an OpenAPI contract (`docs/openapi.yaml`) as shared truth before concurrently implementing Flutter network clients and PHP APIs. Generate or validate clients where useful; do not silently diverge.
- Use database migrations, real FK/index constraints, pagination indexes and safe rollback/migration guidelines. No schema change without a migration.
- Avoid excessive dependencies. Verify current packages and official documentation before installing. Commit dependency lockfiles, but no machine-specific paths or secrets.
- Do not use hardcoded placeholder buttons that appear functional. Either implement the interaction with state and tests, or make its disabled/prototype state obvious.
- Provide meaningful diagnostics, structured redacted logging, tests, reproducible commands, and a concise changelog with each milestone.

### Quality gates
- Dart: `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and integration tests where emulator/device is available.
- UI: widget tests, golden screenshot tests with fixed viewport and fonts, accessibility checks, overflow checks, and manual review on 360×800, 393×852 and tablet layouts; test dark mode and larger text scales.
- PHP: Composer validation, PSR-12 linting, static analysis (PHPStan), PHPUnit or Pest automated tests, authorization tests for cross-community/group leakage, and API integration tests.
- Web admin: TypeScript strict mode, lint/type checks, unit tests, Playwright browser smoke tests. Use Playwright **only** for web UI, not as a substitute for native Flutter emulator testing.
- CI: add jobs for Flutter format/analyze/test, PHP lint/static analysis/test and backend security tests; add web jobs when admin is introduced. Validate before committing and pushing directly to `main`; CI reruns checks on `main`.
- Use security reviews for auth, multi-tenancy, signed media access, rate limits, moderation and retention/deletion. No user-generated media or PII uploaded to external AI/MCP tools without explicit authorization.
- Every delivery reports: scope, screenshots when UI changes, validation commands with real results, risks, and known limitations. Do not create pull requests.

## 14. Design system and pixel-perfect implementation

**Visual direction:** premium, emotionally warm, nostalgic but contemporary; designed for mature college friends rather than a teen-focused short-video network. Avoid a generic social-media clone. Favor quiet typography, generous spacing, carefully selected imagery, meaningful empty states, and polished transitions.

### Tokens (initial proposal; consolidate in `docs/design-system.md`)
- Spacing: 4-point grid (4, 8, 12, 16, 20, 24, 32, 40).
- Corner radius: 8, 12, 16, 24; define semantic usage, not random values.
- Typography: use one properly licensed font family; consistent semantic text styles and line heights. Test Tamil and English text wrapping if localization is added.
- Colors: semantic `primary`, `surface`, `surfaceVariant`, `textPrimary`, `textSecondary`, `outline`, `success`, `warning`, `error`; support WCAG AA contrast for ordinary text where applicable. Never scatter hex literals in feature widgets.
- Components: app shell, navigation bar, primary/secondary button, text field, input feedback, avatar, member tile, photo tile, post card, group card, event card, skeleton, empty/error/loading state, dialog and bottom sheet.
- Images: use fictional or properly licensed photos in development; no arbitrary remote hotlinked images for production. Always preserve aspect ratio and show upload progress/fallbacks.
- Accessibility: touch targets approximately 48 logical pixels or greater where practical, screen reader labels, focus states, keyboard navigation where relevant, text scaling, reduced-motion behavior.

### Visual development workflow
1. Create actual screen specifications and reusable design tokens **before building every page separately**. Document navigation and critical states.
2. If the user provides a Figma link and has authorized access, use the Figma MCP to read frame/component measurements and variables. Otherwise generate an original design system; **Figma MCP does not automatically invent approved product designs or guarantee accuracy**.
3. Build a single polished vertical slice: onboarding → invite access → feed → post detail → comments, with functional mock state and tests.
4. Render target screens on Android emulator/device and capture screenshots at fixed device sizes. Compare them to approved Figma/reference assets or golden baselines; inspect visual differences manually and fix typography, spacing, clipping, alignments, colors and overflow.
5. Maintain golden screenshot tests for stable representative screens and states. Review intentional golden updates instead of blindly accepting diffs.
6. Cover dark theme, keyboard appearance, loading, network failure, long names, zero posts, 100+ posts, oversized photos, dynamic text size and narrow screens.
7. Run interaction testing in the emulator and on a physical Android device before calling the experience production ready. Verify actual app functionality separately from visual similarity.

**Pixel-perfect definition:** measured agreement with an approved design at a specified viewport and rendering environment, plus functional correctness and accessibility; no promise that arbitrary Android/iOS devices render pixel-identically.

## 15. MCP setup for Codex CLI (verified integrations)

MCP gives Codex access to extra tools; **MCP servers are optional integrations, not replacements for Flutter SDK, Android emulator, static analysis, or human design review**. Install only trusted tools after checking their permissions. Run setup on your own computer; this README does not install tools automatically. Configuration normally lives in `~/.codex/config.toml` and is machine-local; it does not get synchronized automatically with Codex Web.

### Recommended servers

| MCP | Purpose | When to use |
|---|---|---|
| **Figma (official)** | Fetch authorized Figma frame layout, components, tokens, and assets for design-to-code work | When an actual Figma design/reference exists; requires login and Figma access |
| **Playwright (Microsoft)** | Inspect and exercise the **web** admin dashboard and web UI via browser automation | For Vue admin later and any supported Flutter web target |
| **Context7 (Upstash)** | Fetch current library/framework API documentation | During Flutter/Riverpod/go_router/Dio and PHP dependency implementation |
| **OpenAI Developer Docs (official)** | Read current OpenAI developer documentation | Optional, only for OpenAI-related integrations |

### Local installation commands

```bash
# Prerequisites: installed/authenticated Codex CLI and Node.js/npm.
# Official Figma remote MCP; browser OAuth may be required.
codex mcp add figma --url https://mcp.figma.com/mcp

# Official Microsoft Playwright MCP (browser testing for web interfaces).
codex mcp add playwright -- npx -y @playwright/mcp@latest

# Documentation MCP (choose this hosted option or follow Context7's current setup).
codex mcp add context7 --url https://mcp.context7.com/mcp

# Optional: official OpenAI developer documentation.
codex mcp add openaiDeveloperDocs --url https://developers.openai.com/mcp

# Inspect registered integrations:
codex mcp list
```

For any integration requesting authentication, follow its official login flow (`codex mcp login <name>` where supported). Check `codex mcp --help` and `/mcp` inside Codex if a server is unavailable. Avoid storing tokens directly in README, tracked TOML, shell history, or repository files. Figma feature availability is subject to account permissions and plan limits.

**Verified docs:**
- Codex MCP: https://learn.chatgpt.com/docs/extend/mcp?surface=cli
- Figma + Codex: https://help.figma.com/hc/en-us/articles/39888629089175-Codex-and-Figma-Set-up-the-MCP-server
- Playwright: https://github.com/microsoft/playwright-mcp
- Context7: https://github.com/upstash/context7/blob/master/docs/clients/codex.mdx
- OpenAI documentation MCP: https://developers.openai.com/learn/docs-mcp

### Critical limitation for Flutter
Playwright and Figma MCP do **not** directly validate native Flutter pixel rendering. Use Flutter's `integration_test`, golden tests, real Android emulator/device screenshots and Flutter diagnostics for native UI. If an optional Flutter-specific MCP integration is added later, first verify its maintainer, package provenance, Codex compatibility and supported tools in current documentation—do not fabricate a server name or installation command.

### Codex Web / Cloud caveat
Cloud tasks run in separate environments and should not assume access to local MCP processes, devices, Figma login sessions, or local MySQL. Configure permitted tools in the cloud environment separately when supported. Keep design references and nonsecret contracts in Git; never upload private college photos or credentials for build convenience.

## 16. Codex delivery protocol and agent prompt

Codex should read `README.md` and `AGENTS.md` on every new workstream. Implementation must be iterative and validated. Never present scaffolded, nonworking screens as complete. If a tool is unavailable, record the blocker and continue with reliable local tooling.

**Recommended first Codex message (replace the earlier milestone-only prompt if using this upgraded guide):**

```text
Act as principal Flutter engineer, product designer, accessibility reviewer,
security-conscious PHP architect and pragmatic technical lead for CIRCLE.

Read README.md completely. Follow sections 13–16 strictly.
Inspect repository and check configured MCP servers; use current framework docs
via Context7 where available. Do not assume MCP servers or Figma designs exist.

FIRST ASSIGNMENT: Build a professional Flutter prototype, not a throwaway demo.
- Establish theme tokens and reusable components in one central design system.
- Create clean feature-based presentation/domain/data architecture.
- Implement onboarding, invitation login, feed, post detail, groups,
  memories, member directory, events and profile with functional fictional data.
- Build real navigation, input validation, testable async state, error/empty/
  loading states and working interactions.
- Maintain consistent spacing and typography; optimize for Android screens.
- Add widget tests and approved golden baselines; include screenshot QA
  instructions and an emulator smoke-test checklist.
- Scaffold docs/design-system.md, docs/architecture.md, AGENTS.md, and CI.
- Run dart format, flutter analyze and flutter test; record actual results.
- Do not claim pixel-perfect match without approved reference screenshots and
  verified comparison at specified viewport.
- Do not implement production accounts, APIs, or cloud media uploads yet.
- Do not commit secrets or use real classmates' data.

Before coding: provide a short execution plan and examine the existing files.
After coding: report changed files, executed checks, screenshot review status,
limitations, and the next incremental task. Work autonomously within scope.
```

### Review rubric
For milestone acceptance check: coherent end-to-end flows, visual consistency, clean architecture, robust state handling, meaningful tests, documented setup, safe handling of private data, and a reproducible working build. Reject vague "done" claims without a command result or working demonstration.

## 17. Implementation readiness and definition of done

A task is **done** only after acceptance criteria are met, not when code is merely generated.

**Required checks before every Flutter UI commit**
```bash
cd mobile
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

**Required checks before backend commits** (once backend scaffolding exists)
```bash
cd backend
composer validate --strict
composer install
composer test
composer analyse
```
Create `composer test` and `composer analyse` scripts when initializing the backend; never pretend they already exist. Run PHP syntax checks and API integration tests as appropriate. All claims of passing tests must be backed by actual command execution. CI should use pinned SDK versions and lockfiles.

**Mandatory code review checklist**
- All authenticated API queries scope data by `community_id`, with explicit membership checks, including media and search.
- Feature modules expose interfaces and typed models; UI widgets never call raw HTTP or SQL directly.
- Use immutable state where practical, dependency injection, pagination and cancellable requests.
- Handle offline/network errors, retries without unsafe duplicate writes, form validation and unknown backend responses.
- Prevent hard-coded credentials, public media access, verbose personal-data logging and unbounded file uploads.
- Supply semantic accessibility labels, text scaling, responsive layouts and clear empty/error states.
- Include a screenshot or state-specific golden comparison for each meaningful UI change. Report deviations.
- Ensure tests cover business behavior, state transitions, authorization denial and tenant isolation.

**Repo collaboration policy**
- Always work on `main`; never create feature branches or pull requests. Pull `origin/main` before starting, commit completed and verified work directly to `main`, and push after successful validation. Fetch and reconcile remote changes safely before pushing.
- The first task owns `mobile/` only. Later backend tasks own `backend/`; changes to `docs/api-contracts/` require review by both tracks.
- Keep commits focused and reviewable. Never use force push or destructive Git commands. Preserve all uncommitted changes and coordinate file ownership between concurrent Web/local workstreams.
- `AGENTS.md` records executable development rules; `README.md` defines product and implementation requirements.
- Record architectural decisions in `docs/adr/` using decision, context, alternatives, consequences.

## 18. First-run setup and execution order

1. Check `git status`, the repository structure and available toolchain (`flutter doctor -v`, `dart --version`, `php -v`, `node -v`).
2. Check `codex mcp list`; set up only MCP servers the user authorizes. Credentials, OAuth login and device/emulator interactions require the user's participation when prompted.
3. If no Figma design exists, first create `docs/design-system.md` and original in-app mockups; do not claim a Figma-derived pixel-perfect result.
4. Build the **first vertical slice**: welcome → invitation entry (mock verification) → home feed → post detail → comments, using fictional local data. Then extend navigation to groups, memories, directory and events.
5. Run formatter, analyzer and tests; capture emulator screenshots if an emulator is available. Document any validation that could not run.
6. Commit completed and verified changes directly to `main` and push to `origin/main` after successful validation. Include a concise delivery report with checks and screenshots. Never create feature branches or pull requests.

**Do not launch or collect real classmates' personal information until** invite-only access, private media delivery, abuse reporting, content deletion, account deletion, security checks and a simple privacy notice are implemented and reviewed.
