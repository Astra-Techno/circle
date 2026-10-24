# Codex Social App Bootstrap

Run this from the repository root.

It will create:
- `AGENTS.md`
- `.codex/skills/flutter-ui/SKILL.md`
- `.codex/skills/design-system/SKILL.md`
- `.codex/skills/social-feed/SKILL.md`
- `.codex/skills/visual-qa/SKILL.md`
- `.codex/skills/accessibility/SKILL.md`
- `.codex/skills/api-integration/SKILL.md`
- Figma MCP
- Playwright MCP
- OpenAI Developer Docs MCP

> Figma registration is automatic, but the one-time account authorization must still be completed interactively when Codex prompts you.

---

## Windows PowerShell

```powershell
$ErrorActionPreference = "Stop"
$root = ".codex\skills"

$dirs = @(
  "$root\flutter-ui",
  "$root\design-system",
  "$root\social-feed",
  "$root\visual-qa",
  "$root\accessibility",
  "$root\api-integration"
)

foreach ($d in $dirs) {
  New-Item -ItemType Directory -Force -Path $d | Out-Null
}

@'
# Private College Social Network

Build a production-quality Flutter app for a closed community.

## Product principles
- Private by default.
- Only approved members can access group content.
- Memories and relationships are the main engagement loop.
- Mobile-first.
- Keep UX simple.
- Privacy and trust are core product features.

## Primary navigation
- Home
- Memories
- Members
- Reunion
- Profile

## Engineering rules
- Flutter + Dart.
- Material 3.
- Feature-first architecture.
- Keep API logic out of UI widgets.
- Use repository/service separation.
- Use centralized routing and design tokens.
- Reuse components.
- Implement loading, empty, error and populated states.
- Run formatter, analyzer and tests before completion.

## Figma workflow
When a Figma design exists:
1. Read it through Figma MCP.
2. Inspect components, variables, spacing and typography.
3. Reuse existing app components.
4. Implement.
5. Render.
6. Compare.
7. Fix differences.
8. Verify small phone, normal phone and tablet widths.

## Privacy
- Backend membership checks are mandatory.
- Never rely only on client-side hiding.
- Validate community membership, ownership and moderation permissions.
- Protect private media.
- Do not expose private media through unrestricted public URLs.
'@ | Set-Content -Encoding UTF8 "AGENTS.md"

@'
# Flutter UI Skill

- Use Material 3.
- Reuse design tokens and shared widgets.
- Do not scatter arbitrary colors, spacing, radius or font sizes.
- Match approved Figma screens closely.
- Support Android and iOS.
- Support narrow phone through tablet widths.
- Provide loading, empty, error and populated states.
- Keep networking outside widget build methods.
- Use lazy lists and pagination for feeds.
- Use thumbnails for feed media.

After meaningful changes run:

```bash
dart format .
flutter analyze
flutter test
```
'@ | Set-Content -Encoding UTF8 "$root\flutter-ui\SKILL.md"

@'
# Design System Skill

Use semantic design tokens.

Spacing:
4, 8, 12, 16, 20, 24, 32

Radius:
8, 12, 16, 24

Prefer reusable components:
- AppScaffold
- AppButton
- AppTextField
- Avatar
- UserCard
- PostCard
- MemoryCard
- CommentTile
- ReactionBar
- EmptyState
- ErrorState
- LoadingSkeleton
- BottomSheet
- ConfirmationDialog
- MediaGrid
- PollCard
- EventCard

Search for an existing component before creating a new one.
'@ | Set-Content -Encoding UTF8 "$root\design-system\SKILL.md"

@'
# Social Feed Skill

Supported post types:
- text
- photo
- multi-photo
- video
- memory
- poll
- reunion announcement

Support where allowed:
- reactions
- comments
- tagging
- edit/delete
- report/moderation
- group-only privacy

Feed requirements:
- pagination
- refresh
- retry
- loading/empty/error states
- media placeholders

All feed queries must be authorization-scoped on the backend.
Never fetch all private posts and hide unauthorized data only in the UI.
'@ | Set-Content -Encoding UTF8 "$root\social-feed\SKILL.md"

@'
# Visual QA Skill

For important UI work:
1. Read approved design.
2. Render implementation.
3. Compare spacing, alignment, typography, colors, radius, shadows and media crops.
4. Verify narrow phone, standard phone, large phone and tablet.
5. Test loading, empty, error and populated states.
6. Fix differences before completion.

Use Figma MCP for exact design data.
Use Playwright for browser/admin/PWA visual verification.
'@ | Set-Content -Encoding UTF8 "$root\visual-qa\SKILL.md"

@'
# Accessibility Skill

- Maintain readable contrast.
- Label icon-only actions.
- Do not rely on color alone.
- Support sensible text scaling.
- Keep touch targets large enough.
- Provide clear validation and error text.
- Ensure privacy state is understandable.
'@ | Set-Content -Encoding UTF8 "$root\accessibility\SKILL.md"

@'
# API Integration Skill

Architecture:

UI
→ state/controller
→ repository
→ API service
→ HTTP client

Requirements:
- typed models
- centralized auth
- centralized error mapping
- pagination
- secure token storage
- safe retry behavior

Backend must authorize:
- community membership
- role
- ownership
- moderation privileges

Private media must:
- be validated server-side,
- use safe IDs,
- generate thumbnails,
- avoid unrestricted public file paths.
'@ | Set-Content -Encoding UTF8 "$root\api-integration\SKILL.md"

Write-Host "Skills created." -ForegroundColor Green

codex mcp add figma --url https://mcp.figma.com/mcp
codex mcp add playwright npx "@playwright/mcp@latest"
codex mcp add openaiDeveloperDocs --url https://developers.openai.com/mcp

Write-Host ""
Write-Host "Bootstrap complete." -ForegroundColor Green
Write-Host "Restart Codex/VS Code if needed, then complete Figma authorization."
```

