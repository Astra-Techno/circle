# CIRCLE design system

## Social 2.3 — interaction and screen audit fixes, 6 November 2026

Retain Social2.2 white canvases, native SF/corrected Inter, Lucide and shared
Memory cards. Apply text scaling once in chat; incoming bubbles use the neutral
recessed surface. Photo viewers own one immersive toolbar and expose only wired
Memory reactions/comments (no unsupported Share). Circle's plus action is named
Memory; nested creation is Create InCircle. Accepted invitations are labelled
Accepted and link entry stays visible with populated data.

Use CircleLayout.stackDetails/treeIndent with actual pane constraints. At narrow
widths or large text, stack Event metadata and keep Circle names readable instead
of reserving fixed side columns. Country-code/mobile fields stack as needed.
CircleFormMetrics.counter reveals limits while editing or near the limit; keep
maxLength enforcement and 48px targets. No text-scale caps. Empty-cover profiles
are compact; gear/Account owns settings, private details and technical device data
use disclosures. Keep capability, permission, session and private-media guards.


## Social 2.2 — white canvases and shared Memory cards, 6 November 2026

Owner requests white backgrounds across light-mode pages. Use the shared surface
for all page canvases, including root shell, Home and chat wallpaper. Keep dark
mode dark and retain distinct form fills/image placeholders/action surfaces.
Home, Circle detail, Profile's Your Memories/Saved and other member profiles use
CircleMemoryCard with a quiet hairline boundary. Reading typography remains the
native Apple/corrected Inter system from Social2.1.

Circle detail is one continuous overview and Memories list. Keep the existing
Lucide action icons; remove the tab strip and duplicate Share/Polls row. Create
opens the exact-Circle Memory composer. Members and InCircles open from header
metadata links; child-Circle creation stays inside InCircles. Reflow icon/card
actions at large text; retain48px hit targets, capability gates, exact-group
access, private media and scoped pagination. Profile's two-view switch remains.
[Audit and verification](circle-design-refinement-2026-11-06.md).


## Social 2.1 — native typography correction, 5 November 2026

Owner's installed-app screenshot rejected Social2.0 typography as too heavy.
Use Flutter's native `CupertinoSystemText` alias on iOS/macOS, with regular400
reading text and medium500 controls. Android/web keep bundled Inter, now exported
with distinct PostScript identities (`Inter-Regular`, `Inter-Medium`,
`Inter-SemiBold`). The previous export gave all three files the same internal
`Inter-Regular` identity; this is a CoreText collision risk, not something the
Windows screenshots or presence-only IPA checks could rule out.

Keep body text16/24; page titles21/28, names15/20 semibold, metadata12/16,
control labels13/18 medium and buttons15/20 medium. Native accessibility bold
text/scaling preferences remain respected. Header artwork28, outline icons20,
quiet action paint36 within unchanged48px hit targets. Photo mosaic corners4;
card corners12. Failed previews use compact recovery affordances with the full
accessible failure description, not a sentence repeated across each tile.

A signed-image403 triggers one authenticated link renewal per resource path;
a second403 or other failures require explicit retry. Missing files/network
failures are not claimed fixed without live evidence. Preserve access checks,
no off-screen fetches, decode budgets and the normal footer clearance.

Current source1.0.33+38/interface Social2.1. Font identity checks run in Windows
CI and both iOS release paths. [Correction record](native-typography-2026-11-05.md).


## Social 2.0 — consistent social UI, 5 November 2026

Owner approved the all-page audit and requested one professional font family.
This direction supersedes the older Roboto/Jakarta pairing and duplicate circle
cards below. Bundle Inter locally (400 regular, 500 medium, 600 semibold); do not
fetch fonts at runtime. Page titles22/28, section headings18/24, names16/22,
reading text16/24, metadata13/18, buttons15/20 medium. Keep normal navigation
labels11/14 and current-user avatar. Reflow navigation into centered rows when
text scaling needs more width; never truncate labels to preserve a compact bar.
Keep the existing bounded device clearance so the footer gap does not return.

