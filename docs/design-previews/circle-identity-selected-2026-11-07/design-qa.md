# Circle identity visual QA — 7 November 2026

Source visual truth: docs/design-previews/circle-identity-selected-2026-11-07/selected-reference.png.
Implementation: docs/design-previews/circle-identity-selected-2026-11-07/circle-actions-393-1.0-bold-false.png.
Combined focused comparison: docs/design-previews/circle-identity-selected-2026-11-07/comparison.jpg.

Native Flutter component implementation, not a browser prototype. Viewport393×1100 logical pixels, density1, signed-in fictional owner/light theme. Reference1436×1096 normalized proportionally to393px width; implementation region cropped215..500px to compare app-owned group identity/actions. The surrounding existing cover/dock are outside the selected component. Mock name differs deliberately to keep fictional data; no exact pixel equivalence claimed. Full capture and focused combined comparison inspected.

Findings: no remaining actionable P0/P1/P2 visual differences for this component.
- Typography: native Apple/corrected Inter policy preserved, compact role badge, regular14px action/metadata labels. Reference's heavier generated name is interpreted using the app's established heading token.
- Spacing/layout: side-by-side role badge, unobtrusive metadata, two rows/three columns normally.12px corners and8px gaps. Full touch targets intentionally give metadata more height than the static image.
- Colors: white surface, neutral recessed tiles, existing lavender/purple Chat and role badge tokens; no new palette or gradients.
- Image quality: reference contains standard outline UI icons only; real library icons render sharply. No rasterized UI, custom artwork or copied private photos.
- Copy: all six actions preserved; real member count/role/name and existing InCircles destination. No added unsupported features.

History: narrow200% Bold Text clipped Memory when measured width omitted part of horizontal padding; measurement now includes full padding. Subsequent four-size layout checks pass with no label truncation. Metadata locator corrected to target the exact Circle header, excluding tablet sidebar links.

Interactions: existing UI6 journeys and photo tests pass; exact-group link destinations and capability gates preserved. Normal/Bold Text and200% phone/tablet captures reviewed. No native-device acceptance claimed.

Follow-up P3: inspect actual iOS system font rendering on the next device build.

final result: passed
