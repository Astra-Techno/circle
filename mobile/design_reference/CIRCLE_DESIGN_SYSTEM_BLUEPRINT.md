# CIRCLE — Unified Design System & Flutter Theme Blueprint

> Current direction,4 November2026: Social1 overrides the older proposed typography
> and dock values below. Use Roboto400/600, the shared CircleTextStyles/Material
> roles and a full-width five-tab navigation bar. See docs/design-system.md and
> docs/design-previews/social-system/REVIEW.md for the implemented design.

**Version:** 1.2 (responsive controls, tablet layout and visual precision standards)  
**Product:** Circle — *My Circle. Billion Memories.*  
**Scope:** V1 mobile app; future features intentionally excluded  
**Source of truth:** Approved screen references + existing production behavior  
**Repository:** https://github.com/Astra-Techno/circle/tree/main/mobile

> **Important:** Numeric values below are **proposed Flutter logical pixels (dp)** for consistent implementation, not claimed measurements of the approved screenshots. Verify against reference images using golden screenshots at the same viewport and text scale. Do not blindly replace the existing theme or break app logic.

## 1. Design philosophy and non-negotiables

- **Personality:** premium, warm, modern, private, memory-first; quiet white surfaces and confident purple accents.
- **Single source of truth:** no widget may invent colors, font sizes, radii, shadow styles or icon sizes.
- **Screen titles:** Home uses brand `Circle` and tagline; other root tabs use their page title (e.g. `Circles`, `Events`) alongside the authentic logo; no redundant large second heading.
- **Author lines:** show `Priya`, **not** `Priya shared a memory`; show `Arjun`, **not** `Arjun created an event`; show `Vignesh`, **not** `Vignesh created a poll`.
- **Privacy:** don't repeat `Private` labels on every post in a closed Circle; show audience where needed for user control.
- **Navigation (owner, 3 November 2026):** exactly five root destinations: Home, Circles, Chats, Events, Profile. Chats replaces the central Create action; Memory creation remains in Home's composer.
- **Scope freeze:** V1 only. No time capsules, secret celebration rooms, AI recaps, rituals, or nostalgia mechanics in this implementation.
- **Logo:** use the user's authentic purple infinity-loop icon as an **asset**; never substitute a generated or approximate infinity symbol.

## 2. Existing codebase integration (checked against main)

Existing files and packages:

| Existing asset / class | Action |
|---|---|
| `lib/core/design.dart` | **Extend/refactor**, don't duplicate; currently defines `Space`, `CircleDepth`, `CircleAccents`, `circleTheme`, `CircleRadius` |
| `lib/core/circle_components.dart` | Reuse existing `CirclePill`, `CircleInitialAvatar`, `CircleSectionTitle`, `CircleRow`, etc. |
| `lib/app/circle_experience.dart` | Reuse actual app shell and floating navigation; do not create a second dock |
| `lib/features/memories/presentation/circle_memories.dart` | Reuse real Home Feed and composer/quick actions |
| `lib/features/memories/presentation/memory_card.dart` | Reuse real post interactions and feed models |
| `lib/features/memories/presentation/memory_photos.dart` | Reuse actual photo mosaic logic |
| `flutter_lucide: ^1.66.0` | Use for icon vocabulary; verify actual exported constants in installed package |
| `PlusJakartaSans`, `Roboto` | Both bundled in `pubspec.yaml`; standardize app-facing type on **PlusJakartaSans**; preserve Roboto only where required by legacy content |
| `assets/brand/circle-brand.png` | Check if it matches the user's authentic uploaded logo. Replace/copy only after visually comparing assets. |

**Migration caution:** Existing `Space.lg` and `Space.md` are both `16`; do not silently redefine existing token meanings across all screens. Introduce named `CircleSpacing` tokens and migrate selectively. Existing `CircleDepth.cardElevation=0` reflects a previous flat-design direction; update only after screenshot comparison.

## 3. Color palette — proposed light theme

### 3.1 Semantic colors

| Token / Dart name | HEX | Usage |
|---|---|---|
| `CircleColors.canvas` | `#FFFFFF` | Page scaffold, Home, Circles, Events |
| `CircleColors.surface` | `#FFFFFF` | Cards, sheets, dock |
| `CircleColors.surfaceSoft` | `#F7F7FB` | Composer, neutral tiles, comment bubbles |
| `CircleColors.surfaceLavender` | `#F3F0FF` | Selected pale backgrounds, badges |
| `CircleColors.primary` | `#5A19D6` | Primary CTAs, active tab, selected icons |
| `CircleColors.primaryPressed` | `#4610AC` | Pressed/active primary |
| `CircleColors.primaryTint` | `#EEE8FF` | Selected controls and gentle highlighting |
| `CircleColors.textPrimary` | `#10132B` | Headings, names, primary content |
| `CircleColors.textSecondary` | `#59607B` | Group/time metadata, supporting content |
| `CircleColors.textMuted` | `#8389A1` | Placeholder and less-important metadata |
| `CircleColors.border` | `#ECECF4` | Dividers, quiet card outline |
| `CircleColors.iconDefault` | `#161A38` | Inactive action icons |
| `CircleColors.danger` | `#F44355` | Heart/reactions, errors, unread dot |
| `CircleColors.success` | `#22B85B` | Event and confirmation accent |
| `CircleColors.warning` | `#F59A15` | Poll accent and warning |
| `CircleColors.photo` | `#5730CC` | Photo quick action |
| `CircleColors.video` | `#F0445B` | Video quick action |
| `CircleColors.event` | `#23B75B` | Event quick action |
| `CircleColors.poll` | `#F59A15` | Poll quick action |
| `CircleColors.photoBg` | `#F2EEFF` | Photo tile |
| `CircleColors.videoBg` | `#FFF0F2` | Video tile |
| `CircleColors.eventBg` | `#EFFAF2` | Event tile |
| `CircleColors.pollBg` | `#FFF7EA` | Poll tile |

**Color discipline:** Purple is reserved for selected states and primary actions. Do not color all body text purple. Keep photos vibrant and chrome neutral. Avoid hardcoded `Colors.grey`, `Colors.purple` in feature widgets.

### 3.2 Dark theme — semantic mapping, not light-theme inversion

| Token | Proposed dark |
|---|---|
| canvas | `#101018` |
| surface | `#1B1B27` |
| surfaceSoft | `#242434` |
| surfaceLavender | `#302746` |
| primary | `#B5A0FF` |
| textPrimary | `#F7F6FF` |
| textSecondary | `#BAB8CE` |
| textMuted | `#8F8CA5` |
| border | `#343244` |
| iconDefault | `#F0EDFF` |

Use theme extensions for semantic colors. Check contrast against WCAG AA for body text. Do not assume tinted light tile fills remain readable in dark mode.

## 4. Typography — Plus Jakarta Sans

