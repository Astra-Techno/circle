# Selected Home header — 6 November 2026

The owner selected the first displayed Product Design/Image Gen result, Quiet Wordmark. [Exact selected reference](design-previews/home-header-selected-2026-11-06/selected-reference.png). Implemented its app-owned header in existing Flutter, preserving the original brand asset, supported routes and approved Memory cards.

-32px intact Circle logo and24px native/system-or-Inter semibold wordmark.
- Plain search and notification icons with the real Activity badge and48px touch targets. Removed Home's tonal backing circles; other page headers retain their existing design.
- Neutral avatar composer with16px margins and8px vertical spacing. At enlarged text the prompt can use two lines instead of truncating to one.
- Slim Photo/Event/Poll shortcuts with14/20 regular labels and existing20px icons, capability gates and exact-Circle routes retained.
- Existing floating header scroll behavior, private account avatar and Memory layout remain. No new image loading, network requests, backend/SQL or feature dependencies.

27 focused Home-header/scroll/Memory/design-guard tests passed; includes four layout configurations and all six real destinations against the signed-in fictional server fixture. Initial navigation test used the account-less mock and failed at the live Event form; corrected the fixture, not production behavior. Format251files/zerochanges; analyzer clean. Reviewed four actual Flutter captures:393px light/dark,320px dark200%text and900px light200%text. No native-phone or web-prototype acceptance is claimed.

[Phone](design-previews/home-header-selected-2026-11-06/selected-home-header-393-1.0-light.png), [narrow/dark200%](design-previews/home-header-selected-2026-11-06/selected-home-header-320-2.0-dark.png). Windows full refresh42242137930 passed792tests/1skip; format252files/zerochanges, analyzer and font checks clean. Reviewed all22 Windows baselines:11 intended Home changes,11 unchanged; imported only the11 changed images and verified copied SHA256 values. [Baseline review](design-previews/home-header-selected-2026-11-06/windows-baseline-review.jpg), [reference comparison](design-previews/home-header-selected-2026-11-06/reference-comparison.jpg). No runtime edits followed the passing suite. Installed APK42/iOS1058.1 remain unchanged until a new mobile build is delivered.
