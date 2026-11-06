# Reference-inspired Memories — Social 2.4

Version **1.0.36+42** implements the owner's attached Facebook post reference in the existing Flutter app. The target is the post's content hierarchy: compact author identity, quiet metadata, full-width photography, clean white sections and icon/count actions. Circle keeps its private audience, purple accent and supported operations.

## What changed

- Shared Memory posts now use flat white sections and a2px bottom divider. Insets, rounded card outlines and the padded image frame are removed.
- Author avatar40px, author name15/20 semibold, private lock/audience/time12/16 and regular caption15/22. Native Apple system text and correctly named Inter faces remain.
- Photos reach both post edges. Known proportions stay within4:5–1.91:1 timeline bounds, unknown/square photos use1:1 and collages use4:3. Full-screen viewing retains original proportions. Decode budgets, signed-link retries and viewport deferral remain.
- Captions expand in place through See more after three lines; full Memory detail starts expanded.
-24px outline thumbs-up/selected real reaction, reaction total/summary, comment/count and saved/unsaved bookmark replace the older text-button row.48px targets, descriptive labels and real controller writes remain. Reaction choices reject a changed account/API/repository/session.
- Home uses one centered720px column on tablets. The same card is used on Circle detail, Your Memories, Saved, other-member profiles and Memory detail. Profile/detail prose keeps its content inset while post media reaches the reading-column edges.
- Shared media corners are square. Other screens retain the established white surfaces, typography, icon family, controls and capability gates.

No backend/SQL, dependency, account model, membership scope or new-feature contract changes. Unsupported Facebook advertising, public-audience, friendship, Reels and Share controls were not added. Existing edit/delete/report, private reply, saving, comments and reaction summaries remain functional.

## Design tools and evidence

Used the installed Product Design screenshot guidance and Hugeicons consistency guidance; the latter directs existing projects to retain their installed icon family. Lucide names were verified in the installed package. Stitch is not connected/authenticated and its host remains blocked; no external MCP-generated design, browser prototype or physical-device acceptance is claimed. This is production Flutter implementation verified with actual widget renders, not a replacement web prototype.

[Single-photo reference render](design-previews/social-2.4/extra/reference-single-photo-393-1.0-light.png) · [Home collage](design-previews/social-2.4/extra/photo--home-393-1.0-light.png) · [Other profile](design-previews/social-2.4/extra/photo--people-mira-393-1.0-light.png)

| Matrix | Light | Dark | Narrow / 200% | Tablet / 200% |
|---|---|---|---|---|
| Main28 routes | [View](design-previews/social-2.4/main-393-1.0-light.jpg) | [View](design-previews/social-2.4/main-393-1.0-dark.jpg) | [View](design-previews/social-2.4/main-320-2.0-dark.jpg) | [View](design-previews/social-2.4/main-900-2.0-light.jpg) |
| Additional32 states | [View](design-previews/social-2.4/extra-393-1.0-light.jpg) | [View](design-previews/social-2.4/extra-393-1.0-dark.jpg) | [View](design-previews/social-2.4/extra-320-2.0-dark.jpg) | [View](design-previews/social-2.4/extra-900-2.0-light.jpg) |

240 screenshots/60 state variants, using fictional data. All contact sheets and representative full-size views inspected. Desktop captures use Inter; actual iPhone SF and phone interactions remain separate. Capability-off/error fixtures are not production-outage evidence. [Manifest and hashes](design-previews/social-2.4/manifest.json).

## Validation at source commit

- Final format/analyzer clean:251 lib/test files checked, zero format changes.
-9 reference regressions pass: real full-width media on Home/detail/member profile; centered tablet column; long-caption expansion; detail readability; actual reaction/save/comment actions; known photo proportions; single-photo specimens across four configurations.
- Final extended/reference capture run13 passed and main route matrix5 passed. Prior focused Memory/shared-card run22 passed after correcting icon-row expectations; previous image-loading budgets and prior audit regressions passed apart from the one stale comment-text locator subsequently corrected.
- Broad local run760 passed/1 skipped/9 image mismatches. Nine existing Home image comparisons require the new Windows baselines;13 other Windows golden cases were excluded by name. No functional failures. The broad run preceded the last spacing-only refinement, which is covered by the final render matrices. Windows full verification remains the integration gate.

## Draft preservation and integration follow-up

A final additional regression reproduced unsent comment loss when Reply inserted
its banner: the new generic inset wrappers needed stable identity for the inline
composer. The wrapper now has a Memory-scoped key. Reply/Cancel retains both text
and composer state; the focused Memory/reference/prior-audit run passes37 tests.
Android candidate41 was never published and iOS42212335842 was cancelled before
upload. The corrected release uses Android42 and a new signed iOS run.

Windows full refresh42212332065 passed782 tests/1skip, format/analyzer clean.
All22 baselines reviewed:12 expected Memory/Home changes,10 unchanged. The
identity fix does not alter default pixels. [Review sheet](design-previews/social-2.4/windows-baseline-review.jpg).
The next normal Windows run verifies the corrected source, including the new
draft regression, against these reviewed baselines.

## Delivery

Reviewed Windows baselines are included with the draft-identity correction. Normal comparison and corrected Android42/TestFlight delivery are pending. Installed apps require this new release to show the design. No native-device or live-hosting deployment acceptance is inferred from source publication.