**Primary family:** `PlusJakartaSans` (already bundled).  
**Fallback:** platform sans-serif; avoid mixing font families within the same card.  
**Available weights in current pubspec:** 400, 500, 600, 700. Do not request 800 without bundling a matching font file.

| Token / Flutter class | Size (sp) | Weight | Line height (dp) | Letter spacing | Use |
|---|---:|---:|---:|---:|---|
| `CircleTextStyles.brand` | 24 | 700 | 30 | -0.5 | `Circle` in header |
| `CircleTextStyles.pageTitle` | 22 | 700 | 29 | -0.4 | `Circles`, `Events`, `Profile` |
| `CircleTextStyles.sectionTitle` | 18 | 700 | 25 | -0.2 | Upcoming Celebrations, Comments |
| `CircleTextStyles.cardTitle` | 16 | 700 | 23 | -0.2 | Post author, event title |
| `CircleTextStyles.body` | 15 | 400 | 23 | 0 | Post captions, comments |
| `CircleTextStyles.bodyMedium` | 15 | 500 | 23 | 0 | Supporting emphasis |
| `CircleTextStyles.label` | 13 | 600 | 18 | 0 | Tabs, quick actions, buttons |
| `CircleTextStyles.metadata` | 12 | 400 | 17 | 0 | Circle name, timestamps, counts |
| `CircleTextStyles.caption` | 11 | 500 | 15 | 0 | Tiny badges and helper text |
| `CircleTextStyles.button` | 14 | 700 | 20 | 0 | Primary and secondary CTAs |
| `CircleTextStyles.navLabel` | 11 | 600 | 15 | 0 | Floating dock labels |
| `CircleTextStyles.input` | 14 | 400 | 20 | 0 | Composer, comments |

**Rules:** Use Flutter `TextTheme`/semantic tokens, not inline `TextStyle(fontSize: ...)` in screens. Respect user text scaling and dynamic type; allow wrapping. Prefer 2-line truncation only where the design demands it. Do not force fixed-height text containers when accessibility font scaling is active.

## 5. Spacing, geometry and depth

### 5.1 Spacing tokens

| Name | dp | Typical use |
|---|---:|---|
| `CircleSpacing.xxs` | 2 | Tiny indicator offsets |
| `CircleSpacing.xs` | 4 | Icon-label micro gap |
| `CircleSpacing.sm` | 8 | Inside card, item gap |
| `CircleSpacing.md` | 12 | Text blocks and rows |
| `CircleSpacing.lg` | 16 | Horizontal page gutter, card padding |
| `CircleSpacing.xl` | 20 | Card-to-card gap |
| `CircleSpacing.xxl` | 24 | Section spacing |
| `CircleSpacing.xxxl` | 32 | Major section separation |

**Baseline:** 4dp micro-grid, predominantly 8dp rhythm. Keep `16dp` horizontal page padding at a 393dp viewport.

### 5.2 Radius tokens

| Name | Radius (dp) | Usage |
|---|---:|---|
| `CircleRadii.xs` | 8 | Compact badges, image corners |
| `CircleRadii.sm` | 12 | Photo mosaics, tiles |
| `CircleRadii.md` | 16 | Quick actions, event preview |
| `CircleRadii.lg` | 20 | Feed cards, Circle list cards |
| `CircleRadii.xl` | 24 | Sheets, large surfaces |
| `CircleRadii.pill` | 999 | Composer, chips, dock, buttons |

### 5.3 Borders and shadows

- Hairline border: 1dp `CircleColors.border`.
- `CircleShadows.card`: `BoxShadow(color: Color(0x0A202044), blurRadius: 18, offset: Offset(0, 4))`.
- `CircleShadows.dock`: `BoxShadow(color: Color(0x18202044), blurRadius: 28, offset: Offset(0, 8))`.
- Cards: white surface + very subtle border/shadow; no heavy elevation.
- Do not draw both thick border and heavy shadow on the same card.

## 6. Icon system — one family, controlled sizing

**Primary icon library:** `flutter_lucide` (`LucideIcons`), already in pubspec.  
**Default stroke:** 1.8 logical pixels for ordinary outline icons.  
**Emphasis stroke:** 2.2 for active/important icons; 1.6 for larger decorative icons.  
**Default color:** `CircleColors.iconDefault`; active `CircleColors.primary`; disabled `CircleColors.textMuted`.

**Flutter caveat:** `IconData` font glyphs may not support configurable `strokeWidth` like SVG icons. If the installed `flutter_lucide` implementation does not expose stroke width, use its native glyph weight and do **not** fake thickness with shadows or multiple overlaid icons. For exact stroke requirements, create a reusable `CircleSvgIcon` backed by approved SVG assets and add an SVG package only if necessary.

| Semantic key / enum | Lucide name (conceptual) | dp | Color/state |
|---|---|---:|---|
| `CircleIcon.home` | `house` | 22 | Primary if selected |
| `CircleIcon.circles` | `users-round` | 22 | Primary if selected |
| `CircleIcon.create` | `plus` | 28 | White on primary circle |
| `CircleIcon.events` | `calendar-days` | 22 | Primary if selected |
| `CircleIcon.profile` | `user-round` | 22 | Primary if selected |
| `CircleIcon.search` | `search` | 22 | Default |
| `CircleIcon.notifications` | `bell` | 22 | Default, unread dot danger |
| `CircleIcon.chat` | `message-circle` | 22 | Default |
| `CircleIcon.more` | `ellipsis` | 20 | Default |
| `CircleIcon.photo` | `image` | 24 | Photo purple |
| `CircleIcon.video` | `video` | 24 | Video coral |
| `CircleIcon.event` | `calendar-days` | 24 | Event green |
| `CircleIcon.poll` | `list-todo` | 24 | Poll amber |
| `CircleIcon.like` | `heart` | 21 | Outline default; filled danger when liked |
| `CircleIcon.comment` | `message-circle` | 21 | Default |
| `CircleIcon.share` | `share-2` | 21 | Default |
| `CircleIcon.bookmark` | `bookmark` | 21 | Default; filled primary when saved |
| `CircleIcon.back` | `arrow-left` | 22 | Default |
| `CircleIcon.close` | `x` | 22 | Default |
| `CircleIcon.members` | `users` | 17 | Metadata |
| `CircleIcon.location` | `map-pin` | 17 | Metadata |
| `CircleIcon.time` | `clock-3` | 17 | Metadata |
| `CircleIcon.birthday` | `cake` | 20 | Celebration primary |
| `CircleIcon.anniversary` | `heart-handshake` | 20 | Celebration primary |
| `CircleIcon.invite` | `user-plus` | 20 | Primary |
| `CircleIcon.send` | `send` | 20 | White on primary button |
| `CircleIcon.check` | `check` | 18 | Success or primary |

**Verification:** The names above are semantic design targets, **not verified Dart constants**. Inspect `flutter_lucide` exports before mapping `CircleIcon` to `LucideIcons.*`; some packages use alternate names. Provide accessible tooltips/semantics on icon-only buttons and >=44×44dp tap targets.

