# Home reference implementation review

Base commit: `fc495575fae1faead62644d6e6c47b76f49b5e12`.
Branch: `ui/home-reference-tablet-alignment` (owner's uploaded task explicitly
requests a dedicated branch and PR; do not merge automatically).
Approved source: `mobile/design_reference/home_feed.png` (852×1846).
Measurable specification: `mobile/design_reference/home_feed_spec.md`.

## Implementation

- Compact original-logo header and 48px-minimum composer with readable input type.
- Four pastel quick actions; Video remains visibly disabled, existing routes/gates retained.
- Ordinary text Memories use normal body text rather than an automatic quote panel.
- Compact list photo mosaics match the reference's approximately 2.8 aspect ratio;
  detail/chat photo grid defaults and fullscreen viewer behavior are retained.
- Full-width Home on portrait tablets; chronological two-column rows at 840+.
  Composer capped at720, floating dock at640, forms remain constrained.
- Dock keeps all five actions and safe-area behavior; Create retains its semantic label.
- Review font loader now loads Lucide, so missing-glyph squares no longer pass
  unnoticed as visual baselines. Captures await visible image decoding.
- Date labels use the existing injected clock for deterministic review fixtures.

## Evidence

| Viewport | Before | After | Actual geometry |
|---|---|---|---|
|393×852|[Phone](before-393x852.png)|[Phone](after-393x852.png)|[JSON](after-393x852.json)|
|800×1280|[Portrait tablet](before-800x1280.png)|[Portrait tablet](after-800x1280.png)|[JSON](after-800x1280.json)|
|1280×800|[Landscape tablet](before-1280x800.png)|[Landscape tablet](after-1280x800.png)|[JSON](after-1280x800.json)|

[Overlay](comparison/home_feed_overlay.png),
[difference](comparison/home_feed_difference.png),
[side by side](comparison/home_feed_side_by_side.png),
[comparison report](comparison/home_feed_report.md).

Before/after use the same fictional account, fixture date and corrected font/
asset-loading setup. Baseline code was exported from the recorded base commit
into an isolated temporary directory. The legacy timestamp formatter used host
time; final code uses the injected clock. No screenshots were fabricated.

At393 wide, header64→56, logo48→40, composer56→48, quick-action72→52,
dock72→64; mosaic4:3→2.8. The first Memory's outer slot moves232→184.
At1280 wide, Home replaces a centered720-wide column with paired640-wide slots;
800 portrait uses the full800-wide list. See JSON for actual bounds.

Raw whole-image mean difference: **61.57→36.66 /255**.
Pixels differing by more than10: **49.79%→39.51%**.
These are diagnostic metrics, not pixel-perfect acceptance scores: the images
contain different people, text, photographs and system chrome.

## Verification

- Flutter analyzer: clean.
- Final focused layout/navigation/Memory/design checks:60 passed, including
  system safe-area bounds, 320-wide/200% text and phone/tablet capture assertions.
- Full Flutter run:682 passed,1 skipped,22 screenshot comparisons differ.
  This full run preceded the final injected-clock/test-only safe-area additions;
  the final focused run covers those changes.
- Existing Windows golden PNG baselines were not overwritten on Linux.
- Existing auth, creation, reaction/comment, viewer, route and capability tests
  ran; widget/fake API checks do not establish production/native-device acceptance.

## Remaining discrepancies / unavailable validation

- Existing golden approvals must be reviewed/rendered on Windows; comparisons
  currently fail and are not described as green CI.
- No tablet reference image was found. Tablet validation uses the documented
  responsive rules and real Flutter renders at requested widths.
- Fixture names/content/photos differ; some fictional scenes are placeholders.
  Emoji fallback also differs from native Android/iOS. Native OS status/home
  indicator artwork is absent from widget captures; no fake system UI is drawn.
- Exact reference font/gradient/stroke values cannot be proved from pixels.
  Accessible48px controls remain taller than some apparent reference controls.
- Production Home keeps its existing Memories data and existing reaction picker;
  no fake event/poll cards or nonfunctional Share action were introduced.
- No attached Android tablet/iPhone; physical-device visual approval remains.

## Changed files

- `mobile/lib/core/design.dart`: shared Home dimensions.
- `mobile/lib/core/circle_components.dart`: compact shared header spacing.
- `mobile/lib/app/circle_experience.dart`: original-logo size and compact capped dock.
- `mobile/lib/features/memories/presentation/circle_memories.dart`: composer/actions/tablet rows.
- `mobile/lib/features/memories/presentation/memory_card.dart`: normal text, spacing and injected clock.
- `mobile/lib/features/memories/presentation/memory_photos.dart`: opt-in list mosaic ratio.
- `mobile/test/flutter_test_config.dart`: Lucide font loading.
- `mobile/test/home_reference_review_test.dart`: deterministic captures, geometry and safe areas.
- `mobile/scripts/compare_screenshots.py`: configurable input/output paths and honest metric interpretation.
- `mobile/design_reference/home_feed_spec.md`: measured/estimated component specification.
- `PROJECT_STATE.md`: handoff; this directory contains before/after evidence and reports.

## Reproduce

From `mobile/` with the repository Flutter toolchain:

```sh
CIRCLE_REVIEW_CAPTURE=after flutter test test/home_reference_review_test.dart
flutter analyze
flutter test test/chrome_review_test.dart test/memories_flow_test.dart test/design_system_guard_test.dart
python scripts/compare_screenshots.py --reference design_reference/home_feed.png --actual ../docs/design-previews/home-reference/after-393x852.png --output-dir ../docs/design-previews/home-reference/comparison
```
