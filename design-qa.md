# Selected compact poll QA — 12 November 2026

Source visual truth: `docs/design-previews/poll-compact-selected-2026-11-12/reference.png`, the first displayed concept selected by the owner. This replaces the earlier lavender-header direction for the shared live poll component.

Implementation: `mobile/lib/features/polls/presentation/live_polls.dart` (`LivePollCard`). This is the existing production Flutter app, not a browser/Sites prototype. Native Flutter widget-renderer captures were used; no physical iPhone/Android or browser verification is claimed.

## Evidence and normalization

- Source:1086×1448 pixels, intended390×520 logical canvas. Poll-region crop `(35,250)-(1053,1206)` normalized to366px wide.
- Implementation:saved390dp viewport,12dp outer insets,366dp component; PNG732×732 at density2, normalized to366×366. Source/implementation represent the same named, saved, single-choice poll with3/12/3 votes and18 voters. Only the poll region is compared; existing author/avatar/social actions remain shared post components.
- Joint full comparison:`docs/design-previews/poll-compact-selected-2026-11-12/comparison.png`.
- Joint focused option comparison:`options-comparison.png` in that folder. Normalization composites transparent capture corners against the white page; source originals are retained.
- Additional captures:saved320dp/200% light and dark,900dp/200% dark, pending selection, and hidden anonymous results. `states-comparison.png` groups representative states.

## Comparison history and findings

1. Initial render had an unpainted component body (transparent in isolated captures), a header-covering border, a quieter12px footer than the selected direction, and unused16dp spacing beneath a saved ballot. These were P2 differences.
2. Fixed the explicit semantic surface, continuous foreground outline,15px footer/button roles and conditional action spacing. Captured again; inspected both joint comparisons and responsive/state captures. No actionable P0/P1/P2 visual mismatch remains.

## Required fidelity surfaces

- Typography:18/24 semibold question,15/20 semibold options,15/20 medium poll label/footer,14px result metadata. Existing native Apple system text / Inter hierarchy and accessibility scaling remain enabled. Lines wrap rather than shrink at200%.
- Spacing/layout:one fine outlined shell,16dp inner spacing,12dp option gaps, rounded result rows and integrated background fills; no duplicate separators/bars, lavender banner or unchanged Save button. The implementation reserves real48dp touch targets, so its isolated card is slightly taller than the mock.
- Colors/tokens:white/semantic dark surface, existing purple primary/primaryContainer, neutral outline and caption colors. No new hardcoded feature colors or gradients.
- Images/icons:the card needs no raster content. Existing real `CircleIcons` ballot/check icons are retained; the outlined library check differs slightly from the mock's filled check (P3). Live author photos and social actions are preserved rather than replaced by the fictional Alex avatar.
- Copy/content:actual question/options/counts only. Footer uses votes for single-choice, voters for multiple-choice and View voters only when identities are allowed.12/18 is correctly rounded to67%, rather than the mock's66%. Hidden results never get counts/percentage fills; anonymous polls never get voter identities. Named visibility remains in accessibility semantics without the repeated visible boilerplate.

## Interactions checked

Single-choice submit and persistence; pending change/remove; no write or unchanged Save action for a saved choice; multiple selection; closed/immutable options; anonymous/after-close privacy; failed save preserves pending selection; batched cards on Home/Circle/Profile/Saved/Memory detail/Polls; scoped API behavior remains unchanged. Focused tests and captures found no framework/layout errors.

## Implementation checklist

- [x] Selected first concept implemented through the shared live card.
- [x] Existing API, permissions, vote persistence, management and voter routes preserved.
- [x] Joint source/render comparison and responsive/error states inspected.
- [x] Focused regression/design guards pass; complete functional suite831pass/one existing real-HTTP smoke skip. Analyzer/format clean. No backend/SQL changes.
- [ ] Physical device acceptance/new client build (separate release step).

Follow-up P3: physical-device font rasterization and filled-check icon parity. Windows baseline review remains a separate, previously blocked repository gate; no old golden files were replaced here.

final result: passed
