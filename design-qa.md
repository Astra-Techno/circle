# Poll consistency QA — 7 November 2026

Source target: existing event invitation, freshly captured at docs/design-previews/poll-consistency-2026-11-07/before/event.png, plus the owner's supplied poll screenshot.
Implementation: after/poll-card-home-selected-393-light.png in the same directory. Combined comparison: comparison.jpg.
Native Flutter renders393×852 logical pixels/density1, light theme with fictional selected poll/event. Content differs deliberately between the two card types. Bold Text captures393×1100 and320×1100 at200% dark preserve accessibility preferences. This is a component consistency correction, not a browser prototype.

Typography: event/poll title role18px, options14px, caption12px; native/corrected Inter policy preserved. Spacing:12px shell corners,16px body/header padding, separate outer footer gap. Colors: existing lavender primaryContainer, white/semantic surface, outlineVariant and purple action. Icons: real library ballot icon, no generated raster UI or custom drawings. Copy: true counts/results only, empty voter link omitted, privacy note remains; removed instruction line stays absent.

History/findings: uncontained controls, page-heading-sized question, duplicate menus and repetitive empty counts corrected. Post menu and tappable card header preserve exact poll management. Combined before/event/after comparison and focused Bold Text renders inspected;25focused checks pass. No actionable P0/P1/P2 visual mismatch remains. Native-device font rasterization remains a P3 acceptance check; no live/device claim.

final result: passed
