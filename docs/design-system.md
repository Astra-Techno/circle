# Original CIRCLE design

No Figma reference was provided. This is an original Material 3 direction: warm paper surfaces, deep evergreen actions, amber archive illustrations, quiet editorial headings and generous spacing. Use the locally bundled Roboto family (license in mobile/assets/fonts/LICENSE.txt), no remote fonts or images.

Tokens live in mobile/lib/core/design.dart: 4/8/12/16/20/24/32/40 spacing; 8 input, 12 compact tile, 16 card, 24 hero radii. ColorScheme defines primary, surface, text, outline and error for light/dark; success and warning use semantic theme extensions when needed. Material icons, 48px targets, max 720px reading width, scrollable screens, system text scaling and system theme by default.

Screen specification: welcome uses an archive illustration and one invitation CTA; invitation explains mock access and validates a visible demo code; feed uses an editorial community header, composer CTA and chronological cards. Detail exposes full text, toggles and comments. Supporting tabs use consistent cards and detail routes. Profile controls theme and ends the demo session.

States: repository-driven loading/progress, retryable error, empty feed invitation to write, invalid invite feedback, unknown resource fallback. All write actions update in-memory mock state only. No upload controls imply real media delivery.

QA: test at 360x800, 393x852 and 900x1100, light/dark and 2x text. Golden tests load bundled Roboto and Material Icons at a fixed viewport. Baselines are provisional until human review. Native screenshot approval remains separate.
