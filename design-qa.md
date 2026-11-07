# Event form and card visual QA — 7 November 2026

Source: docs/design-previews/event-selected-2026-11-07/selected-reference.png.
Implementation: same directory/event-form-filled-393-light.png and event-card-events-393-light.png.
Combined comparison: same directory/comparison.jpg. Responsive contact sheet: review.jpg.

Native Flutter implementation, not a browser prototype. Source is a paired two-surface generated concept, normalized proportionally to786px total width. Implementation captures393px wide at density1; form viewport393×852 and list393×852 (layout matrix also393×1100,320×1100,900×1100). Fictional names, event dates/counts and UTC test-device zone differ deliberately. Existing global header/dock are outside the redesign scope. Separate controls preserve actual timezone conversion rather than hardcoding the mock's Asia/Kolkata.

Required fidelity surfaces: established native/corrected Inter family with18px card titles and regular detail text; lavender semantic primaryContainer, white canvas and thin outline; rounded12px card/date badge with grouped timing/location/footer; real library icons and deferred authenticated cover images (source has no artwork); real title/venue/status/counts and permission-controlled actions. Full combined source/render comparison and form/card details inspected.

History: restored a readable18px card title and thin outer border after first render. At200% text, footer actions wrap and timing/venue remain visible. A narrow test locator now scrolls lazy content into view. Subsequent creation/layout and existing private-media/RSVP checks pass. The chosen source's full-width form fields map to existing shared input tokens and counters; optional advanced settings and errors are retained.

No remaining actionable P0/P1/P2 visual findings. Follow-up P3: native iOS font rasterization and final physical-device comparison. No live-server/device acceptance inferred from fictional Flutter renders.

final result: passed