Use compact white rows for chats/member/settings lists, photo-led cards for
Memories/events, and CircleEditorLayout for forms. A CircleHeading is a short
16px introduction, not a second page title. Search fields use CircleSearchField
with clear controls and explicit scope for loaded-page searches. Semantic icons
come from CircleIcons (Lucide); do not mix another icon family into the app.
Empty/error panels shrink to their content and use meaningful icons/actions.

Retain CIRCLE purple, the supplied brand artwork, exact-group access and private
media safeguards. Filled send controls use onPrimary. Group Chat/Events tabs
open their scoped destination directly and Back restores the previous content
tab. Inbox filters and event date grouping operate on loaded pages; complete
server-side search/filtering remains a separately reviewed API extension.

Current source1.0.32+37, in-app interface marker Social2.0. Validation/release
status and audit mapping: [implementation record](design-refresh-2026-11-05.md).


## Social 1.1 — headers and forms,4 November2026

Root headers use one title row,32px Home logo,22px outline icons in40px quiet
circles with48px touch targets. Omit the tagline from navigation bars. Keep
Search plus a relevant create/settings action; Home uses Search/Activity.
Detail/auth/invite headers share the Back/title treatment; conversation identity
remains visible. Headers grow with text scaling. Home has compact supported
Photo/Event/Poll shortcuts and no Video placeholder.

Standard inputs follow CircleFormMetrics:56px minimum height,16px text/padding
and field gaps,24px section gaps,16px side margins. Do not fix heights around
multiline/error content. Primary form actions are at least56px tall. Shared
InputDecorationTheme controls borders, labels, hints, errors and icon alignment.
[Full header review and actual captures](design-previews/headers-forms/REVIEW.md).

## Social 1 — 4 November 2026

Owner requests Facebook-inspired consistency across every screen. This supersedes
the older Jakarta/Home-only typography and floating-pill navigation directions.
Use bundled Roboto400/600 exclusively, with CircleTextStyles and the Material
TextTheme sharing the same semantic roles. Body/card text16, page titles24,
sections20, metadata13; use tokens rather than per-screen sizes. All primary
icons are Lucide outlines; selected filled hearts retain their state meaning.
Use the gray/white canvas,12px cards,10px controls and full-width five-tab bar.
Preserve CIRCLE purple, feature/access gates and real data behavior.
[Audit and actual Flutter renders](design-previews/social-system/REVIEW.md).

## Root-page refinement — 3 November 2026

Owner requested applying the current Home styling to the other pages. Chats,
Circles, Events and Profile now use Home's pale `recessed` canvas, rounded
`surface` cards (`CircleSurfaceCard`), 16px root side insets, compact title/metadata
roles and 22px page titles from `CircleTextStyles`. This supersedes the older
divider-only treatment for these root lists. Home's brand, WhatsApp-style chat
conversation, existing detail/form controls and privacy/access behavior remain.
At large text sizes cards grow, chat metadata stacks and filter pills wrap.
The five dock destinations are Home / Circles / Chats / Events / Profile; the
owner replaced the central Create action with Chats. Memory creation stays in
Home's composer. See [review and captures](design-previews/home-style-rollout/REVIEW.md).

## Current direction — Editorial, photo-first (owner, 28 Oct 2026)

The owner approved the "Editorial, photo-first" mock-ups and asked for the whole app to follow them. This **supersedes** the Visual refinement, Soft 3D and Warm Keepsake sections below and the older token, typography and component tables, which are updated to match. README §4.0 (calm, easy UX) still governs.

Five rules, enforced through `mobile/lib/core/design.dart` and the shared kit:

