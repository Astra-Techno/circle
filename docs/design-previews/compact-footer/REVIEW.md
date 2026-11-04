# Compact footer correction

The previous fix colored the bottom padding but retained its height. With a 34px iPhone bottom inset the footer measured 98px: a 64px navigation row plus 34px padding.

The navigation row now has a 48px minimum and bottom clearance is capped at 16px. The same test device now measures 64px total. The surface extends to the screen edge; left/right safe areas remain respected. Intrinsic row sizing still allows larger text to grow.

| Theme | Before (98px) | After (64px) |
| --- | --- | --- |
| Light | [Before](before-light.png) | [After](after-light.png) |
| Dark | [Before](before-dark.png) | [After](after-dark.png) |

Validation: the light/dark geometry test fails on the old 98px layout and passes after the correction. All 16 focused chrome, header/form, scroll-header and design guard checks pass. Flutter analysis reports no issues. These are widget renders; physical iPhone acceptance is pending.

Source version: 1.0.28+32. Account interface marker: Social 1.2.
