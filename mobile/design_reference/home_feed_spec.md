# Home reference measurements and implementation review

Reference discovered in this repository: `home_feed.png`, 852 × 1846 raster pixels.
Review base: `fc495575fae1faead62644d6e6c47b76f49b5e12`.
Requested phone viewport: 393 × 852 Flutter logical pixels. Raster-to-logical
scale is approximately 2.168; this is not proof of the original device DPR.
The reference includes OS status/home-indicator artwork; widget renders contain
app content without drawing fake system chrome. Font identity cannot be proved
from pixels: retain bundled Plus Jakarta Sans and the existing Circle artwork.
The blueprint's numeric proposals are guidance, not measured pixel truth.

| Component | Reference estimate (logical pixels) | Implemented / measured |
|---|---:|---:|
| Header logo | ~39 square, ~16 left | 40 square, 16 left |
| Header app-content height | ~48–56, excluding system region | 56 |
| Composer pill height | ~39–40 | 48 minimum to retain accessible tap area |
| Quick-action tile | ~84 × 49 on phone | 84.25 × 52; grows with scaled text |
| Quick-action icon | ~21–24 | 24 |
| Photo mosaic | ~2.8 width / height | 2.8 in list cards; detail/chat defaults preserved |
| Card horizontal margin | ~7–8 | 8 |
| Card corner | ~16–20 | existing 16 token |
| Image corner | ~9–12 | existing 12 photo token |
| Dock | floating capsule, ~48–64 high | 64 high; safe area; 640 maximum width |

Exact fonts, gradients, some icon stroke widths and system inset dimensions
remain estimates. The app preserves minimum 48-pixel interactive targets,
readable text roles and real capability state (Video visible but disabled).
Search/bell/chat and all five dock actions keep their real routes. The reference
Share glyph is not substituted for the existing reaction-picker behavior.

## Responsive behavior

The former Home `ReadingPane` capped all widths at 720: on a 1280-wide tablet
this left 280 logical pixels unused on each side. Home now fills its available
width, with one column below 840 and two natural-height chronological columns
from 840 upward. Portrait 800 uses an 800-wide list; landscape 1280 uses paired
640-wide card slots. Composer caps at 720, dock at 640. Forms retain ReadingPane
constraints. CircleAdaptivePane already uses a 320–420-wide list plus remaining
detail width above 840; its selection/navigation logic is unchanged.

## Acceptance and evidence

- Real Flutter captures at 393×852, 800×1280, 1280×800.
- Same frozen fictional account/date, bundled fonts, loaded Lucide font and
  awaited asset decoding for before/after captures.
- No layout exceptions at target sizes or 320-wide / 200% text checks.
- Create, reactions, comments, photo viewer and navigation remain tested.
- Measurements and comparison artifacts: `docs/design-previews/home-reference/`.
- Windows golden baselines remain unchanged; Linux renders and changed layouts
  are not evidence of baseline approval or native Android/iPhone acceptance.
- Fictional names/text/photos, emoji fallback and absent system chrome differ
  from the reference. Home keeps production Memories rather than inserting mock
  event/poll cards. Thus whole-image differences are diagnostic, not a claim of
  pixel-perfect equivalence. Physical-device and human visual approval remain.
