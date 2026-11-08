# Home Feed Visual Comparison Report

## Image Dimensions
- Reference: 852x1846
- Actual: 852x1846

## Pixel Metrics
- Mean pixel difference: 36.14 / 255
- Max pixel difference: 255 / 255
- Pixels with >10 difference: 36.69%

## Visual Artifacts
- `home_feed_overlay.png` — 50% blend of reference and actual
- `home_feed_difference.png` — amplified pixel differences (bright = mismatch)
- `home_feed_side_by_side.png` — reference and actual side by side

## Interpretation
- Mean diff < 5: Excellent match (font rendering, antialiasing only)
- Mean diff 5-15: Good match, minor layout differences
- Mean diff > 15: Significant visual differences need investigation
- Mismatch > 20%: Major layout or content mismatch

## Notes
- Photo content will always differ (test uses fictional scenes vs real photos)
- Font rendering varies by platform (Windows ClearType vs iOS)
- Status bar content (time, signal) will differ
- Focus comparison on **geometry**: card positions, spacing, alignment