## 7. Shared class and file naming blueprint

### 7.1 Files

```text
lib/core/design.dart                     # existing ThemeData, semantic extensions
lib/core/circle_components.dart          # existing shared widgets; migrate incrementally
lib/design_system/circle_colors.dart     # semantic palette / ThemeExtension
lib/design_system/circle_typography.dart # text styles / text theme builder
lib/design_system/circle_spacing.dart    # spacing, radii, sizes
lib/design_system/circle_icons.dart      # semantic icon mapping
lib/design_system/circle_shadows.dart    # depth styles
lib/design_system/circle_theme.dart      # theme composition / compatibility wrapper
lib/design_system/widgets/               # only NEW reusable widgets; avoid duplicating existing ones
```

**Rule:** `circleTheme()` remains a compatibility entry point; it may delegate to the new theme builder. Avoid two competing themes. Existing `Space`, `CircleRadius`, `CircleAccents`, `CircleDepth` remain supported until all call sites are migrated.

### 7.2 Reusable class contracts

| Class | Purpose | Required input / behavior |
|---|---|---|
| `CircleAppHeader` | Common root-tab header | `title`, `showLogo`, `actions`; Home displays brand/tagline; other tabs title only |
| `CircleIconButton` | Uniform action button | `icon`, `tooltip`, `onPressed`, `tone`, `size`; 44dp target |
| `CirclePrimaryButton` | Primary CTA | `label`, `icon?`, `onPressed`, `loading`, `enabled` |
| `CircleSecondaryButton` | Outlined/soft CTA | Same API as primary |
| `CircleSurfaceCard` | Consistent white card | `child`, `padding`, `onTap?`, `variant` |
| `CircleAvatar` | Unified member avatar wrapper | `image`, `name`, `size`, `active`; delegate to existing avatar where possible |
| `CircleMemberAvatarStack` | Overlapping avatars + count | `members`, `maxVisible`, `totalCount` |
| `CircleMetaRow` | Group + time + optional context | `circleName`, `timestamp`, `icon?` |
| `CircleSectionHeader` | Section title + trailing link | `title`, `actionLabel?`, `onAction?` |
| `CircleSegmentedTabs` | My Circles/Discover/Invitations | `tabs`, `selectedIndex`, `onChanged` |
| `CircleQuickActionTile` | Photo/Video/Event/Poll | `type`, `label`, `onTap` |
| `CircleFeedCard` | Standard feed surface | `child`, `padding` |
| `CirclePostHeader` | Avatar/name/circle/time/overflow | No activity verbs in name line |
| `CirclePostActions` | Like/comment/share/save | Real callbacks, correct selected states |
| `CirclePhotoMosaic` | 1/2/3+ image layout | Reuse `memory_photos.dart` logic |
| `CircleEventPreviewCard` | Event inside feed | Title/date/location/image/RSVP |
| `CirclePollCard` | Poll in feed | Question/options/vote state/results |
| `CircleCelebrationTile` | Birthday/anniversary | Date/person/type/circle; only shared dates |
| `CircleFloatingNav` | Root floating navigation | Existing shell must remain authoritative |
| `CircleCommentBubble` | Comment body/reply | Avatar, author, time, text, actions |
| `CircleEmptyState` | Empty lists | Icon/title/message/action? |
| `CircleLoadingState` | Skeleton/progress | Consistent spacing and non-jarring loading |
| `CircleErrorState` | Failure/retry | Friendly error, retry action |

**Avoid duplication:** If an equivalent widget exists in `circle_components.dart`, refactor/alias it rather than adding a parallel implementation with the same responsibility.

### 7.3 Naming conventions

- `Circle*` for reusable public widgets, tokens, services.
- `CircleColors`, `CircleTextStyles`, `CircleSpacing`, `CircleRadii`, `CircleSizes`, `CircleIcons` for design tokens.
- `*Page` for route-level screens (`CirclesPage`, `EventsPage`, `PostDetailPage`).
- `*Card` for reusable content surfaces; `*Tile` for compact list entries; `*Section` for page sections.
- No `_PurpleButton`, `CustomCard2`, `NewNavBar`, `CircleHeaderV3` or duplicate “temporary” widgets.
- No direct magic numbers in feature screen layout except deliberate content-specific values documented in the screen spec.

## 8. Component specifications (proposed dp)

### 8.1 Root header

- White background; height target **64dp** excluding status bar; 16dp horizontal padding.
- Authentic logo: **40×40dp**, rounded icon asset, `BoxFit.contain`.
- Home: `Circle` 24sp bold + `My Circle. Billion Memories.` 11sp medium.
- Other root pages: logo + `Circles`, `Events`, `Profile` at 22sp bold; **no repeated brand tagline**.
- Right actions: 22dp icons in 44dp targets; 4dp–8dp visible gap; never squeeze title offscreen.
- Circles: a **plus** action in the same header, immediately associated with the page title/actions; opens Create Circle.
- Post Detail and deep pages: back arrow + page title + overflow; no root-brand header.

### 8.2 Composer

- Row: 40dp avatar + 12dp gap + expandable pill.
- Pill height **44–48dp**, radius 999, background `surfaceSoft`.
- Placeholder `Share a memory with your Circle...`, 14sp muted.
- On tap open real create flow; no dummy text input in feed.

### 8.3 Quick actions

- Four equal-width tiles in one row, gap **8dp**.
- Tile height target **72dp** at 393dp viewport; radius 16dp.
- Icon **24dp**, label **12–13sp / 600**, 4dp gap.
- Photo purple / Video coral / Event green / Poll amber, each with its own pastel fill.
- Avoid `AspectRatio(1)` square tiles. On narrow screens use responsive layout rather than clipping labels.

### 8.4 Feed memory card

- White card, 20dp radius, 1dp quiet border or light shadow; **12–16dp internal padding**.
- Header: 40dp avatar, 12dp gap; author 16sp/700; metadata 12sp/400; 20dp overflow icon.
- Caption: 15sp/400, 23dp line height; 8–12dp below header.
- Photo collage: 8dp corner radius, 4dp gutters; for 3+ photos, **2/3 large left + 1/3 right stacked** as approved. Use real media assets, no generated placeholder in production.
- Reaction summary: compact 12sp, with count and comments count.
- Actions: heart/comment/share/bookmark icon-only, 21dp icons, each >=44dp hit target.
- Do not show activity verbs in post author line.

### 8.5 Circle list card

- White rounded 20dp card, padding 12dp.
- Leading square cover **76–84dp**, 16dp radius.
- Title 16sp bold; member count 12sp secondary; stacked avatars 24–28dp + `+N`.
- Overflow button top-right; do not show redundant privacy badges.
- `My Circles`, `Discover`, `Invitations` tabs below header; invitation count badge.

### 8.6 Events / celebrations

