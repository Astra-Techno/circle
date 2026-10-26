# Visual review — Android beta 1.0.6

These are Flutter widget renders with shadow painting enabled, bundled fonts and fictional API fixtures. They show the signed-in three-tab layout; they are not physical-device screenshots or approved Windows golden baselines.

- [Home, light](home.png)
- [Groups, light](groups.png)
- [You, light](you.png)
- [Home, dark](home-dark.png)
- [Groups, 360px wide at 200% text](groups-large-text.png)

Standard renders use 393×852 logical pixels. The large-text render uses 360×800. Images are exported at 2× resolution. The narrow large-text layout keeps the create action in a fixed footer, makes decorative introductions compact and retains readable group names. All seven signed-in rendering checks passed, including Home at tablet width. Six populated preview-mode renders were also inspected.

Measured token contrast: primary/white 9.26:1, selected navigation text/lavender 7.30:1, caption/white 4.97:1. These are selected token calculations, not a claim that every possible image or native screen has been audited.
