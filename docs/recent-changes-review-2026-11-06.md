# Recent changes review — 6 November 2026

## Scope and checkout

Safely fast-forwarded main from `6a65e62` to `925d386` (five commits,12 files,657 insertions/523 deletions). No local user changes existed. This review changes documentation only; it does not repair or deploy app code.

## Working map

- `3ece273` refreshes shared horizontal insets to12px, makes invitations full-width, overlaps Circle/profile avatars with covers, introduces the InCircles label, and splits Profile into Your Memories/Saved tabs. Shared insets affect forms/authentication as well as root pages.
- `da4cfa7`, `ab7a4f9`, `c7d763a` repair formatting, the Circle events-title lint and then route syntax. Routes retain internal `/groups/...` names while more visible strings say Circle.
- `925d386` replaces Circle cards/staggered entry animation with compact cover-led rows, inline member/event counts, avatar stacks, activity and an unread dot. Detail adds member/role/privacy/request/report pills and Chat/Invite/Events/Polls/Create/Settings shortcuts. Search, hierarchy collapse, pending memberships and exact-group membership checks remain in source.
- InCircles is a presentation name for existing subgroups, not a new data model or permission inheritance. Existing tab navigation still pushes full-page Chat/Events and restores the previous content tab on return.
- Profile renders its cover/header outside the old card, places Edit profile beside the name, and mounts the saved query only when Saved is selected. Own Memories still filter the loaded workspace page and retain Load older Memories; this is not a new author-specific server query.
- No backend, SQL, API contract, dependency, typography-family, signed-image renewal or bottom-dock implementation changed. Version remains1.0.33+38 and markerSocial2.1, so these strings alone cannot identify whether this later redesign is installed.

## Findings, ordered by impact

1. **High — Profile tabs conflict with the shared theme.** `circle_you.dart:114` adds a non-scrollable TabBar without an alignment override; `core/design.dart:585` defaults tab alignment to start, which Flutter allows only for scrollable bars. Reproduced locally: `TabAlignment.start is only valid for scrollable tab bars.` Profile-related flows fail in tests. Compilation/upload success does not validate this widget; exact release-device behavior has not been inspected. Set an alignment compatible with the chosen bar and verify both tabs, profile editing and large text.
2. **High — Circle detail actions exceed available width.** `group_detail.dart:374` lays up to six individually padded actions in a non-flexible Row. CI reports135px overflow on a296px content width and212px in the route matrix. It also fails large-text group-photo/member tests. Reflow or adapt the controls while preserving48px targets, all permitted actions and readable labels.
3. **Medium — Paste-invite discovery is conditional now.** Circles no longer has its direct Open an invite link button. The remaining inbox button (`contact_invitation_inbox.dart:258`) appears only when the received list is empty. A user with pending invitations loses this visible paste entry. Direct deep-link routes remain. The changed tests now visit the route directly, so they no longer verify the original pasted-code journey. Keep a persistent inbox entry and test the journey with both empty and populated inboxes.
4. **Medium — New Chat/Events shortcuts omit capability checks.** Header Chat and Events actions are unconditional, while the existing tab content uses liveChat/liveEvents gates; Polls still checks livePolls. Server-off configurations can show shortcuts to unavailable features. This is a presentation consistency issue, not evidence of an authorization bypass. Apply capability checks consistently.
5. **Integration — Baselines and journey expectations are not integrated.** Latest Windows quality run42157644292 has712 passed/40 failed/1 skipped. Failures include golden differences, the actual Profile assertion/action overflow, and tests still expecting the previous Saved/create control journey. Review/correct behavior first, update journey tests, then review Windows baselines; do not accept all failures as cosmetic. Shared12px insets explain changes even in auth goldens.
6. **Maintainability — Local dimensions escape the shared tokens.** New avatar sizes/overlaps and40px icon surfaces/20px icons/2px gaps are defined in feature files. The existing guard passes because it does not cover all size properties. Consolidate these dimensions when repairing the affected components; no broad token refactor is necessary.

## Verification and release distinction

- Local analyzer: **No issues found**.
- Focused local suite (design guard, Profile, group/profile photos, headers, chrome, Circle experience): **47 passed,24 failed**. Includes Windows-baseline comparisons run on Linux; these counts are not directly comparable to full Windows CI. Functional Profile assertion and layout failures reproduce independently of image comparison.
- Latest full Windows run42157644292 at925d386: **712 passed,40 failed,1 skipped**. Logs inspected for actual exceptions and failing cases.
- iOS workflow42160445820 at925d386: **success**. This review checked workflow status, not its IPA/checksum, Apple processing, installed build or physical-device acceptance. No new build was triggered.
- Backend and production behavior were not retested; no backend code changed. Existing media/query optimizations and known Android signing blocker remain.

## Next implementation batch

Correct Profile alignment and Circle-action reflow first; restore persistent invite paste discovery and capability-aware shortcuts. Update affected Saved/create/paste journeys, run focused checks and full Windows comparison, then review refreshed baselines. Only after that verification should a new identifiable app version/build be delivered. No app fixes are included in this review.