- Events root header with create action; below it tabs **All / Events / Celebrations**. Calendar can be an action/view, not mandatory fourth V1 tab.
- Upcoming Celebrations strip: birthday/anniversary avatar, name, date, circle. Tap to detail/wish if implemented.
- Upcoming Events: event image, title, date, time, circle, RSVP status.
- RSVP options: Going / Maybe / Not Going; one selected state at a time.
- V1 celebrations: **birthdays and anniversaries only**, opt-in visibility, recurring yearly, no automatic public posts.

### 8.7 Post detail / comments

- Deep-page header: back, `Post`, overflow.
- Full-width post content consistent with feed but may use larger photo mosaic.
- Comments: avatar 32dp, author 13sp bold, metadata 11sp, body 14sp, light neutral bubble.
- Composer pinned above keyboard/safe area; avatar + pill + image/GIF only if supported + send.
- No root bottom dock on focused detail screen unless navigation architecture explicitly requires it.

### 8.8 Floating bottom navigation

- Exactly five destinations: Home / Circles / **Create** / Events / Profile.
- Capsule white, pill radius, 16–20dp horizontal inset, height target **64–72dp**; float **8–12dp** above bottom safe area.
- Icon 22dp; labels 11sp; selected icon and label primary purple; tiny selected dash under label if reference uses it.
- Center create: 52–56dp purple circular button, white 28dp plus; visually raised, with proper hit area.
- Soft dock shadow only; avoid a full-width attached white rectangle.
- Reserve scroll bottom padding equal to dock height + safe area + breathing room.

### 8.9 Buttons, inputs, badges

- Primary button: min height 48dp, purple fill, white 14sp/700, radius pill.
- Secondary button: min height 44dp, lavender/white fill with purple label and subtle border.
- Inputs: 48dp min height, radius 16–20dp, neutral fill, focus ring 1.5–2dp purple.
- Chips/tabs: 36–40dp height, pill radius; selected purple fill/white text; inactive soft lavender/textPrimary.
- Badges: 20–24dp height, 11sp/600; no colored badges for ordinary headings.

## 9. Per-page design contract

| Page | Header | Key components | Bottom nav |
|---|---|---|---|
| Home | Authentic logo + Circle/tagline + search/bell/chat | Composer, 4 actions, unified chronological memory/event/poll cards | Home selected |
| Circles | Logo + `Circles` + create plus + appropriate actions | My Circles/Discover/Invitations; circle cards | Circles selected |
| Create Memory | Back + `Create Memory` | Circle selector, text/media, optional type actions, primary submit | Usually hidden for editor |
| Events | Logo + `Events` + create | All/Events/Celebrations, upcoming celebrations, event cards | Events selected |
| Event Detail | Back + event title or `Event Details` | Cover, date/location, RSVP, participants, discussion | Hidden |
| Celebration Detail | Back + `Celebration` | Name, date, wish action, shared memories where available | Hidden |
| Post Detail | Back + `Post` | Full post, reactions, comments, comment composer | Hidden |
| Chat | Back + circle/person name | Messages, attachments, composer | Hidden |
| Profile | Logo + `Profile` or profile-specific toolbar | Avatar, bio, circles, memories, settings | Profile selected |

**V1 boundaries:** If a screen or feature is not implemented yet, do not add fake buttons. Hide, disable with explanation, or defer explicitly. Preserve backend permissions and real actions.

## 10. Sample Dart API contracts (illustrative, not drop-in code)

```dart
// lib/design_system/circle_spacing.dart
abstract final class CircleSpacing {
  static const xxs = 2.0, xs = 4.0, sm = 8.0, md = 12.0;
  static const lg = 16.0, xl = 20.0, xxl = 24.0, xxxl = 32.0;
}

abstract final class CircleRadii {
  static const xs = 8.0, sm = 12.0, md = 16.0;
  static const lg = 20.0, xl = 24.0, pill = 999.0;
}

abstract final class CircleSizes {
  static const iconSmall = 17.0, iconDefault = 22.0;
  static const iconQuickAction = 24.0, iconCreate = 28.0;
  static const minTouchTarget = 44.0, avatarPost = 40.0;
  static const logoHeader = 40.0, dockCreate = 56.0;
}
```

```dart
// Example contract only. Wire to actual `CircleAccents` / ColorScheme
// rather than creating conflicting color ownership.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    icon: Icon(icon, size: CircleSizes.iconDefault,
      color: color ?? Theme.of(context).colorScheme.onSurface),
  );
}
```

```dart
// Example of usage: use semantic widgets and theme styles everywhere.
CirclePostHeader(
  author: post.author,
  circleName: post.circleName,
  timestamp: post.createdAt,
  onMore: () => openPostActions(post),
);

CirclePostActions(
  isLiked: post.isLiked,
  isSaved: post.isSaved,
  onLike: () => toggleLike(post.id),
  onComment: () => openComments(post.id),
  onShare: () => sharePost(post.id),
  onSave: () => toggleSave(post.id),
);
```

## 11. Responsive behavior and accessibility

- Reference viewport: **393×852 logical dp** for initial tests; also test 360×800, 430×932, and text scale 1.3/1.5.
- Honor SafeArea and keyboard insets. Avoid fixed heights for content with variable text.
- Icons can be visually 20–24dp but interactive targets must be >=44×44dp.
- Maintain sufficient text contrast; use `Semantics`, `Tooltip`, meaningful image labels.
- Respect reduced motion and system text scaling.
- Keep image aspect ratios stable while loading to avoid jumping layouts.
- Dark mode must use semantic tokens; no direct `Colors.white` in screen widgets unless explicitly on-image/on-primary.

## 12. Visual verification and CI quality gates

**No emulator required.** Prefer widget/golden tests with real production widgets, fixture providers, and font loading.

1. Store approved reference images under `design_reference/approved/` (the exact user-approved images, not AI re-creations).
2. Include the **real logo asset** and verify it renders at 40dp with no distortion.
3. Load **PlusJakartaSans** and **Lucide** fonts in golden tests. If icon glyphs render as squares, the test is invalid.
4. Render at exact logical viewport + pixel ratio + text scale; do not compare images at different aspect ratios.
5. Capture Home, Circles, Events, Post Detail; add Create and Profile when ready.
6. Produce actual PNG, overlay PNG, difference PNG, and per-component notes.
7. Test layout on 360dp and 430dp widths, plus accessibility text scale.
8. Run `dart format`, `flutter analyze`, relevant `flutter test` and inspect any failures.
9. Do not declare pixel-perfect based on code review or a passing test alone.
10. Do not hardcode image content from the reference into production UI. Layout must work with live data.