1. **8-point grid.** `Space` is 8 / 16 / 24 / 32 / 48 (`md` = `lg` = 16, `xl` = `section` = 24). The only half-step is `xs` = 4, for icon-to-text micro gaps. Page margins are 24 (`CircleInsets`); tap targets are at least 48, primary CTAs 56 tall.
2. **60 / 30 / 10 colour on Material 3 tokens.** 60% white surface; 30% warm neutral fills (`surfaceContainer`/`recessed` `#F3F0EA`) and ink text (`#1C1B22`, captions `#6B6878`); 10% deep indigo `#3B2E8C` for the one primary action, selection and love. `ColorScheme.fromSeed` with overrides. Photos carry the colour, not chrome. `CircleAccents` keeps its names: `heart` and `calm` are now indigo (a vector heart, never emoji); `sage` is kept only for confirmations.
3. **Thumb zone.** Primary actions sit in the bottom third. The floating dock stays; an open event pins Going / Maybe / Not going in `RsvpBar` above it (a choice the rules refuse, such as Going on a full event, is disabled with the reason shown in the bar, so no snackbar covers the buttons); the live chat composer is pinned below the conversation. At very large text (`CircleLayout.largeTextThreshold`) the chat composer scrolls with the conversation instead.
4. **Four sizes, two weights.** 28 / 20 / 16 / 13 at 400 / 600 only, all in **Plus Jakarta Sans** (owner rejected the serif, 28 Oct 2026). Headlines use −0.02em tracking. Body stays 16.
5. **No overflow.** Screens scroll as one list; one-line labels ellipsize or scale down (`RsvpBar`) instead of breaking words; decorative covers step aside at large text.

Surfaces are flat: no gradients or decorative shadows. Owner30Oct: replace the floating pill dock with a slim full-width navigation bar and a subtle top separator. Buttons are pills (`CircleRadius.button` 24); cards, tiles and menus 16; sheets 24.

Screen patterns:
- **Home:** the logo and "Circle", then "Your circles": round group photos that filter Memories (tap again for all). The brand lockup no longer sits on Home; it stays on Welcome and access screens.
- **Memory:** no card box. Avatar, name and a lock + audience + time line (audience is always visible); full-width photos; an action row with a vector heart, a reaction count that opens the summary, comments, the reaction picker and save; then the caption. Short words-only Memories (≤ 160 characters) read as a quote on a warm panel.
- **Group:** a wide cover, the name as a headline, a caption meta line, then the tabs.
- **Live Chats:** WhatsApp layout in CIRCLE colours (owner, 29 Oct 2026): inbox rows with last message/time/unread; full-screen conversation with its own bar, `chatWallpaper`/`chatIncoming`/`chatOutgoing` tokens, tailed bubbles with the time inside, day chips, long-press options and a rounded composer with a round send button. See `chat-redesign.md`.
- **No demo mode (owner, 29 Oct 2026):** the app always connects to a server. Features the server doesn't offer (Albums, Activity, Memory polls, direct invitations) are hidden — no "Not on the server yet" cards; a direct link shows "This page is unavailable". Fictional data lives only in `mobile/test/support/`.
- **Home:** "Your circles" lists circles with the newest Memories first, then the remaining top-level groups. An indigo ring marks new Memories since this person last opened that circle (kept on the phone per account; opening a circle clears it). An empty Home shows three ticked first steps: create or join a circle, invite your people, share your first Memory.
- **Composer (camera first):** a large "Add photos" tile at the top opens the phone's photos only when tapped, then the caption, "Share with" and "More options"; "Share Memory" is pinned at the bottom, and upload problems show inline above it (never a snackbar over the button).
- **Group page:** five tabs — Memories, Chat, Events, Members, Subgroups (Albums only if the server offers it). At large text the banner steps aside; its refresh/change controls move below the group picture.
- **Lists:** chat inbox, events, attendees, polls, voters and blocked people load the next page as they scroll (`CircleLoadMore`); no Next/Previous buttons. Pull down to refresh.
- **Profiles:** a three-column "Recent Memories" grid (`MemoryGrid`) on people's profiles and "Your Memories" on You, from the Memories already loaded (the API has no author filter yet).
- **Headings:** in-page headings (`CircleHeading`, `CircleIntroPanel`) are 20px, one step below the 28px page title; tab home screens carry no tagline heading. Create actions live in the header +, not in page buttons; lists refresh by pulling down.
- **Events (live):** cards with the date badge; event detail uses icon rows, organiser actions under ⋮ (cover, edit, cancel), and a pinned answer bar whose labels shrink instead of wrapping. Group photos change from camera badges on the picture and banner. Profile covers likewise use a round camera in the cover's corner. Scrolling tab bars use 13px labels and `CircleEdgeFade` so a tab cut by the screen edge reads as "scroll for more"; each tab keeps a 48px target.
- **Event:** details scroll; the answer bar is pinned in the thumb zone. Events list: Upcoming/Past and an icon-only List/Month toggle share one row.
- **You:** a quiet cover with the avatar overlapping it, the name as a headline.

