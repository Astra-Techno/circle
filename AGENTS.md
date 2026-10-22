# CIRCLE engineering rules

Read README.md and CODEX_START_PROMPT.md before a new workstream. Phase 1 owns mobile/ and supporting documentation only; do not introduce backend services or real personal data.

- Keep feature presentation/domain/data boundaries; inject repositories with Riverpod. Use go_router for navigation. Never perform HTTP in widgets.
- Use central semantic theme tokens and accessible, responsive widgets. Label mock access explicitly. No credentials or public media URLs.
- Preserve user changes and work on a topic branch. Do not merge automatically.
- Run Flutter format, analyze, unit/widget/golden tests. Record actual results and device limitations. Golden creation is not approval.
- Never claim production authentication, tenant security, approved visual equivalence, or native device validation from mocks or web tests.