**Suggested commands (after harness is implemented):**

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
# Use the golden-test command documented by the implemented harness.
# Do not run an Android emulator for screenshot checks.
```

## 13. Claude Code implementation phases

### Phase A — Freeze and audit

- Create branch `ui/circle-design-system`.
- Inspect current `design.dart`, `circle_components.dart`, all existing theme references, icons, tests and approved reference screenshots.
- Build a map of existing widgets to the class contracts in Section 7. **No feature changes.**
- Report any conflict between this blueprint and current approved screenshots.

### Phase B — Tokens and compatibility

- Introduce semantic colors, typography, spacing, icon mapping, radii and shadows.
- Keep `circleTheme()` public API and existing `CircleAccents`, `Space`, `CircleRadius`, `CircleDepth` working through adapters or staged migration.
- Prefer existing widget classes where possible; do not introduce duplicate headers/cards/navigation.

### Phase C — Reusable components

- Standardize root header, icon button, quick action tile, card, avatar stack, post header/actions and floating dock.
- Preserve actual onTap/onPressed behavior and Riverpod/GoRouter integration.
- Fix activity verbs in author headers.

### Phase D — Screens in priority order

1. Home
2. Circles
3. Events + minimal Celebrations
4. Post Detail + Comments
5. Create Memory
6. Chat and Profile

One screen per review cycle; **do not restyle all screens at once**.

### Phase E — Golden QA and release

- Generate actual screenshots without emulator.
- Compare against approved references and fix three largest differences per iteration.
- Confirm no API/auth/navigation regressions and no broken icon fonts.
- Produce a visual QA report with remaining mismatches and evidence.

## 14. Acceptance checklist

- [ ] Authentic logo asset used consistently
- [ ] One shared font family and semantic typography system
- [ ] One shared palette with no hardcoded screen colors
- [ ] One icon family and semantic icon mapping
- [ ] Shared spacing/radius/shadow tokens
- [ ] Root headers consistent; no duplicated page title
- [ ] Home author names have no activity verbs
- [ ] Compact labeled Photo/Video/Event/Poll actions
- [ ] Unified feed preserves real data and actions
- [ ] Floating dock correct and non-overlapping
- [ ] Circles title and create plus in header
- [ ] Events includes minimal birthdays and anniversaries
- [ ] Post Detail comments composer works with keyboard
- [ ] Accessibility labels and 44dp targets
- [ ] Golden tests render fonts/icons/logo correctly
- [ ] Actual-vs-reference screenshots reviewed
- [ ] `flutter analyze` and relevant tests pass
- [ ] No future-scope features slipped into V1

## 15. Master instruction for Claude Code

> Read `CIRCLE_DESIGN_SYSTEM_BLUEPRINT.md` and the approved reference screenshots. Treat this blueprint as the shared token and class naming contract; treat approved screenshots as the visual target; treat existing production behavior as the functional source of truth. Audit first, then implement the design system incrementally without duplicating current classes or breaking backend/API/Riverpod/GoRouter behavior. Start with tokens, compatibility, and a golden-test harness; then migrate Home, Circles, Events, Post Detail one screen at a time. Never claim pixel-perfect success without a rendered screenshot comparison. No Android emulator. No future-feature expansion.

---

**Decision status:** Proposed design-system contract, ready for Claude Code implementation and screenshot validation. Exact colors, dimensions and icons should be refined only from approved reference images, not arbitrary agent preference.


---

## 16. Mandatory responsive sizing and tablet layout contract (v1.1)

**Reason:** A narrow `Center > ConstrainedBox(maxWidth: 480/600)` applied to the entire application can create huge unused gutters on Android tablets. Do not use a universal maximum page width. Forms and content feeds have different width rules. All dimensions are **Flutter logical pixels (dp)**, not physical Android pixels; use `MediaQuery.sizeOf(context).width` and `LayoutBuilder` for available-width decisions, never the device's raw physical resolution.

### 16.1 Breakpoints and width strategy

| Available width | `CircleBreakpoint` | Page outer padding | Content structure | Navigation |
|---|---|---:|---|---|
| < 600dp | `compact` | 16dp | Single column, full available width | Existing floating bottom dock |
| 600–839dp | `medium` | 24dp | Single column or 2-column cards; never fixed 393dp canvas | Floating dock; verify no overlap |
| 840–1199dp | `expanded` | 32dp | Feed + optional sidebar, 2–3-column grids | Adapt existing dock/rail without duplicating routes |
| >= 1200dp | `large` | 40dp | 2–3 content regions, bounded *per region* | Navigation rail/sidebar where appropriate |

**Width contracts by page** (widths are caps only where specified; available width after page padding takes precedence):

| Page/region | Compact | Medium | Expanded/large |
|---|---|---|---|
| Home | One fluid feed | Feed 100% or feed + right rail when enough room | Main feed target 600–720dp **plus** 240–320dp side rail; whole composition centered, not feed alone |
| Circles | One full-width list | 2-column circle-card grid | 2–3-column circle-card grid, cards at least 280dp |
| Events | One full-width list | 2-column event grid where content allows | Main event list + upcoming celebrations/calendar side rail |
| Chat list | Full width | Split list + conversation when possible | Persistent list 300–360dp + flexible conversation |
| Chat conversation | Full width | Fill remaining conversation pane | Fill conversation pane; message bubbles capped individually |
| Profile | Full width | Flexible cover + 2-column sections | Cover spans content region; details use 2 columns |
| Create/edit form | Full width | Form capped 560dp (intentional) | Form capped 640dp (intentional); explanatory/preview rail optional |
| Post detail | Full width | Post 600–720dp, comments below | Post + comments/related sidebar when appropriate |
| Dialog | Screen width minus 32dp | max 480dp | max 560dp; avoid excessively wide dialogs |

**Non-negotiable:** Never put the entire `Scaffold`, app shell, `CustomScrollView`, tab header or bottom dock inside a global `ConstrainedBox(maxWidth: 480/600)`. Only constrain the specific reading/form region. A tablet must not look like a phone screenshot pasted into the middle of the screen.

### 16.2 Complete controls sizing specification

| Component | Height / size | Width behavior | Radius | Notes / canonical class |
|---|---|---|---|---|
| Single-line text field | min 48dp, recommended 52dp | `double.infinity` within form column | 14dp | `CircleTextField`; label above, 16sp text, 15sp hint |
| Search field | 44–48dp | Fill available search region | 24dp | `CircleSearchField`; leading 20dp search icon |
| Multi-line textarea | min 112dp, grows to max 240dp before scrolling | Fill available form column | 16dp | `CircleTextArea`; do not force fixed height with large text |
| Password field | 52dp min | Fill form column | 14dp | `CirclePasswordField`; show/hide target 44dp |
| Dropdown/select | min 52dp | Fill form column; menu width matches field when feasible | 14dp | `CircleSelectField`; chevron 20dp |
| Date/time picker field | min 52dp | Fill form column | 14dp | `CircleDateField`; icon 20dp; platform picker |
| Checkbox visual box | 20×20dp | Intrinsic | 5dp | `CircleCheckbox`; 2dp outline; selected fill primary; minimum tappable row 48dp |
| Checkbox with label | min 48dp row | Fill form column | — | `CircleCheckboxTile`; gap 12dp; label wraps |
| Radio visual | 20×20dp | Intrinsic | circular | `CircleRadioTile`; 2dp ring; 48dp min touch row |
| Switch | 52×32dp visual target | Intrinsic | pill | `CircleSwitchTile`; 48dp min touch row; adapt platform if needed |
| Segmented control | min 40dp | Fill available section width; wrap/scroll if labels overflow | 20dp | `CircleSegmentedTabs`; no clipped labels |
| Filter chip | 36–40dp | Intrinsic; wrap or horizontal scroll | 20dp | `CircleFilterChip`; horizontal 12dp padding |
| Primary button | min 48dp, recommended 52dp | Fill forms; intrinsic on toolbars | 16dp or pill by variant | `CirclePrimaryButton`; 16sp semibold |
| Secondary button | min 48dp | Fill forms; intrinsic on toolbars | 16dp | `CircleSecondaryButton` |
| Icon-only button | min 44×44dp touch area | Intrinsic | 22dp | `CircleIconButton`; glyph 20–24dp |
| Avatar | 32/40/56/72/96dp | Intrinsic | circular | Reuse `CircleInitialAvatar` / `CircleAvatarSize` |
| Inline badge | min 20dp | Intrinsic | 10dp | `CirclePill`; 11–12sp label |
| Snackbar | min 48dp | Fill minus 16dp gutters; cap 560dp on tablet | 14dp | Theme-level behavior |
| Bottom sheet | content-driven | Phone full width; tablet max 640dp centered | top 24dp | `CircleAdaptiveSheet`; safe-area + keyboard aware |
| Dialog | content-driven | 100% minus gutters, cap per table above | 20dp | `CircleAdaptiveDialog` |
| Feed card | content-driven | Fill its assigned feed column | 20dp | `CircleFeedCard`; inner padding 16dp |
| Circle card | min 132dp, content may grow | Fill grid cell; min cell width 280dp | 20dp | `CircleCircleCard`; no clipped member names |
| Event card | content-driven, usually >=144dp | Fill grid cell | 20dp | `CircleEventPreviewCard` |
| Photo tile | aspect ratio controlled | Fill grid slot | 12–16dp | `CirclePhotoMosaic`; use `AspectRatio` |
| Quick action | min 72dp height | Equal widths on phone; max 160dp each on tablet, grid/wrap | 16dp | `CircleQuickActionTile`; visible icon and label |
| Bottom navigation dock | 64–72dp | Phone width minus 32dp; tablet max 560dp **only dock**, not page | pill | `CircleFloatingNav`; respect safe area |
| Top toolbar | 56–64dp | Full available page width | — | `CircleAppHeader`; actions 44dp touch |
| List row | min 56dp, expands for wrapping | Fill content column | — | `CircleRow`; no fixed text height |

**Checkbox and icon stroke:** Flutter's standard checkbox supports border `BorderSide(width: 2, color: ...)`. Lucide font icons have a fixed glyph weight: do not pretend `Icon` exposes configurable SVG stroke widths. Use one approved icon set consistently; where exact 1.75/2.0dp strokes are essential, use an approved SVG icon component.

### 16.3 Responsive layout primitives: exact reusable class names

- `CircleBreakpoints`: constants `compactMax=600`, `mediumMax=840`, `expandedMax=1200`.
- `CircleBreakpoint`: enum `compact`, `medium`, `expanded`, `large`.
- `CircleResponsive`: `breakpointFor(double availableWidth)`; prefer `LayoutBuilder` for nested layout decisions.
- `CirclePageLayout`: handles **outer** page padding and optional region composition; must not globally cap page width.
- `CircleContentGrid`: uses minimum card width, dynamic column count and spacing; no hardcoded phone-width list.
- `CircleFormLayout`: width-limited **form only**, capped at 560dp on medium and 640dp on expanded screens.
- `CircleAdaptiveSplitView`: optional two-pane list/detail on tablets; keep phone routing unchanged.
- `CircleTextField`, `CircleTextArea`, `CircleSelectField`, `CircleCheckboxTile`, `CircleRadioTile`, `CircleSwitchTile`: reusable semantic form components.
- `CircleAdaptiveDialog`, `CircleAdaptiveSheet`: tablet-aware overlays with safe areas and keyboard handling.

If existing classes already fulfill a contract, **reuse or adapt** them; do not introduce duplicate versions. Keep `CircleInsets`, `Space`, `CircleRadius`, `CircleAccents`, `CircleDepth` compatible during migration.

### 16.4 Example Flutter implementation: page widths vs form widths

```dart
import 'package:flutter/material.dart';