Header: the owner's logo (`assets/brand/circle-brand.png`) and "Circle" on Home, the page name on other tabs, and the tab's create action as a + icon beside the title (no floating action button). No preview labels are drawn (`PreviewLabel` renders nothing; real notices use `CircleNote`). Group lists are one clean list: subgroups indent 24px per level (up to 4) with smaller avatars and no coloured guides.

Windows golden baselines must be regenerated and reviewed for this deliberate change; they are not regenerated on Linux.

## Visual refinement — 26 October 2026

The current pass applies the repository's Flutter UI, design-system, accessibility and visual-QA skills, activated from `CODEX_SOCIAL_APP_SKILLS_BOOTSTRAP.md` under `.codex/skills/`. This section supersedes earlier sizes and navigation treatments where they differ.

Use the richer indigo primary `#46369C` on a white canvas, with the existing lavender/coral/sage families. Keep soft depth restrained: cards and primary buttons use 2px elevation, floating actions 4px. The rounded navigation dock has a shared perimeter and lavender selection indicator, with filled selected icons and readable labels. Keep safe-area handling and at least 48px targets. Above the shared large-text threshold, create actions move from a floating overlay into a full-width footer above navigation.

`CircleIntroPanel` is a reusable, naturally sized lavender introduction. Home places the unchanged full original brand asset at up to 96px beside a short heading; at large text the illustration shrinks and the nonessential decorative subtitle is omitted while the heading continues wrapping. Groups uses a decorative dimensional emblem, a clear search path and root group cards; nested rows retain their ancestry guides. Invitations use a labelled expandable summary, initially open for an account with no groups; existing members can browse their groups without scrolling through invitation cards. Memory headers let author and timestamp wrap on the same line while retaining a separate audience pill. Never crop brand assets, shrink reading text, invent counts, animate continuously or weaken audience visibility to achieve a visual effect.

Validate renders in light/dark mode, empty/populated workspaces, at narrow and tablet widths and with 200% text. Native-device review and Windows golden approval remain separate gates.

## Current depth treatment — Soft 3D (26 October 2026)

The owner requested 3D effects. This adds a shared soft-depth layer to Warm Keepsake on White and supersedes the older flat-only/shadow-free rules below. Preserve the supplied brand artwork, readable typography, white canvas and indigo/lavender/coral/sage palette.

`CircleDepth` in `mobile/lib/core/design.dart` owns all lighting: gentle top-left highlights, tonal gradients, restrained downward shadows and consistent elevations. Gradients may only be defined in that token file; feature widgets consume the shared panel decoration. Cards lift above the canvas; primary buttons and floating actions lower when pressed, and disabled primary buttons have no elevation. Avatar and illustration surfaces share the same lighting. Dark mode uses dark surfaces and shadow colours. Inputs retain explicit borders and focus outlines; neither depth nor colour is the sole indication of an interactive state. No continuous tilt/parallax animation or additional animation controller is introduced.

Access forms use a compact 128px complete brand lockup and shorter spacing so the form is reached sooner. The logo image is never cropped, redrawn or recoloured. Welcome retains its branded composition with a dimensional photo-collage panel. Keep list rows light rather than giving every row a floating card.

