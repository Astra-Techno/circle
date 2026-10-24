import 'package:flutter/material.dart';

abstract final class Space {
  static const double xs = 4,
      sm = 8,
      md = 12,
      lg = 16,
      xl = 20,
      section = 24,
      hero = 32,
      large = 40;
}

/// "Luminous Pure Minimal" roles that Material's [ColorScheme] has no slot
/// for. The design is monochrome: deep indigo on pure white, slate text and
/// cool hairlines, with no saturated accents. The `heart`, `calm` and `sage`
/// families keep their names so screens don't change, but all resolve to
/// quiet indigo/slate washes; groups are told apart by icon and name.
@immutable
class CircleAccents extends ThemeExtension<CircleAccents> {
  const CircleAccents({
    required this.heart,
    required this.heartText,
    required this.heartContainer,
    required this.calm,
    required this.calmText,
    required this.calmContainer,
    required this.sage,
    required this.sageText,
    required this.sageContainer,
    required this.recessed,
    required this.hairline,
    required this.title,
    required this.caption,
    required this.activeDot,
  });

  /// Love and reactions (a filled indigo heart, no alarm colours).
  final Color heart, heartText, heartContainer;

  /// Selection and focus: the indigo wash (#1B223C at about 6%).
  final Color calm, calmText, calmContainer;

  /// Supporting slate family (events, confirmations, secondary groups).
  final Color sage, sageText, sageContainer;

  /// Recessed fills (comment previews, tiles) and the 1px hairline border.
  final Color recessed, hairline;

  /// Title charcoal (#1A1D2E) and caption slate (#667085). Body copy is the
  /// scheme's onSurfaceVariant-style slate (#475467) via the text theme.
  final Color title, caption;

  /// The "Active now" dot on a person's avatar: solid indigo (no new hue),
  /// drawn with a ring of the surface colour.
  final Color activeDot;

  static const light = CircleAccents(
    heart: Color(0xFF1B223C),
    heartText: Color(0xFF1B223C),
    heartContainer: Color(0xFFF1F2F6),
    calm: Color(0xFF1B223C),
    calmText: Color(0xFF1B223C),
    calmContainer: Color(0xFFF1F2F6),
    sage: Color(0xFF475467),
    sageText: Color(0xFF344054),
    sageContainer: Color(0xFFF2F4F7),
    recessed: Color(0xFFF6F7FA),
    hairline: Color(0xFFEAEDF5),
    title: Color(0xFF1A1D2E),
    caption: Color(0xFF667085),
    activeDot: Color(0xFF1B223C),
  );

  static const dark = CircleAccents(
    heart: Color(0xFFDCE1FF),
    heartText: Color(0xFFDCE1FF),
    heartContainer: Color(0xFF1E2333),
    calm: Color(0xFFDCE1FF),
    calmText: Color(0xFFDCE1FF),
    calmContainer: Color(0xFF1E2333),
    sage: Color(0xFFB0B8C8),
    sageText: Color(0xFFC9D0DC),
    sageContainer: Color(0xFF1C212B),
    recessed: Color(0xFF181B24),
    hairline: Color(0xFF262B38),
    title: Color(0xFFF0F1F7),
    caption: Color(0xFF98A2B3),
    activeDot: Color(0xFFDCE1FF),
  );

  static CircleAccents of(BuildContext context) =>
      Theme.of(context).extension<CircleAccents>() ?? light;

  @override
  CircleAccents copyWith() => this;

  @override
  CircleAccents lerp(ThemeExtension<CircleAccents>? other, double t) =>
      other is CircleAccents && t >= 0.5 ? other : this;
}

const _font = 'PlusJakartaSans';