enum CircleBreakpoint { compact, medium, expanded, large }

abstract final class CircleBreakpoints {
  static const compactMax = 600.0;
  static const mediumMax = 840.0;
  static const expandedMax = 1200.0;
}

abstract final class CircleResponsive {
  static CircleBreakpoint breakpointFor(double width) {
    if (width < CircleBreakpoints.compactMax) return CircleBreakpoint.compact;
    if (width < CircleBreakpoints.mediumMax) return CircleBreakpoint.medium;
    if (width < CircleBreakpoints.expandedMax) return CircleBreakpoint.expanded;
    return CircleBreakpoint.large;
  }

  static double pagePadding(double width) => switch (breakpointFor(width)) {
    CircleBreakpoint.compact => 16,
    CircleBreakpoint.medium => 24,
    CircleBreakpoint.expanded => 32,
    CircleBreakpoint.large => 40,
  };
}

class CirclePageLayout extends StatelessWidget {
  const CirclePageLayout({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Padding(
      padding: EdgeInsets.symmetric(
        horizontal: CircleResponsive.pagePadding(constraints.maxWidth),
      ),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

class CircleFormLayout extends StatelessWidget {
  const CircleFormLayout({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final cap = width < 600 ? width : (width < 840 ? 560.0 : 640.0);
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: cap),
          child: SizedBox(width: double.infinity, child: child),
        ),
      );
    },
  );
}

class CircleContentGrid extends StatelessWidget {
  const CircleContentGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 16.0;
      final width = constraints.maxWidth;
      final columns = ((width + gap) / (280 + gap)).floor().clamp(1, 3);
      final itemWidth = (width - (columns - 1) * gap) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children)
            SizedBox(width: itemWidth, child: child),
        ],
      );
    },
  );
}
```

**Implementation note:** `CirclePageLayout` is for content **inside** a bounded screen; do not wrap the existing root navigation in it. The grid uses `Wrap` to allow variable card height; use a lazy sliver/grid for large datasets, with equivalent adaptive column rules. Avoid nested unbounded scrollables.

### 16.5 Tablet-specific behavior by screen

1. **Home:** header spans full width; primary feed may have a 600–720dp reading column, but fill remaining width with meaningful optional content (upcoming events/celebrations) on expanded layouts. If the sidebar has no data, allow the feed to grow modestly rather than show two huge empty gutters. Never stretch paragraph text to 1200dp.
2. **Circles:** change list to adaptive 2/3-column card grid; member avatars and covers remain proportional. No 393dp-centered column.
3. **Events:** use responsive event cards and a celebration/calendar rail when room permits. Keep All/Events/Celebrations tabs functional.
4. **Chat:** tablet uses a list/conversation split when supported by routing; on phone preserve one conversation per route.
5. **Create/Edit:** intentionally center a bounded form for readability; its empty sides are acceptable, unlike the feed/list pages.
6. **Profile:** cover photo spans the main content region; details can split into sections.
7. **Bottom dock:** may remain a compact centered capsule on tablets; this does **not** mean content must be compact.
8. **Landscape/split-screen:** recompute from **available** width, not device type or orientation; avoid forcing a tablet layout when the app is in a narrow window.

### 16.6 Text field / checkbox sample contracts

```dart
// Canonical sizing used inside CircleTextField / CircleCheckboxTile.
const circleInputMinHeight = 52.0;
const circleCheckboxVisualSize = 20.0;
const circleControlMinTapSize = 48.0;