Validate populated/empty states, small phones, large text, dark mode and screen-reader labels. Existing Windows golden baselines must be reviewed for this deliberate visual change; do not regenerate them on Linux or describe new visual differences as approved baselines.

## Current direction — Warm Keepsake on White (26 October 2026)

The owner supplied `stitch_circle_private_social_network/{screen.png,code.html,DESIGN.md}` and requested a colourful app with a white background. This supersedes the monochrome direction below. The initial appearance is **light**, independent of device dark mode; the existing appearance setting can still select dark or system.

Keep pure white canvas/cards and indigo primary actions. Shared `CircleAccents` now supplies lavender (`calm`, `calmText`, `calmContainer`), coral (`heart*`) and sage/teal (`sage*`, `activeDot`). Use the accessible darker variants for text, pastel containers for panels, and icon/name labels alongside colour. All values stay in `core/design.dart`.

Welcome follows the supplied composition: owner logo/name/tagline, two photo tiles, Living Room privacy card, quality badge and avatars, centred headline, three promises and account/login actions. The two illustrative photos from the owner's export are bundled in `assets/welcome/`; no public image URLs are used at runtime. Keep login available rather than an inert invite button, and do not introduce placeholder legal links. The waving-hand and person-add decorations are removed from access forms.

The sections below preserve the earlier design rationale and component inventory; the current palette and supplied welcome composition take precedence where they differ.

No Figma reference has been provided. Everything here is an **original** Material 3 design direction. Product scope and screens: README §3–4.

## Supplied brand identity (owner, 25 October 2026)

- Name: **CIRCLE**.
- Tagline, exactly: **MY CIRCLE. BILLION MEMORIES.**
- Canonical artwork: `mobile/assets/brand/circle-brand.png`, copied byte-for-byte from the owner's supplied PNG. Use the complete logo, wordmark and tagline together. Do not redraw, crop or recolour the artwork.
- `core/circle_brand.dart` supplies the shared access-screen lockup and its screen-reader label. The supplied image retains its light background in dark mode.
- Since the editorial redesign (28 Oct 2026) Home opens on "Your circles" instead of the brand lockup; `CircleBrand.home()` remains available. The complete logo, wordmark and tagline stay together wherever the artwork is used (Welcome and access screens).
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
| Canvas and cards (60%) | `#FFFFFF` | `#121116` / `#17161B` | Everything sits on white |
| Warm neutral (`surfaceContainer`, `recessed`) (30%) | `#F3F0EA` | `#1E1C22` | Quote panels, comment bubbles, covers, illustration tiles |
| Hairline | `#ECE8E1` | `#2C2A31` | Inputs, dock, list dividers |
| Primary indigo (10%) | `#3B2E8C` | `#C9C0FF` | The primary action, selection, filled heart, badges |
| Titles (ink) | `#1C1B22` | `#F2EFEA` | Headlines, titles, labels |
| Body | `#34323C` | `#D6D2DA` | Reading text |
| Captions | `#6B6878` | `#A19DAA` | Timestamps, metadata, unselected nav |
| Indigo wash (`calmContainer`) | `#EFECF7` | `#2A2547` | Pills, avatars, selection tiles |
| Spacing | 4 (half-step), 8, 16, 24, 32, 48 (`Space`); 24px page margins (`CircleInsets`) | | |
| Radius | checkbox 4 · small/input 8 · tile/card/menu 16 · button/sheet/dialog 24 · pill (`CircleRadius`) | | |
| Max content width | 640px (`ReadingPane`) | | |

**`CircleAccents`** keeps its `heart`, `calm` and `sage` names. `heart` and `calm` resolve to indigo, `sage` to a muted green for confirmations. Groups are told apart by **icon and name**, never by colour.

**Depth:** flat. `CircleDepth.panel` is a plain warm fill; only the floating dock keeps one soft shadow. Floating buttons are flat indigo pills.

Never put hex literals in feature widgets. Use `ColorScheme` or `CircleAccents.of(context)`.

## Typography

