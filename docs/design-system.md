# CIRCLE design system

No Figma reference has been provided. Everything here is an **original** Material 3 design direction. Product scope and screens: README §3–4.

## Supplied brand identity (owner, 25 October 2026)

- Name: **CIRCLE**.
- Tagline, exactly: **MY CIRCLE. BILLION MEMORIES.**
- Canonical artwork: `mobile/assets/brand/circle-brand.png`, copied byte-for-byte from the owner's supplied PNG. Use the complete logo, wordmark and tagline together. Do not redraw, crop or recolour the artwork.
- `core/circle_brand.dart` supplies the shared access-screen lockup and its screen-reader label. The supplied image retains its light background in dark mode.
- Welcome and access forms replace the previous infinity/blur symbols, collage and alternate slogans with this identity. General product copy and group-type icons are not brand marks.
- Android/iOS launcher assets and web icons are mechanical size exports of the complete artwork. Regenerate on Windows with `mobile/tool/generate_brand_icons.ps1`; no additional dependencies or image generation are used.
- The existing semantic screen palette and component kit below remain the UI system; the supplied artwork is an intentional branded image asset.

## Direction: "Luminous Pure Minimal" (owner choice, 23 Oct 2026)

Source: `~/Downloads/DESIGN.md` ("Luminous Pure Minimal"). It **replaces** "Warm Keepsake":

- **Overall:** pure white, airy and calm, with high trust. Hierarchy comes from hairline borders, whitespace and type weight, not colour.
- **Colour:** monochrome. Deep indigo for actions and selection, slate greys for text and icons, no saturated accents.
- **Chat:** keeps the Instagram Direct patterns, restyled in the same palette.

**One deliberate deviation:** the design's default body text is 14px. CIRCLE keeps everyday reading text at **16px** (`body-lg`) for ages 15–75 (README §4.0) and uses 14px for secondary text. Everything else follows the file.

## Ease of use first

README §4.0 is binding for every component:
- one primary action per screen;
- advanced options collapsed behind "More options";
- labels on bottom-bar icons;
- every gesture (swipe, double-tap) also reachable from a long-press menu;
- undo snackbars instead of confirmation dialogs for reversible actions, with confirmation only for destructive or cascading ones;
- quiet, non-modal offline and error banners;
- indigo (never alarm red) badges, only for things that need the user;
- prototype labels once per screen (the header shows "CIRCLE • PREVIEW").

## Tokens (`mobile/lib/core/design.dart`)

| Token | Light | Dark (derived) | Use |
|---|---|---|---|
| Canvas and cards | `#FFFFFF` | `#0F1117` / `#151821` | Everything sits on white; no grey stacking |
| Hairline | `#EAEDF5` | `#262B38` | Card, input, sheet and chip borders; list dividers |
| Primary indigo | `#1B223C` (pressed wash 6%) | `#DCE1FF` | Primary buttons, selected chip, nav pill, FAB, filled ♥ |
| Titles | `#1A1D2E` | `#F0F1F7` | Headlines, titles, labels |
| Body | `#475467` | `#C3C9D5` | Reading text |
| Captions | `#667085` | `#98A2B3` | Timestamps, placeholders, metadata, unselected nav |
| Indigo wash (`calmContainer`) | `#F1F2F6` | `#1E2333` | Pills, avatars, selection tiles |
| Recessed | `#F6F7FA` | `#181B24` | Comment bubbles, illustration tiles |
| Spacing | 4, 8, 12, 16, 20, 24, 32, 40 (`Space`); 16px mobile margins (`CircleInsets`) | | |
| Radius | checkbox 4 · small 8 · input 10 · button/tile 12 · card/menu/FAB 16 · sheet/dialog 24 · pill (chips, avatars, badges) (`CircleRadius`) | | |
| Max content width | 640px (`ReadingPane`) | | |

**`CircleAccents`** keeps its `heart`, `calm` and `sage` names, so no screen code changed. All three now resolve to indigo/slate washes. Groups are told apart by **icon and name**, never by colour.

**Depth:** cards use the 1px hairline. The design's micro-shadows are too faint to notice on devices and render as hard rings in goldens, so they're omitted. Floating buttons are flat indigo.

Never put hex literals in feature widgets. Use `ColorScheme` or `CircleAccents.of(context)`.

## Typography

**Plus Jakarta Sans** is bundled at weights 400/500/600/700 (SIL OFL, `PlusJakartaSans-OFL.txt`). Headlines use negative tracking.