// A field expands to its parent form region, not the device width.
SizedBox(
  width: double.infinity,
  child: TextFormField(
    style: Theme.of(context).textTheme.bodyMedium,
    decoration: const InputDecoration(
      labelText: 'Circle name',
      constraints: BoxConstraints(minHeight: circleInputMinHeight),
    ),
  ),
);

// Checkbox has a 20dp visual target but a >=48dp tappable row.
CheckboxListTile(
  value: isSelected,
  onChanged: onChanged,
  title: const Text('Notify members'),
  contentPadding: EdgeInsets.zero,
  controlAffinity: ListTileControlAffinity.leading,
  checkboxShape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(5),
  ),
);
```

**Important:** `CheckboxListTile`'s actual checkbox rendering and row height depend on Flutter theme and accessibility settings. Enforce visual sizing and touch targets through the reusable component and golden tests; don't shrink interactive hit areas to 20dp.

### 16.7 Required responsive golden tests (no emulator)

| Test viewport | Purpose |
|---|---|
| 360×800dp | Small Android phone |
| 393×852dp | Approved phone reference |
| 430×932dp | Large phone |
| 600×960dp | Small tablet / foldable |
| 800×1280dp | Android tablet portrait |
| 1024×768dp | Tablet landscape |
| 1280×800dp | Large Android tablet landscape |

For **each** viewport capture Home, Circles, Events, Create, and one form with textbox/checkbox/dropdown. Assert: no RenderFlex overflow, no unintended fixed-width 393/430dp canvas, no clipped controls, no navigation overlap, readable text at 1.0 and 1.3 text scale, and reasonable use of screen width. Compare tablet screenshots against tablet-specific layout rules; do not stretch the phone reference image and call it a match.

### 16.8 Mandatory Claude Code audit and implementation checklist

1. Search the existing Flutter code for `ConstrainedBox`, `maxWidth`, `SizedBox(width:)`, `FractionallySizedBox`, `Center`, `Align`, `LayoutBuilder`, `MediaQuery`, `CircleInsets`, and `SafeArea` in root screens and shared shells.
2. Identify the **exact ancestor** that limits available width on Android tablets; include file path and line number in the audit. Do not guess the cause from a screenshot.
3. Check whether any width cap belongs to a form, feed reading column, or mistakenly to the entire page.
4. Add responsive tokens and classes without changing API or routing behavior.
5. Fix root-page width constraints first; then implement grid/split layouts where needed.
6. Apply control dimensions and semantic colors via reusable widgets and `ThemeData`, not page-level hardcoded values.
7. Preserve the approved phone layout at 393dp, while creating intentional tablet layouts.
8. Render all seven viewport sizes using golden/widget tests without an emulator.
9. Show **before/after screenshots**, list modified files, and report unresolved differences. Do not claim visual verification if screenshots weren't generated.
10. Keep V1 feature scope frozen. This is a responsive UI/system consistency task, not a request to add product features.


## 17. Visual precision standards (v1.2)

> **Authority:** Approved screenshots define the visual target at their captured viewport; this document defines proposed implementation contracts. Values in this section are **defaults**, not measured facts. Record reference-derived measurements in `design_reference/measurements/*.json` before asserting pixel-perfect accuracy.

### 17.1 Coordinate system and screenshot metadata

- Flutter sizes use logical pixels (`dp`); raster screenshots use physical pixels. `physicalPixels = logicalPixels × devicePixelRatio`.
- Every golden must record: logical viewport width/height, device pixel ratio, `textScaler`, brightness, platform, locale, font family, font loading status, safe-area padding, and app commit SHA.
- Capture with a fixed deterministic clock and stable fixtures. Disable animations and network-dependent media in tests.
- Do not scale a phone screenshot to match a tablet screenshot. Maintain separately approved responsive references.
- Normalize comparison crops only for known status/navigation bars. Never use image resizing to conceal layout mismatch.
- Suggested golden fixture baseline: 393×852 logical px, DPR 1, light theme, text scale 1.0; this is a **test convention**, not a statement about the original image DPR.

### 17.2 Geometry measurement contracts

Create `CircleVisualKeys` containing stable keys for `header`, `composer`, `quickActions`, `firstMemoryCard`, `firstMemoryCollage`, `floatingDock`, `circleList`, `eventList` and `primaryButton`. In widget tests, measure each target's `Rect` using the actual render object after layout, not inferred parent sizes.

For each element store `x`, `y`, `width`, `height`, `radius`, `padding`, `gap` (where measurable), and `visibility`. Compare against an approved per-viewport geometry JSON. Define tolerances explicitly: **±2 logical px** for key geometry at baseline viewport is a proposed starting threshold; allow documented exceptions for font rendering and image content. Fail for clipping, overlapping touch targets, and out-of-bounds geometry even when pixel diff is low.

### 17.3 Typography rendering contract

- Use `CircleTypography` / `Theme.of(context).textTheme` only. Do not create arbitrary inline `TextStyle` in feature screens.
- Font family: bundled PlusJakartaSans per Section 4; load all declared weights in widget tests. Never let goldens silently fall back to Ahem or a missing font.
- Document font size, weight, height, letter spacing, `maxLines`, overflow, alignment, and `textScaler` behavior for each text role.
- Test at text scales **1.0, 1.3, 2.0**; for 2.0, prioritize readable wrapping and non-overlap over screenshot identity.
- Test long names, long group titles, empty strings, emojis, mixed English/Tamil text and RTL layout resilience where applicable.
- Use `TextPainter` or actual `RenderParagraph` measurements for text baselines and line count; avoid manual top offsets to compensate for font metrics.

### 17.4 Icon contract and font reliability

- Use `flutter_lucide` consistently and centralized `CircleIcons` mappings. Validate that each selected `LucideIcons.*` symbol exists in the installed package.
- Default action icon box **24×24dp**, glyph nominal **20–22dp**; small metadata glyph **16dp**, prominent feature icon **24dp**. Use tokenized sizes; verify optical centering in goldens.
- Lucide icon fonts expose fixed glyph artwork; `Icon` does **not** generally support arbitrary stroke-width changes. To require a specific stroke thickness, use an approved SVG with fixed stroke width or another supported vector asset, and document the exception.
- Icon states: normal `caption`, active `primary`, destructive `error`, disabled semantic onSurface at reduced opacity. Keep hit targets **≥48×48dp**, even for 20dp artwork.
- Ensure the Lucide font is available in test rendering; assert no missing-glyph boxes. Test icon fallback explicitly.

### 17.5 Image, media and avatar contract

- Document `BoxFit`, aspect ratio, clipping radius, image alignment, placeholders, loading and failure states per component.
- For the three-photo Home collage: use a deterministic layout with a dominant left tile and two stacked right tiles; define shared gap and total height via named `CircleMediaGeometry` tokens, and measure rendered bounds.
- Use fixed local fixture images for goldens, never live network image URLs. Different source photography should not be counted as a geometry regression.
- Preserve focal points when cropping photos; never distort aspect ratios. Ensure avatar placeholders and `+N` overlays are tested.

### 17.6 Reusable control state matrix

All shared controls (`CircleTextField`, `CircleCheckbox`, `CircleRadio`, `CircleDropdown`, `CircleButton`, `CircleIconButton`, `CircleSegmentedTabs`, `CirclePill`, `CircleCard`) require screenshot coverage for relevant states:

| State | Required check |
|---|---|
| Default | Size, alignment, color, border and typography |
| Focused | Focus ring, border, caret, keyboard-safe layout |
| Filled / selected | Text, icon, indicator and semantic contrast |
| Disabled | Readable disabled style and no interaction |
| Error | Border, helper text, wrapping, height growth |
| Loading | No layout jump; progress semantics |
| Long content | Wrap/truncate intentionally; no overflow |
| Dark mode | Correct semantic colors and contrast |

Input sizing and tablet form max widths remain governed by Section 16. Do not apply form max-width to entire root pages.

### 17.7 Safe areas, keyboard and navigation

- Use real `MediaQuery.viewPadding`, `viewInsets`, and `SafeArea` behavior. Do not bake status bar height into fixed page padding.
- Dock bottom offset must account for device gesture navigation. Feed bottom padding must include dock height + safe-area + breathing room, preventing the last card from hiding.
- Test keyboard open on Create, Comment and Chat; text input and primary actions remain reachable.
- For Android tablets, adapt navigation and content grid based on constraints rather than stretching the phone dock indiscriminately. Keep five root destinations and their route identities.

### 17.8 Responsive layout decision rules

- Use `LayoutBuilder` / parent constraints for local layout; `MediaQuery.sizeOf` for app-level breakpoint decisions. Do not use raw physical device width or a hardcoded device model.
- At widths <600dp: one column, 16dp horizontal padding.
- At 600–839dp: adaptive one-column or two-column content, 24dp horizontal padding; never clamp all root content to 393dp.
- At ≥840dp: feed with optional supporting column; cards and form fields use independent max-width policies.
- `CirclePageLayout` must expand to available safe width. `CircleFormLayout` may center and cap editor width for readability; distinguish these wrappers in code review.
- Test portrait/landscape rotation, split screen, and 1.3× text scaling at 800×1280 and 1280×800.

### 17.9 Motion specification

- Default small-state transitions: **150–200ms** ease-out; route transitions: **220–300ms** where supported by existing routing. Values are proposals, not screenshot measurements.
- Respect reduced-motion settings; never make layout depend on animation completion.
- Golden tests should disable or settle animations deterministically before capture.

### 17.10 Screenshot diff and quality gates

Generate `actual.png`, `reference.png`, `overlay.png`, `difference.png`, and `geometry.json` per tested screen/viewport. Produce an audit with:

1. Measured component bounds and deltas (dp).
2. Pixel differences inside stable UI regions, excluding photo content when assets differ.
3. Missing icons/fonts/assets, text clipping, overflow and touch-target failures.
4. Screenshots for phone, tablet portrait, tablet landscape, light/dark, and key states.
5. Clear classification: **visually verified**, **code-inspected only**, or **not tested**.

Never declare success solely because `flutter analyze` passes or a whole-screen similarity score exceeds an arbitrary threshold. Require human review of the approved reference comparison before marking a screen visually accepted.

### 17.11 Token enforcement and migration

- Reuse existing `Space`, `CircleAccents`, `CircleRadius`, `CircleDepth`, `circleTheme` and shared components; introduce new names only where needed, then migrate incrementally.
- Add CI checks that flag raw `Color(0x...)`, ad hoc `TextStyle(fontSize:)`, arbitrary `BorderRadius.circular(...)`, and direct icon usage in feature screens. Allow documented exceptions for data visualizations and image content.
- Enforce **one owner per component**: shared header, floating dock, avatar, field, button, card and image collage must not have parallel inconsistent implementations.
- Do not globally change existing token semantics without reviewing every usage. Capture baseline goldens before migration and rerun after each shared-component change.

### 17.12 Proposed directory and class contracts

```text
lib/core/design.dart                       # Existing ThemeData, Space, CircleAccents, CircleRadius
lib/core/circle_components.dart            # Existing reusable widgets
lib/core/design/circle_typography.dart     # Named text roles (optional extraction)
lib/core/design/circle_icons.dart          # Icon mapping + size/semantic colors
lib/core/design/circle_geometry.dart       # Control dimensions, collage, dock
lib/core/design/circle_responsive.dart     # Page/form/grid layout policies
lib/core/design/circle_visual_keys.dart    # Stable test keys

design_reference/home_feed.png             # Approved source screenshot
design_reference/measurements/             # Per-screen per-viewport measured geometry
 design_reference/output/                  # Golden, overlay, diff, geometry reports

test/goldens/                              # Widget/golden tests without emulator
```

Avoid introducing a second theme object or duplicate navigation shell. Keep the V1 feature freeze.

### 17.13 Claude Code execution gate

**Step 1:** Confirm the approved reference image and authentic Circle logo are present and inspectable. If absent, ask for them; do not fabricate a reference.

**Step 2:** Audit existing theme/components and capture baseline golden screenshots. Fix Lucide/font/asset loading first.

**Step 3:** Implement the shared visual contracts, geometry capture and responsive wrappers. Do not redesign every screen at once.

**Step 4:** Migrate Home Feed first; compare reference vs actual at identical viewport and record geometry errors. Get approval before migrating Circles, Events, Create, Comments, Chat and Profile.

**Step 5:** Test tablet layouts separately and document remaining visual differences. Run `dart format`, `flutter analyze`, widget/golden tests and relevant interaction tests.

**Completion criteria:** Screenshots and geometry report exist; no unexplained overflow, missing fonts or unintended tablet width caps; existing API/state/navigation behavior preserved; outstanding visual differences explicitly listed. **Pixel-perfect remains a review outcome, not a promise.**
