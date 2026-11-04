# Compact footer correction

The previous fix colored the bottom padding but retained its height. With a 34px iPhone bottom inset the footer measured 98px: a 64px navigation row plus 34px padding.

The navigation row now has a 48px minimum and bottom clearance is capped at 16px. The same test device now measures 64px total. The surface extends to the screen edge; left/right safe areas remain respected. Intrinsic row sizing still allows larger text to grow.

| Theme | Before (98px) | After (64px) |
| --- | --- | --- |
| Light | [Before](before-light.png) | [After](after-light.png) |
| Dark | [Before](before-dark.png) | [After](after-dark.png) |

Validation: the light/dark geometry test fails on the old 98px layout and passes after the correction. All 16 focused chrome, header/form, scroll-header and design guard checks pass. Flutter analysis reports no issues. These are widget renders; physical iPhone acceptance is pending.

Follow-up: labels reduced from 12px/16px line height to 11px/14px. The same total clearance is distributed equally above/below the navigation row so icon/label groups are centered. Profile now uses the signed-in account's authenticated PersonAvatar (24px), with initials when unavailable. Latest after captures show this revision. Geometry assertions cover centered groups and aligned avatar/icon centers; compact 64px maximum remains verified at normal text scale.

Avatar/profile checks:19 pass, covering authenticated bytes, photo deletion, cache/session isolation, large member lists and 200% text.

Source version: 1.0.28+33. Account interface marker: Social 1.3.