---

## macOS / Linux / Git Bash / WSL

```bash
set -e

ROOT=".codex/skills"

mkdir -p   "$ROOT/flutter-ui"   "$ROOT/design-system"   "$ROOT/social-feed"   "$ROOT/visual-qa"   "$ROOT/accessibility"   "$ROOT/api-integration"

cat > AGENTS.md <<'EOF'
# Private College Social Network

Build a production-quality Flutter app for a closed community.

## Product principles
- Private by default.
- Only approved members can access group content.
- Memories and relationships are the main engagement loop.
- Mobile-first.
- Keep UX simple.
- Privacy and trust are core product features.

## Primary navigation
- Home
- Memories
- Members
- Reunion
- Profile

## Engineering rules
- Flutter + Dart.
- Material 3.
- Feature-first architecture.
- Keep API logic out of UI widgets.
- Use repository/service separation.
- Use centralized routing and design tokens.
- Reuse components.
- Implement loading, empty, error and populated states.
- Run formatter, analyzer and tests before completion.

## Privacy
- Backend membership checks are mandatory.
- Never rely only on client-side hiding.
- Validate community membership, ownership and moderation permissions.
- Protect private media.
EOF

cat > "$ROOT/flutter-ui/SKILL.md" <<'EOF'
# Flutter UI Skill
- Use Material 3.
- Reuse tokens/components.
- Match approved Figma screens closely.
- Support phone through tablet widths.
- Implement loading/empty/error/populated states.
- Keep networking outside build methods.
- Paginate feeds.

Run:
```bash
dart format .
flutter analyze
flutter test
```
EOF

cat > "$ROOT/design-system/SKILL.md" <<'EOF'
# Design System Skill
Spacing: 4, 8, 12, 16, 20, 24, 32
Radius: 8, 12, 16, 24

Prefer reusable:
AppScaffold, AppButton, AppTextField, Avatar, UserCard, PostCard,
MemoryCard, CommentTile, ReactionBar, EmptyState, ErrorState,
LoadingSkeleton, BottomSheet, ConfirmationDialog, MediaGrid, PollCard, EventCard.
EOF

cat > "$ROOT/social-feed/SKILL.md" <<'EOF'
# Social Feed Skill
Support: text, photo, multi-photo, video, memory, poll, reunion announcement.
Support reactions, comments, tagging, edit/delete, report/moderation and group-only privacy.
Use pagination, refresh, retry and proper remote-data states.
Backend queries must be membership-authorized.
EOF

cat > "$ROOT/visual-qa/SKILL.md" <<'EOF'
# Visual QA Skill
Read approved design, render implementation, compare carefully, verify phone/tablet widths,
test all UI states, and fix differences before completion.
Use Figma MCP for design data and Playwright for browser/admin/PWA QA.
EOF

cat > "$ROOT/accessibility/SKILL.md" <<'EOF'
# Accessibility Skill
Maintain contrast, semantic labels, usable tap targets, text scaling,
clear errors and understandable privacy states.
EOF

cat > "$ROOT/api-integration/SKILL.md" <<'EOF'
# API Integration Skill
Use UI → controller/state → repository → API service → HTTP client.
Use typed models, centralized auth/errors, pagination and secure token storage.
Backend must authorize membership, role, ownership and moderation.
Protect private media and never rely only on client-side access control.
EOF

codex mcp add figma --url https://mcp.figma.com/mcp
codex mcp add playwright npx "@playwright/mcp@latest"
codex mcp add openaiDeveloperDocs --url https://developers.openai.com/mcp

echo "Bootstrap complete. Complete Figma authorization if prompted."
```

---

## After Installation — Paste This Into Codex

```text
Read AGENTS.md and every SKILL.md under .codex/skills before making code changes.

Confirm that you will follow:
- flutter-ui
- design-system
- social-feed
- visual-qa
- accessibility
- api-integration

Then inspect the repository.

Do not immediately rewrite the project.

First report:
1. current Flutter architecture,
2. reusable components already present,
3. routing/state-management approach,
4. API structure,
5. missing design-system foundations,
6. privacy/security risks,
7. recommended implementation sequence.

Use Figma MCP whenever an approved design exists.
Use Playwright MCP for applicable web/admin/PWA QA.
Run formatter, analyzer and relevant tests after implementation.

Primary product areas:
Home, Memories, Members, Reunion, Profile.

Critical privacy rule:
No community post, comment, media, member data or memory may be returned to
a user who is not an authorized member of that community.
```

---

## Recommended First Design Sequence

```text
1. Login / Join Community
2. Home Feed
3. Create Post / Memory
4. Members Directory
5. Reunion Dashboard
6. Profile
```

For each design:
- use Figma as source of truth,
- reuse design tokens,
- reuse shared Flutter widgets,
- implement all remote-data states,
- test responsive behavior,
- perform visual QA before completion.

---

## Verify Installation

These files should exist:

```text
AGENTS.md
.codex/skills/flutter-ui/SKILL.md
.codex/skills/design-system/SKILL.md
.codex/skills/social-feed/SKILL.md
.codex/skills/visual-qa/SKILL.md
.codex/skills/accessibility/SKILL.md
.codex/skills/api-integration/SKILL.md
```

Also confirm Codex can see:
- Figma MCP
- Playwright MCP
- OpenAI Developer Docs MCP
