# CIRCLE engineering rules

Read README.md and CODEX_START_PROMPT.md before a new workstream. Phase 1 owns mobile/ and supporting documentation only; do not introduce backend services or real personal data.

- Keep feature presentation/domain/data boundaries; inject repositories with Riverpod. Use go_router for navigation. Never perform HTTP in widgets.
- Use central semantic theme tokens and accessible, responsive widgets. Label mock access explicitly. No credentials or public media URLs.
- Preserve user changes. Use `main` only for all work and pushes, per the owner's instruction. Do not create feature/topic branches. This overrides older branch/PR workflow instructions in README.md and CODEX_START_PROMPT.md. Never force-push or overwrite unrelated work.
- Before starting, inspect status and pull `origin/main` safely. Never create pull requests or use destructive Git commands. Commit completed, verified changes directly to `main`, then fetch and reconcile any remote changes safely before pushing `origin/main`. Never overwrite or automatically stash uncommitted changes. When Web and local work overlap, coordinate ownership of files and lockfiles before editing them.
- Run Flutter format, analyze, unit/widget/golden tests. Record actual results and device limitations. Golden creation is not approval.
- Never claim production authentication, tenant security, approved visual equivalence, or native device validation from mocks or web tests.
