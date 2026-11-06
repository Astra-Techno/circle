# Memory footer alignment — 6 November 2026

Owner screenshot shows the selected heart painting at the top of its button while counts, comment and save icons sit on the center line. The shared action button constrained the Text to a48px-high box but did not align its painted glyph inside that box.

The shared Memory footer now centers action content. Selected reaction glyphs use a24px visual box, fitted native emoji and the shared reactionGlyph typography role; glyph scaling follows icons while count labels continue to respect accessibility text size. All buttons retain at least48px touch targets, tooltip/selected semantics, actual counts, reaction picker/summary, comments and save persistence. Reaction/count and comment/count pairs wrap together. Applies to Home, Circle, Profile, Saved and other uses of CircleMemoryCard.

Used Product Design screenshot-to-code guidance for this scoped existing Flutter component, and the live Hugeicons MCP catalog for thumbs-up/comment/bookmark references. The Hugeicons plugin explicitly directs projects with another icon library to retain it; existing Lucide names were verified in the installed flutter_lucide package. No icon-library migration, web prototype, replacement assets or externally generated screen is claimed.

Three new selected-heart layout tests reproduced the defect before the fix, checking the actual emoji visual box rather than just the button bounds. Corrected renders reviewed at393px/light,320px/dark/200%text and900px/light/200%text. Fictional test assets do not establish native-device appearance. Captures: [phone](design-previews/footer-alignment-2026-11-06/aligned-footer-393-1.0.png), [narrow](design-previews/footer-alignment-2026-11-06/aligned-footer-320-2.0.png), [tablet](design-previews/footer-alignment-2026-11-06/aligned-footer-900-2.0.png).

Final Memory/reference/design-guard suite:34tests passed. Analyzer clean; format251files/zerochanges. No backend changes. Installed APK42/iOS1058.1 do not contain this subsequent source fix; a new mobile build is required to deliver it.
