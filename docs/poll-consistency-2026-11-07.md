# Poll consistency audit and fix — 7 November 2026

Used Product Design audit guidance and the Hugeicons MCP catalog to review ballot icon meaning. Retained the existing Lucide family, as Hugeicons guidance requires consistency with an established icon library. Evidence: the owner's screenshot and fresh fictional Flutter captures of the current poll and event cards, then revised captures. No private device access or production data was used.

1. Embedded poll before — inconsistent. Two ellipsis menus split post/poll management. Uncontained question and controls look separate from the shared Memory post; the question uses the larger page-heading role. Repeated zero counts and a voter link with no voters add noise. Privacy text sits too close to the button and outer reactions. Supplied screenshot also shows globally heavy text; the device's font/accessibility settings are unverified.
2. Event comparison — clearer grouping. Thin rounded outline, lavender identity area,18px title, white detail region and contained footer establish one shared card hierarchy.
3. Revised poll — corrected. Same outline/header/body structure, ballot icon,18px question and14px option labels. One embedded post menu; its Open poll and settings entry and each poll header open the exact live ballot, preserving management for multiple ballots. Standalone screens retain their poll menu. Empty polls omit repeated per-option zero counts and empty voter links; the true summary, selected/closed/hidden states, vote action and quieter12px privacy note remain. Padding separates card and Memory footer.

Bold Text and200% scaling remain enabled. Layout checks cover normal/Bold Text phones and narrow dark200%, plus existing detail/form/tablet/privacy tests.25focused tests pass; analyzer clean. Existing vote/session guards and server batching remain; no backend/SQL changes. Full Windows verification pending. Physical-device equivalence and the installed font settings remain unverified. A new client build is required.

Full comparison: design-previews/poll-consistency-2026-11-07/comparison.jpg. Before/after files live alongside it.
