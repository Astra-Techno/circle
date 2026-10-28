# CIRCLE engineering rules

Start with `PROJECT_STATE.md` and these rules. Read only the README sections, ADRs, contracts and design guidance relevant to the task; their requirements remain binding. README §0 governs implementation/releases and §4.0 governs calm UX. Read `CODEX_START_PROMPT.md` when setup/workflow context is needed, rather than loading the entire kickoff prompt and README for every task. This targeted-reading policy supersedes older instructions to read every document in full. Use fictional data only.

## Efficient workflow — ChatGPT/Codex and Claude

- Keep the current goal and acceptance criteria short. Inspect status/recent diffs and use scoped `rg` searches before opening files. Retain a working map; do not repeat whole-app discovery unless new evidence requires it.
- Use one agent by default. Delegate only when the user or applicable instructions authorize it and independent work justifies the extra context. Give each agent narrow file ownership and avoid duplicated analysis.
- Make the smallest complete change using existing components and APIs. Avoid unrelated refactors, speculative features and repeated visual redesign.
- During implementation run focused checks. At integration/release run the required broader checks below. Repeat passed checks only after relevant edits, failures or unresolved concerns; never save tokens by skipping authorization, privacy or release-integrity verification.
- Build/deploy once per completed, verified batch unless the user requests an immediate build. Documentation-only work does not need an APK or runtime test rerun.
- Keep commentary useful and brief; summarize long tool output and report failures precisely. Final replies should normally state the outcome, validation, blockers and relevant links without repeating the plan or logs.
- Update `PROJECT_STATE.md` at task boundaries with verified state, next work and blockers. Keep it under 60 lines. Distinguish repository state, local unfinished work and live deployment; never infer one from another.

## Engineering and release requirements

- Product vocabulary: the post stream is "Memories", never "feed". Groups nest up to 10 levels. Enforce group rules (roles, owner protection, approval, listed/hidden, parent membership at join and approval, cascade removal without orphaned subgroups, DM eligibility) in domain/controller code with unit tests, never only in widgets. Access is per exact group, never inherited.
- Accounts follow ADR 0005: mobile number + password, OTP later; registration never grants membership. Preview access remains explicitly fictional/local; server access follows the reviewed API.
- Backend (`backend/`, ADR 0006): the owner approved `docs/api-contracts/openapi.yaml` (0.3.0) on 23 Oct 2026. Implement only what the contract describes (planned operations included), keep it in sync, and get both tracks' review for contract changes. Run backend tests only against a dedicated `circle_test` database.
- Keep feature presentation/domain/data boundaries; features never import `app/` or another feature's `data/`. Inject repositories with Riverpod. Use go_router for navigation. Never perform HTTP in widgets.
- Follow the design kit (docs/design-system.md: current direction "Editorial, photo-first" — 8-pt grid, 60/30/10 colour, thumb-zone CTAs, 4 sizes/2 weights; "How to build any screen"). Colours, text styles, spacing, radii and components come from `mobile/lib/core/`. Never hardcode them in a feature. `test/design_system_guard_test.dart` enforces this and must pass. Preview labels are no longer drawn on screen (owner, 28 Oct 2026); keep preview behaviour honest in code and docs. No credentials or public media URLs.
- Preserve user changes. Use `main` only for all work and pushes, per the owner's instruction. Do not create feature/topic branches. This overrides older branch/PR workflow instructions anywhere else. Never force-push or overwrite unrelated work.
- Before starting, inspect status and pull `origin/main` safely. Never create pull requests or use destructive Git commands. Commit completed, verified changes directly to `main`, then fetch and reconcile any remote changes safely before pushing `origin/main`. Never overwrite or automatically stash uncommitted changes. Do not leave shared docs (README, AGENTS, docs/) uncommitted on one machine: other machines and fresh downloads will not see them. When Web and local work overlap, coordinate ownership of files and lockfiles before editing them.
- Run Flutter format, analyze, unit/widget/golden tests, and backend `composer test` / `composer analyse` when backend files change. Record actual results and device limitations. Goldens are rendered on Windows (CI); golden creation is not approval.
- Never claim production authentication, tenant security, approved visual equivalence, or native device validation from mocks or web tests.

- README §0 is the shared rulebook for Claude Code and Codex: truthful capability gates, optional/session-scoped Firebase, stable signing identity, incremented build numbers and coherent immutable download publication. Existing violations do not override those rules. `CLAUDE.md` imports the same sources; keep one canonical rulebook.
