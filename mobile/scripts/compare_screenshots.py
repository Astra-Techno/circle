"""
Screenshot comparison for Circle Home Feed design verification.

Usage:
  python scripts/compare_screenshots.py

Requires: pip install Pillow

Inputs:
  design_reference/home_feed.png         (approved reference)
  design_reference/output/home_feed_actual.png  (rendered Flutter output)

Outputs:
  design_reference/output/home_feed_overlay.png
  design_reference/output/home_feed_difference.png
  design_reference/output/home_feed_side_by_side.png
  design_reference/output/home_feed_report.md
"""

import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont, ImageChops
except ImportError:
    print("Pillow is required: pip install Pillow")
    sys.exit(1)


def load_images(ref_path: str, actual_path: str):
    if not os.path.exists(ref_path):
        print(f"Reference not found: {ref_path}")
        sys.exit(1)
    if not os.path.exists(actual_path):
        print(f"Actual not found: {actual_path}")
        print("Run: flutter test test/home_feed_golden_test.dart --update-goldens")
        sys.exit(1)
    return Image.open(ref_path).convert("RGB"), Image.open(actual_path).convert("RGB")


def resize_to_match(ref: Image.Image, actual: Image.Image):
    """Resize actual to match reference dimensions for comparison."""
    if ref.size != actual.size:
        actual = actual.resize(ref.size, Image.LANCZOS)
    return ref, actual


def make_difference(ref: Image.Image, actual: Image.Image, amplify: int = 10):
    """Pixel difference, amplified for visibility."""
    diff = ImageChops.difference(ref, actual)
    # Amplify differences for visibility.
    return diff.point(lambda p: min(255, p * amplify))


def make_overlay(ref: Image.Image, actual: Image.Image, alpha: float = 0.5):
    """Blend reference and actual at 50% opacity."""
    return Image.blend(ref, actual, alpha)


def make_side_by_side(ref: Image.Image, actual: Image.Image):
    """Place reference and actual side by side with labels."""
    gap = 20
    w = ref.width + actual.width + gap
    h = max(ref.height, actual.height) + 40
    canvas = Image.new("RGB", (w, h), (255, 255, 255))
    canvas.paste(ref, (0, 40))
    canvas.paste(actual, (ref.width + gap, 40))
    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("arial.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
    draw.text((ref.width // 2 - 30, 10), "Reference", fill=(0, 0, 0), font=font)
    draw.text(
        (ref.width + gap + actual.width // 2 - 20, 10),
        "Actual",
        fill=(0, 0, 0),
        font=font,
    )
    return canvas


def compute_metrics(ref: Image.Image, actual: Image.Image):
    """Compute per-pixel difference metrics."""
    import numpy as np

    ref_arr = np.array(ref, dtype=float)
    act_arr = np.array(actual, dtype=float)
    diff = np.abs(ref_arr - act_arr)

    mean_diff = diff.mean()
    max_diff = diff.max()
    # Percentage of pixels with >10 difference in any channel.
    mismatch_mask = diff.max(axis=2) > 10
    mismatch_pct = mismatch_mask.mean() * 100

    return {
        "mean_pixel_diff": round(mean_diff, 2),
        "max_pixel_diff": int(max_diff),
        "mismatch_pct": round(mismatch_pct, 2),
        "ref_size": ref.size,
        "actual_size": actual.size,
    }


def write_report(metrics: dict, output_path: str):
    """Write a markdown comparison report."""
    report = f"""# Home Feed Visual Comparison Report

## Image Dimensions
- Reference: {metrics['ref_size'][0]}x{metrics['ref_size'][1]}
- Actual: {metrics['actual_size'][0]}x{metrics['actual_size'][1]}

## Pixel Metrics
- Mean pixel difference: {metrics['mean_pixel_diff']} / 255
- Max pixel difference: {metrics['max_pixel_diff']} / 255
- Pixels with >10 difference: {metrics['mismatch_pct']}%

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
"""
    with open(output_path, "w") as f:
        f.write(report)
    print(f"Report: {output_path}")


def main():
    base = Path(__file__).parent.parent / "design_reference"
    ref_path = str(base / "home_feed.png")
    actual_path = str(base / "output" / "home_feed_actual.png")
    out_dir = base / "output"
    out_dir.mkdir(exist_ok=True)

    print("Loading images...")
    ref, actual = load_images(ref_path, actual_path)

    print(f"Reference: {ref.size}, Actual: {actual.size}")
    ref, actual = resize_to_match(ref, actual)

    print("Generating overlay...")
    overlay = make_overlay(ref, actual)
    overlay.save(str(out_dir / "home_feed_overlay.png"))

    print("Generating difference map...")
    diff = make_difference(ref, actual)
    diff.save(str(out_dir / "home_feed_difference.png"))

    print("Generating side-by-side...")
    sbs = make_side_by_side(ref, actual)
    sbs.save(str(out_dir / "home_feed_side_by_side.png"))

    print("Computing metrics...")
    try:
        metrics = compute_metrics(ref, actual)
    except ImportError:
        print("numpy not available; skipping metrics. pip install numpy")
        metrics = {
            "mean_pixel_diff": "N/A",
            "max_pixel_diff": "N/A",
            "mismatch_pct": "N/A",
            "ref_size": ref.size,
            "actual_size": actual.size,
        }

    print("Writing report...")
    write_report(metrics, str(out_dir / "home_feed_report.md"))

    print("\nDone. Review outputs in design_reference/output/")


if __name__ == "__main__":
    main()