/// The design's scale with negative tracking on headlines. One readability
/// exception (README §4.0, ages 15–75): everyday body text stays 16px
/// (`body-lg`) instead of the design's 14px default; 14px is secondary text.
TextTheme _textTheme({required Color title, required Color body}) {
  TextStyle style(
    double size,
    FontWeight weight,
    double height,
    double em,
    Color ink,
  ) => TextStyle(
    fontFamily: _font,
    fontSize: size,
    fontWeight: weight,
    height: height / size,
    letterSpacing: em * size,
    color: ink,
  );
  return TextTheme(
    displaySmall: style(32, FontWeight.w700, 40, -0.03, title),
    headlineLarge: style(26, FontWeight.w700, 34, -0.025, title),
    headlineMedium: style(22, FontWeight.w600, 28, -0.02, title),
    headlineSmall: style(18, FontWeight.w600, 24, -0.015, title),
    titleLarge: style(18, FontWeight.w600, 24, -0.015, title),
    titleMedium: style(16, FontWeight.w600, 22, -0.01, title),
    titleSmall: style(14, FontWeight.w600, 20, 0, title),
    bodyLarge: style(16, FontWeight.w400, 24, -0.01, body),
    bodyMedium: style(16, FontWeight.w400, 24, -0.01, body),
    bodySmall: style(14, FontWeight.w400, 20, -0.005, body),
    labelLarge: style(14, FontWeight.w600, 20, 0.01, title),
    labelMedium: style(12, FontWeight.w600, 16, 0.02, title),
    labelSmall: style(11, FontWeight.w500, 14, 0.03, title),
  );
}

/// "Luminous Pure Minimal" (owner choice, 23 Oct 2026): pure white canvas
/// and cards, deep indigo actions, slate text, cool hairlines and ambient
/// depth instead of grey stacking. See docs/design-system.md.
ThemeData circleTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final accents = light ? CircleAccents.light : CircleAccents.dark;
  final generated = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1B223C),
    brightness: brightness,
  );
  final body = light ? const Color(0xFF475467) : const Color(0xFFC3C9D5);
  final colors = generated.copyWith(
    primary: light ? const Color(0xFF1B223C) : const Color(0xFFDCE1FF),
    onPrimary: light ? Colors.white : const Color(0xFF131A34),
    primaryContainer: accents.calmContainer,
    onPrimaryContainer: accents.calmText,
    secondary: light ? const Color(0xFF475467) : const Color(0xFFB0B8C8),
    onSecondary: light ? Colors.white : const Color(0xFF101828),
    secondaryContainer: accents.calmContainer,
    onSecondaryContainer: accents.calmText,
    tertiary: accents.sageText,
    tertiaryContainer: accents.sageContainer,
    onTertiaryContainer: accents.sageText,
    surface: light ? Colors.white : const Color(0xFF0F1117),
    onSurface: accents.title,
    onSurfaceVariant: body,
    surfaceContainerLowest: light ? Colors.white : const Color(0xFF151821),
    surfaceContainerLow: light ? Colors.white : const Color(0xFF151821),
    surfaceContainer: accents.recessed,
    surfaceContainerHigh: light
        ? const Color(0xFFF1F2F6)
        : const Color(0xFF1E2333),
    surfaceContainerHighest: light
        ? const Color(0xFFEAEDF5)
        : const Color(0xFF262B38),
    outline: accents.caption,
    outlineVariant: accents.hairline,
  );
  final text = _textTheme(title: accents.title, body: body);
  final hairline = BorderSide(color: accents.hairline);
  final pressedWash = colors.primary.withValues(alpha: 0.06);
  RoundedRectangleBorder rounded(double radius, {BorderSide? side}) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: side ?? BorderSide.none,
      );
  return ThemeData(
    fontFamily: _font,
    useMaterial3: true,
    colorScheme: colors,
    textTheme: text,
    extensions: [accents],
    scaffoldBackgroundColor: colors.surface,
    splashColor: pressedWash,
    highlightColor: pressedWash,
    hoverColor: pressedWash,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      shape: Border(bottom: hairline),
      titleTextStyle: text.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerLowest,
      hintStyle: text.bodyMedium?.copyWith(color: accents.caption),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CircleRadius.input),
        borderSide: hairline,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CircleRadius.input),
        borderSide: hairline,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CircleRadius.input),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      // Hairline edge on white; the design's micro-shadow is too faint to
      // matter on screen and renders as a hard ring in goldens.
      elevation: 0,
      color: colors.surfaceContainerLowest,
      margin: const EdgeInsets.only(bottom: Space.lg),
      shape: rounded(CircleRadius.card, side: hairline),
    ),
    chipTheme: ChipThemeData(
      shape: StadiumBorder(side: hairline),
      side: hairline,
      backgroundColor: colors.surfaceContainerLowest,
      selectedColor: colors.primary,
      labelStyle: text.labelMedium?.copyWith(color: body),
      secondaryLabelStyle: text.labelMedium?.copyWith(color: colors.onPrimary),
      checkmarkColor: colors.onPrimary,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: rounded(CircleRadius.button),
        textStyle: text.labelLarge?.copyWith(fontSize: 16),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.section,
          vertical: Space.md,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: rounded(CircleRadius.button),
        backgroundColor: colors.surfaceContainerLowest,
        foregroundColor: accents.title,
        side: hairline,
        textStyle: text.labelLarge?.copyWith(fontSize: 16),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.section,
          vertical: Space.md,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: colors.primary,
        shape: rounded(CircleRadius.button),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
      shape: rounded(CircleRadius.card),
      // Flat: tinted shadows render as hard rings in goldens.
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      extendedTextStyle: text.labelLarge?.copyWith(fontSize: 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      // The selected indicator pill is solid indigo with a white icon.
      indicatorColor: colors.primary,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colors.onPrimary
              : accents.caption,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? accents.title
              : accents.caption,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: accents.hairline, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      // Flat indigo on white: tinted shadows render as hard rings.
      elevation: 0,
      backgroundColor: colors.primary,
      contentTextStyle: text.bodySmall?.copyWith(color: colors.onPrimary),
      actionTextColor: light ? accents.hairline : accents.calmContainer,
      shape: rounded(CircleRadius.button),
    ),
    // Lists are rows separated by hairline dividers (see CircleRow).
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
      minVerticalPadding: Space.md,
      horizontalTitleGap: Space.md,
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodySmall?.copyWith(color: accents.caption),
      iconColor: accents.caption,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.onPrimary
            : accents.caption,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.primary
            : colors.surfaceContainerLowest,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.primary
            : accents.hairline,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? colors.primary : null,
      ),
      checkColor: WidgetStatePropertyAll(colors.onPrimary),
      side: BorderSide(color: accents.hairline, width: 1.5),
      shape: rounded(CircleRadius.xsmall),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.primary
            : accents.hairline,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: accents.title,
      unselectedLabelColor: accents.caption,
      labelStyle: text.labelLarge,
      unselectedLabelStyle: text.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      indicatorColor: colors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: accents.hairline,
      tabAlignment: TabAlignment.start,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: rounded(CircleRadius.sheet, side: hairline),
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: accents.hairline,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CircleRadius.sheet),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      textStyle: text.bodyMedium,
      shape: rounded(CircleRadius.card, side: hairline),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerLowest),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          rounded(CircleRadius.card, side: hairline),
        ),
      ),
    ),
    badgeTheme: BadgeThemeData(
      // Counts that need the person: indigo, not alarm red (§4.0).
      backgroundColor: colors.primary,
      textColor: colors.onPrimary,
      textStyle: text.labelSmall,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: text.bodySmall?.copyWith(color: colors.onPrimary),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(CircleRadius.small),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.primary,
      linearTrackColor: accents.hairline,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: text.bodyMedium,
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerLowest),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: colors.primary,
        selectedForegroundColor: colors.onPrimary,
        side: hairline,
        shape: rounded(CircleRadius.button),
      ),
    ),
  );
}