**Plus Jakarta Sans** (SIL OFL, `PlusJakartaSans-OFL.txt`) for everything. Four sizes, two weights (400/600); feature code never adds other weights.

| Style | Font | Size / line height / weight |
|---|---|---|
| displaySmall · headlineLarge · headlineMedium | Jakarta | 28/36/600, −0.02em |
| headlineSmall · titleLarge (app bar titles, section titles) | Jakarta | 20/28/600, −0.02em |
| titleMedium · labelLarge (buttons) | Jakarta | 16/24/600 |
| bodyLarge · bodyMedium (the readable default) | Jakarta | 16/24/400, `#34323C` |
| titleSmall · labelMedium | Jakarta | 13/16/600 |
| bodySmall · labelSmall | Jakarta | 13/16/400 |

Plus Jakarta Sans has **no Tamil glyphs**. When localization is added, bundle a licensed fallback (e.g. Noto Sans Tamil).

## Components in this design

- **Buttons:**
  - Primary: indigo pill, white 16px label, 56px tall with default padding, flat.
  - Secondary: white pill with a hairline border and ink label.
  - Ghost: text only, indigo.
- **Cards:** white, hairline border, 16px radius, flat. Memories have no card box.
- **Inputs:** white, hairline border, 8px radius; focus is a 1.5px indigo border.
- **Chips:** white with a hairline border and slate label; selected = solid indigo with white text.
- **Selection controls:** a checked checkbox, radio or switch is solid indigo.
- **Lists:** rows separated by 1px hairline dividers (`CircleRow`), not one card per row.
- **Navigation bar:** the floating white dock with a hairline and one soft shadow. The selected item is an indigo filled icon with a semibold indigo label (no pill); unselected items are caption grey.

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

## You screen — personal profile and saved Memories

The signed-in shell shows CIRCLE and the current screen title, without a server address. Its avatar follows the signed-in display name. Connection details remain available under Account → Connection. Preview mode retains its explicit CIRCLE • PREVIEW label.

You starts with a raised lavender profile card using the shared CircleDepth.profilePanel lighting, complete name wrapping, and working Edit profile / Your groups actions. Editing a display name uses the existing reviewed PATCH /me operation through the API client and session notifier. Success updates session identity and stored account details; validation and save failures preserve the previous name and keep the form available for retry.

The introductory paragraph is removed. Saved Memories uses a bookmark illustration, concise explanation and Browse Memories action when empty. Populated saved items retain their existing navigation. Settings rows remain simple; unsupported live features are not invented to fill empty space. Verify narrow phones at 200% text, dark mode, error recovery and name persistence.

## Immersive scrolling and single headings (owner, 30 Oct 2026)

Root tabs use one floating header with one title and one create action. Do not render compact and expanded titles simultaneously. Home, Chats, Groups, Events and You use the same header behavior: scroll down to clear the header, scroll up to restore it. The slim bottom navigation hides after a deliberate downward vertical drag and returns on upward movement or route change. Horizontal carousels do not hide it; accessibility navigation keeps it visible, and reduced-motion settings disable the transition. Full-screen conversations retain their own header/composer. Safe system insets remain respected.

Failed Memory photos offer an explicit retry that refreshes the signed URL and evicts the failed image. Keep the media frame stable to avoid scroll jumps; use neutral error styling, no purple oversized icon or centered count badge over an error. Live photo recovery still needs a real-device/server check.

## Home reference update — 31 October 2026

Owner-provided Circle screenshot supersedes the prior Home composition: bundled Roboto, violet primary, pale neutral page background, white rounded Memory cards, captions before photos, compact reaction/comment totals, evenly spaced actions, circle filter chips and a centered create dock. Chats moves to the header; Photos shows only the current authorized Memory timeline with pagination. Events and polls remain accessible through composer shortcuts. Video and private sharing are not implemented, so those controls are not advertised. Exact font identity and pixel equivalence cannot be established from the raster reference alone. Real photos and native screenshots remain acceptance checks.
