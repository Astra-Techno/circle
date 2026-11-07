# Selected poll card visual QA — 7 November 2026

Source: docs/design-previews/poll-card-selected-2026-11-07/selected-reference.png.
Implementation: docs/design-previews/poll-card-selected-2026-11-07/poll-card-polls-selected-393-light.png.
Combined comparison: docs/design-previews/poll-card-selected-2026-11-07/comparison.jpg.

Native Flutter rendering, not a browser prototype. Source852×1846 normalized proportionally to393px width; implementation393×852 density1. Light theme, one pending selection. Fictional labels/two options differ deliberately from source names/three options; actual UI supports2–12 options. Polls list includes its existing create button; embedded Memory examples include real outer post controls. Owner-requested removal of instruction line overrides the generated source.

Required surfaces reviewed: native/correctly named Inter typography with regular16px option labels and existing heading scale; white/purple/lavender semantic tokens; compact rows with48px targets, radio/checkbox alignment and counts; real vector icons without rasterized UI; live copy/state rather than invented votes. Source contains no artwork requiring generated assets. Source/implementation full comparison and focused card regions inspected.

History: initial option backgrounds hid Material ink and triggered Flutter assertions; changed to Material surfaces. Narrow200% layouts stack counts and wrap summaries without overflow. Added fresh Memory refresh so voting/closing/creation persist between listings. Removed requested instruction line. The mock omits Add option/closed/multiple/privacy states; production preserves these existing permission-controlled behaviors.

Verification: six inline-voting listing checks and existing poll/provider/design tests pass; light/dark phone/tablet200% renders inspected. Anonymous/hidden results and scope guards retained. No native-device/server acceptance inferred from fictional rendering.

No actionable P0/P1/P2 visual issues remain. Follow-up P3: compare native iOS font rasterization on the next app build.

final result: passed
