# Home Feed Visual Comparison Report

## Image Dimensions
- Reference: 852x1846
- Compared raster: 852x1846 (actual scaled to the reference)

## Pixel Metrics
- Mean pixel difference: 36.66 / 255
- Max pixel difference: 255 / 255
- Pixels with >10 difference: 39.51%

## Visual Artifacts
- `home_feed_overlay.png` — 50% blend of reference and actual
- `home_feed_difference.png` — amplified pixel differences (bright = mismatch)
- `home_feed_side_by_side.png` — reference and actual side by side

## Interpretation
- These are raw screenshot differences, not a layout acceptance score.
- Different fictional content, photos, system chrome and emoji rendering confound whole-image metrics.
- Verify component geometry separately; baseline generation is not visual approval.

## Notes
- Photo content will always differ (test uses fictional scenes vs real photos)
- Font rendering varies by platform (Windows ClearType vs iOS)
- Status bar content (time, signal) will differ
- Focus comparison on **geometry**: card positions, spacing, alignment
