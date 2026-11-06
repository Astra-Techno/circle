# Latest owner Memory reference — 6 November 2026

The owner supplied Reddit timeline/detail screenshots after the Facebook-style reference. Applied the new visual structure to existing production Flutter shared Memory cards, rather than reproducing unrelated Reddit capabilities.

- Inset16px media with16px outer corners, existing aspect ratios and private-image loading preserved.
- Thin1px post separators,16/24 regular body text and18/24 semibold short text posts/opening paragraphs. A heading is derived only from a short standalone text post or explicit first paragraph of at most160characters; content and paragraphs are preserved, not duplicated or rewritten. Full detail starts expanded.
- Stadium-outline reaction/count and comment/count pills, explicit zero counts and a trailing save pill. Visual40px outlines sit inside48px touch targets. Real reaction chooser/summary, comments and persisted save remain; pairs wrap together.
- Shared across Home, Circle, Profile, Saved, other-member profile and detail. White light surfaces, native Apple/corrected Inter, existing Lucide and Circle purple retained. No downvote/repost/public-share/ad implementation or backend/API changes.

Used installed Product Design screenshot guidance and live Hugeicons MCP searches for thumbs-up/comment/bookmark, retaining the existing icon family per Hugeicons plugin instructions. No externally generated screen, web prototype or native-device acceptance is claimed.

Local verification:35 Memory/reference/design-guard checks passed, including paragraph/heading/detail integrity, rounded-media geometry on Home/detail/member, centered narrow/tablet footer at200%text, actual reactions/comments/saving and unsent-comment Reply/Cancel preservation. Analyzer clean. Eight Flutter captures saved and reviewed across normal/dark/narrow/tablet views and text-only detail. Windows image baselines require refresh for the intended layout change; completing separately.

[Phone](design-previews/reddit-reference-2026-11-06/aligned-footer-393-1.0.png), [narrow/dark200%](design-previews/reddit-reference-2026-11-06/aligned-footer-320-2.0.png), [text detail](design-previews/reddit-reference-2026-11-06/reference-text-detail-393-1.0-light.png).

Source update only. Installed APK42/iOS1058.1 remain the previous layout until a subsequent mobile build is delivered. Loading-recovery backend fix3eaf891 still requires its separate backend deployment; this visual change does not establish that production Retry errors are resolved.