| Style | Size / line height / weight / tracking |
|---|---|
| displaySmall (headline-xl) | 32/40/700, −0.03em |
| headlineLarge (headline-lg) | 26/34/700, −0.025em |
| headlineMedium (headline-md) | 22/28/600, −0.02em |
| headlineSmall · titleLarge (headline-sm) | 18/24/600, −0.015em |
| titleMedium | 16/22/600 |
| bodyLarge · bodyMedium (body-lg, the readable default) | 16/24, −0.01em, `#475467` |
| bodySmall (body-md) | 14/20 |
| labelLarge / labelMedium / labelSmall | 14/20/600 · 12/16/600 · 11/14/500 |

Plus Jakarta Sans has **no Tamil glyphs**. When localization is added, bundle a licensed fallback (e.g. Noto Sans Tamil).

## Components in this design

- **Buttons:**
  - Primary: indigo, white label, 48px tall, 12px radius.
  - Secondary: white with a hairline border and charcoal label.
  - Ghost: text only, indigo.
- **Cards:** white, hairline border, 16px radius.
- **Inputs:** 48px tall, white, hairline border, 10px radius; focus is a 1.5px indigo border.
- **Chips:** white with a hairline border and slate label; selected = solid indigo with white text.
- **Selection controls:** a checked checkbox, radio or switch is solid indigo.
- **Lists:** rows separated by 1px hairline dividers (`CircleRow`), not one card per row.
- **Navigation bar:** white. The selected item is a solid indigo pill with a white icon and a charcoal label; unselected items are caption slate.

## Welcome screen (owner's Stitch design, 23 Oct 2026)

Layout follows the Stitch "Welcome" export, top to bottom:
1. ∞ logo avatar, the "CIRCLE" wordmark, and "PRIVATE GROUPS. SHARED MEMORIES."
2. A keepsake collage on an indigo-wash panel:
   - two illustrated "photos" ("Sunday supper" ♥ and a hillside);
   - a "Living room · Invite only" tile;
   - a "Calm and private" pill;
   - stacked avatars.
3. The headline "Your people. Your moments. Your circle."
4. The calm explanation.
5. Three promises: private to chosen groups; no follower counts, metrics or ads; clear for ages 15–75.

**Buttons:**
- Primary **Create account →**: registration (mobile + password, ADR 0005).
- Secondary (white, hairline) **Log in**.
- A quiet **Explore fictional circles** link (prototype tour only).
- One preview note.

**Changes from the export:**
- Fictional illustrations instead of hotlinked AI photos of people.
- A **Log in** button added, since the export only had "Get Started".
- **"I Have an Invite" is deferred.** A new preview account has no groups, so it would always say "link not recognised". It returns with backend invites, following README §4.3 flow 1 (link → create account → join).
- **The legal footer is omitted** until Community Values and the privacy notice exist; no placeholder links.

**Large text:** the headline's scaling is capped at 1.3× so words never break mid-word. The decorative collage doesn't scale; screen readers get its description. Body text, promises and buttons scale fully.

## How to build any screen (the design kit)

All design values live in two files. Screens only use them; they never invent their own.

| Need | Use | File |
|---|---|---|
| Colours | `Theme.of(context).colorScheme` and `CircleAccents.of(context)` | `core/design.dart` |
| Colour family for a group or status | `CircleTone` (`neutral`, `strong`, `calm`, `heart`, `sage`, `surface`; monochrome in this design) with `circleToneColors()`; for a group type, `circleTypeTone(type)` | `core/circle_components.dart`, `workspace/presentation/group_visuals.dart` |
| Text | `Theme.of(context).textTheme.*` (scale above). Never set a font size or family | `core/design.dart` |
| Spacing | `Space.xs…large` | `core/design.dart` |
| Page padding | `CircleInsets.page` (lists with a FAB), `CircleInsets.form` (details, forms) | `core/design.dart` |
| Corner radius | `CircleRadius.small/tile/inner/card/sheet/pill` | `core/design.dart` |
| Page intro | `CircleHeading`: one calm line plus a muted explanation. The header already names the page | `core/circle_components.dart` |
| Section header | `CircleSectionTitle('Members (5)')` | ″ |
| Person or group avatar | `CircleInitialAvatar(name:/icon:, tone:, size: small/medium/large/hero, active:)`. `active` draws the "active now" dot (`CircleAccents.activeDot`, indigo with a surface ring), used only in 1:1 contexts | ″ |
| Audience, role or status label | `CirclePill(label, icon:, tone:, semanticsLabel:)`; roles via `CircleBadge` | ″ |
| Empty or error state | `CircleEmpty(title, message, action)` | ″ |
| Illustration placeholder | `CircleCover` (flat recessed tile); photo placeholders use `CircleSceneTile` (icon + label; "+N more" replaces the label on the last tile) | ″ |
| Mock label (once per screen) | `PreviewLabel` | ″ |
| Feedback, Undo, confirm | `runCalmly`, `showCircleMessage`, `confirmCircleAction`, `undoWith`, `undoDetached` (Undo that still works after its card is gone) | ″ |
| Bottom sheets inside the shell | `showModalBottomSheet(..., useRootNavigator: true)`, so sheets sit above the nav bar and FAB | Flutter |
| List row with hairline divider | `CircleRow(child: ListTile(...))` | ″ |
| Lists, switches, tabs, dialogs, sheets, menus, chips, badges, snackbars, tooltips | Plain Material widgets: the theme styles them. Don't override per screen | `circleTheme()` |