/// Corner radii from the design. Use these names, never numbers.
abstract final class CircleRadius {
  /// Checkbox corners.
  static const xsmall = 4.0;

  /// Core interactive elements, tooltips.
  static const small = 8.0;

  /// Input fields.
  static const input = 10.0;

  /// Buttons, tiles and inner panels.
  static const button = 12.0, tile = 12.0, inner = 12.0;

  /// Cards, menus and floating buttons.
  static const card = 16.0;

  /// Sheets, dialogs and hero surfaces.
  static const sheet = 24.0, hero = sheet;

  /// Chips, avatars, badges and micro-tags.
  static const pill = 999.0;
}

/// Standard page padding: 16px mobile margins, with room at the bottom so
/// the floating action button never covers the last item.
abstract final class CircleInsets {
  static const page = EdgeInsets.fromLTRB(
    Space.lg,
    Space.md,
    Space.lg,
    Space.hero * 3,
  );

  /// Pages without a floating action button (details, forms, settings).
  static const form = EdgeInsets.fromLTRB(
    Space.lg,
    Space.md,
    Space.lg,
    Space.hero,
  );
}

/// Centers content within the design's 640px handheld-first column.
class ReadingPane extends StatelessWidget {
  const ReadingPane({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: child,
    ),
  );
}
