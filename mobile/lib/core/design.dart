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

/// Shared soft-depth lighting: bright upper edge, tinted lower surface,
/// and a restrained downward shadow. Text and fields retain clear borders.
abstract final class CircleDepth {
  static const cardElevation = 3.0;
  static const buttonElevation = 4.0;
  static const pressedElevation = 1.0;
  static const floatingElevation = 6.0;
  static const _ink = Color(0xFF262047);

  static Color shadow(Brightness brightness) => brightness == Brightness.light
      ? _ink.withValues(alpha: 0.18)
      : Colors.black.withValues(alpha: 0.48);

  static BoxDecoration panel(
    BuildContext context, {
    required double radius,
    Color? tint,
  }) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final surface = tint ?? theme.colorScheme.surfaceContainer;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(surface, theme.colorScheme.surface, light ? 0.72 : 0.12)!,
          surface,
        ],
      ),
      border: Border.all(
        color: light
            ? Colors.white.withValues(alpha: 0.9)
            : theme.colorScheme.outlineVariant,
      ),
      boxShadow: [
        BoxShadow(
          color: shadow(theme.brightness),
          offset: const Offset(0, 6),
          blurRadius: 16,
          spreadRadius: -5,
        ),
      ],
    );
  }

  static BoxDecoration profilePanel(BuildContext context) =>
      panel(
        context,
        radius: CircleRadius.sheet,
        tint: CircleAccents.of(context).calmContainer,
      ).copyWith(
        boxShadow: [
          BoxShadow(
            color: shadow(Theme.of(context).brightness),
            offset: const Offset(0, 10),
            blurRadius: 24,
            spreadRadius: -6,
          ),
        ],
      );

  static WidgetStateProperty<double> get buttonLift =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return 0;
        if (states.contains(WidgetState.pressed)) return pressedElevation;
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return floatingElevation;
        }
        return buttonElevation;
      });
}

/// Warm Keepsake on White: indigo structure, lavender selection, coral
/// reactions and sage confirmations. Semantic roles keep colour consistent
/// across every feature; group identity also always has an icon and name.
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

  /// Love and reactions: warm coral with an accessible text variant.
  final Color heart, heartText, heartContainer;

  /// Selection and focus: soft lavender with darker accessible text.
  final Color calm, calmText, calmContainer;

  /// Supporting sage family (events, confirmations, secondary groups).
  final Color sage, sageText, sageContainer;

  /// Recessed fills (comment previews, tiles) and the 1px hairline border.
  final Color recessed, hairline;

  /// Title charcoal (#1A1D2E) and caption slate (#667085). Body copy is the
  /// scheme's onSurfaceVariant-style slate (#475467) via the text theme.
  final Color title, caption;

  /// The "Active now" dot on a person's avatar: sage,
  /// drawn with a ring of the surface colour.
  final Color activeDot;

  static const light = CircleAccents(
    heart: Color(0xFFC24534),
    heartText: Color(0xFF9C3426),
    heartContainer: Color(0xFFFFE8E1),
    calm: Color(0xFF5753AC),
    calmText: Color(0xFF46408D),
    calmContainer: Color(0xFFEAE7FF),
    sage: Color(0xFF297B6F),
    sageText: Color(0xFF23675D),
    sageContainer: Color(0xFFE0F3ED),
    recessed: Color(0xFFF0F3FF),
    hairline: Color(0xFFEAEDF5),
    title: Color(0xFF1A1D2E),
    caption: Color(0xFF667085),
    activeDot: Color(0xFF297B6F),
  );

  static const dark = CircleAccents(
    heart: Color(0xFFFFB4A6),
    heartText: Color(0xFFFFDAD3),
    heartContainer: Color(0xFF4E211C),
    calm: Color(0xFFC4C0FF),
    calmText: Color(0xFFE3DFFF),
    calmContainer: Color(0xFF2C2854),
    sage: Color(0xFF9FD8C8),
    sageText: Color(0xFFC2EBDD),
    sageContainer: Color(0xFF183E36),
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

/// Warm Keepsake on White (owner, 26 Oct 2026): white canvas and cards,
/// indigo actions, lavender panels, coral reactions and sage confirmations.
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
    secondary: light ? const Color(0xFF5753AC) : const Color(0xFFC4C0FF),
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
        ? const Color(0xFFEAE7FF)
        : const Color(0xFF1E2333),
    surfaceContainerHighest: light
        ? const Color(0xFFE2E8F9)
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
      elevation: CircleDepth.cardElevation,
      shadowColor: CircleDepth.shadow(brightness),
      surfaceTintColor: Colors.transparent,
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
      style:
          FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: rounded(CircleRadius.button),
            textStyle: text.labelLarge?.copyWith(fontSize: 16),
            padding: const EdgeInsets.symmetric(
              horizontal: Space.section,
              vertical: Space.md,
            ),
          ).copyWith(
            elevation: CircleDepth.buttonLift,
            shadowColor: WidgetStatePropertyAll(CircleDepth.shadow(brightness)),
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
      elevation: CircleDepth.floatingElevation,
      focusElevation: CircleDepth.floatingElevation,
      hoverElevation: CircleDepth.floatingElevation,
      highlightElevation: CircleDepth.pressedElevation,
      extendedTextStyle: text.labelLarge?.copyWith(fontSize: 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: CircleDepth.cardElevation,
      shadowColor: CircleDepth.shadow(brightness),
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