**Enforced by a test:** `mobile/test/design_system_guard_test.dart` scans `lib/`. It fails (naming the file and line) on any of these:
- a hex colour or `Colors.*` outside `core/design.dart`;
- a font size or family;
- a numeric radius or numeric padding;
- a gradient;
- a raw `CircleAvatar`;
- a network image.

To change the look, change the tokens, never a single screen.

## Components

**Existing:**
- `ReadingPane`, `CircleCover` (solid recessed tile, no gradient), `CircleHeading` and `CircleEmpty`;
- shell header: viewer avatar → You, "CIRCLE • PREVIEW" eyebrow, tab title; bottom bar with a lavender active pill; flat indigo pill FAB ("Create Memory", "New group");
- Home: "All" + group chips with type-coloured dots; selected chip filled indigo;
- Memory card:
  - 44px avatar, name, audience pill (lock + "Root › … › Group"), relative time;
  - text, illustration, ♥ count + comment count, latest-comment preview (recessed);
  - Love · Comment · Save row, which wraps at large text;
- group visuals: type icons and the group header with tappable breadcrumbs;
- the memory card;
- the 5-tab shell (Home · Chats · Groups · Events · You).

**To build by phase:**
- group tree item: true parent → child order, stepped indent up to 10 levels;
- role badge (Owner/Admin), member tile;
- invite sheet (link, expiry/usage under "More options", reset);
- join-request tile and invitation card (Accept/Decline);
- photo tile/viewer, comment;
- chat inbox tile: avatar with active dot, name, preview or "Seen"/"Sent 2h", unread bold + dot, mute/pin icons;
- Chats/Requests tabs, request card (shared groups, Accept/Delete/Block);
- message bubble: incoming/outgoing, grouped runs with corner shaping, reply preview, reactions, edited marker, "Seen"/"Seen by…" with semantic labels;
- shared-content card (Memory/event/poll/album inside chat), composer (text, emoji, photo, poll);
- poll card (options with result bars, closes-in, voters);
- event card, RSVP control with guest stepper;
- skeletons, empty/error/offline/no-access states, dialog, bottom sheet (create menu, poll creation).

## Screens

The screen inventory (A1–I3), key flows and required states are in README §4.2–4.4. Every screen needs:
- skeleton loading;
- an empty state with a next action;
- error with retry;
- an offline banner;
- a no-access/removed state;
- handling for long text;
- dark mode and 2× text.

## Design references (exploration only, not approved)

- **Concept canvas "CIRCLE UI concepts":** 8 clickable phone screens: Home, invite landing, groups tree, group space, chats inbox, 1:1 conversation, family event with RSVP + guests, create poll.
- **"Luminous Pure Minimal"** (`~/Downloads/DESIGN.md`): the **adopted** direction (see above).
- **Stitch export "Warm Keepsake Minimal"**: the previous direction (linen, lavender/coral/teal), now superseded. Its welcome-screen *layout* is still used.
- **Stitch project "CIRCLE — private groups app":** an earlier "CIRCLE Calm" evergreen design system, now superseded.
- **Mobbin** (once authenticated): real-app references for Instagram Direct, invite/onboarding and RSVP patterns. Never copy proprietary designs.

## Accessibility

- ≥ 48 px touch targets.
- Screen reader labels with context. For example, "Love Mira's memory" rather than a bare "Love". Include message status like "Seen by 3 people", poll results and breadcrumb levels.
- Decorative text is never read twice.
- Visible focus, text scaling to 200 %, reduced motion (no essential animation).
- WCAG AA contrast for text and chat bubbles.
- Password-manager autofill on access forms.

## QA

- Test at 360×800, 393×852 and 900×1100, in light and dark, with 2× text, deep breadcrumbs (10 levels), long group/member names and 100+ items.
- Golden tests load bundled Plus Jakarta Sans and Material Icons at a fixed viewport.
- Baselines are provisional until human review. They're generated on the CI platform (**Windows**), so Linux/macOS runs show pixel differences; regenerate goldens on Windows only.
- Native screenshot approval is separate.
