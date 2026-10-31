import 'package:flutter/material.dart';

abstract final class CircleProfileLayout {
  static const coverAspectRatio = 2.6;
  static const minCoverHeight = 112.0, maxCoverHeight = 200.0;
}

abstract final class CircleLayout {
  static const largeTextThreshold = 1.4;
}

/// 8-point grid. [xs] (4) is the only half-step, kept for icon-to-text
/// micro gaps; every other padding, margin and gap is a multiple of 8.
abstract final class Space {
  static const double xs = 4,
      sm = 8,
      md = 16,
      lg = 16,
      xl = 24,
      section = 24,
      hero = 32,
      large = 48;
}

/// Editorial surfaces are flat: a quiet fill and, where needed, a hairline.
/// Only the floating dock keeps one soft shadow so it reads above content.
abstract final class CircleDepth {
  static const cardElevation = 0.0;
  static const buttonElevation = 0.0;
  static const pressedElevation = 0.0;
  static const floatingElevation = 2.0;
  static const _ink = Color(0xFF1C1B22);

  static Color shadow(Brightness brightness) => brightness == Brightness.light
      ? _ink.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.40);

  static BoxDecoration panel(
    BuildContext context, {
    required double radius,
    Color? tint,
  }) => BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    color: tint ?? Theme.of(context).colorScheme.surfaceContainer,
  );

  static BoxDecoration profilePanel(BuildContext context) => panel(
    context,
    radius: CircleRadius.sheet,
    tint: Theme.of(context).colorScheme.surfaceContainer,
  );

  /// The floating navigation dock: surface, hairline and one soft shadow.
  static BoxDecoration dock(BuildContext context) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(CircleRadius.sheet),
      border: Border.all(color: CircleAccents.of(context).hairline),
      boxShadow: [
        BoxShadow(
          color: shadow(theme.brightness),
          offset: const Offset(0, 8),
          blurRadius: 24,
          spreadRadius: -4,
        ),
      ],
    );
  }

  static WidgetStateProperty<double> get buttonLift =>
      const WidgetStatePropertyAll(0);
}

/// Editorial, photo-first (owner, 28 Oct 2026). 60/30/10: 60% white
/// surface, 30% warm neutral fills and ink text, 10% deep indigo for the one
/// primary action, selection and love. Photos carry the colour, not chrome.
/// Sage is kept only for confirmations; group identity always has a name.
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
    required this.video,
    required this.videoContainer,
    required this.amber,
    required this.amberContainer,
    required this.recessed,
    required this.hairline,
    required this.title,
    required this.caption,
    required this.activeDot,
    required this.chatWallpaper,
    required this.chatIncoming,
    required this.chatOutgoing,
  });

  /// Love and reactions: the primary indigo (a vector heart, never emoji).
  final Color heart, heartText, heartContainer;

  /// Selection and focus: a faint indigo wash with indigo text.
  final Color calm, calmText, calmContainer;

  /// Supporting sage family (events, confirmations, secondary groups).
  final Color sage, sageText, sageContainer;

  /// Video tile accent and poll/amber tile accent.
  final Color video, videoContainer, amber, amberContainer;

  /// Recessed fills (comment previews, tiles) and the 1px hairline border.
  final Color recessed, hairline;

  /// Title ink (#1C1B22) and warm caption grey (#6B6878). Body copy is the
  /// scheme's onSurfaceVariant (#34323C) via the text theme.
  final Color title, caption;

  /// The "Active now" dot on a person's avatar: sage,
  /// drawn with a ring of the surface colour.
  final Color activeDot;

  /// Chat (WhatsApp-style): the conversation background behind bubbles,
  /// incoming bubbles and the viewer's own (outgoing) bubbles.
  final Color chatWallpaper, chatIncoming, chatOutgoing;

  static const light = CircleAccents(
    heart: Color(0xFFFF4054),
    heartText: Color(0xFFFF4054),
    heartContainer: Color(0xFFEFECF7),
    calm: Color(0xFF4930A7),
    calmText: Color(0xFF4930A7),
    calmContainer: Color(0xFFEFECF7),
    sage: Color(0xFF3F7A68),
    sageText: Color(0xFF2F6153),
    sageContainer: Color(0xFFE6EFE9),
    video: Color(0xFFE05252),
    videoContainer: Color(0xFFFDE8E8),
    amber: Color(0xFFD68F00),
    amberContainer: Color(0xFFFFF3DB),
    recessed: Color(0xFFF5F5F8),
    hairline: Color(0xFFECECF2),
    title: Color(0xFF1C1B22),
    caption: Color(0xFF6B6878),
    activeDot: Color(0xFF3F7A68),
    chatWallpaper: Color(0xFFEFEAE2),
    chatIncoming: Color(0xFFFFFFFF),
    chatOutgoing: Color(0xFFE4DEFA),
  );

  static const dark = CircleAccents(
    heart: Color(0xFFC9C0FF),
    heartText: Color(0xFFE2DCFF),
    heartContainer: Color(0xFF2A2547),
    calm: Color(0xFFC9C0FF),
    calmText: Color(0xFFE2DCFF),
    calmContainer: Color(0xFF2A2547),
    sage: Color(0xFF9CCFB9),
    sageText: Color(0xFFC3E6D6),
    sageContainer: Color(0xFF1B3A30),
    video: Color(0xFFFF8A80),
    videoContainer: Color(0xFF442727),
    amber: Color(0xFFFFCC80),
    amberContainer: Color(0xFF3E2F10),
    recessed: Color(0xFF1E1C22),
    hairline: Color(0xFF2C2A31),
    title: Color(0xFFF2EFEA),
    caption: Color(0xFFA19DAA),
    activeDot: Color(0xFF9CCFB9),
    chatWallpaper: Color(0xFF0E0D12),
    chatIncoming: Color(0xFF1F1E25),
    chatOutgoing: Color(0xFF332B66),
  );

  static CircleAccents of(BuildContext context) =>
      Theme.of(context).extension<CircleAccents>() ?? light;

  @override
  CircleAccents copyWith() => this;

  @override
  CircleAccents lerp(ThemeExtension<CircleAccents>? other, double t) =>
      other is CircleAccents && t >= 0.5 ? other : this;
}

const _font = 'Roboto';

/// Editorial type: exactly four sizes (28 / 20 / 16 / 13) and two weights
/// (400 / 600), all in the app's bundled Roboto. Headlines get slightly
/// tighter tracking. Body text stays 16px for readability (§4.0).
TextTheme _textTheme({required Color title, required Color body}) {
  TextStyle sans(double size, FontWeight weight, double height, Color ink) =>
      TextStyle(
        fontFamily: _font,
        fontSize: size,
        fontWeight: weight,
        height: height / size,
        letterSpacing: 0,
        color: ink,
      );
  TextStyle headline(double size, double height) => TextStyle(
    fontFamily: _font,
    fontSize: size,
    fontWeight: FontWeight.w600,
    height: height / size,
    letterSpacing: -0.02 * size,
    color: title,
  );
  return TextTheme(
    displaySmall: headline(28, 36),
    headlineLarge: headline(28, 36),
    headlineMedium: headline(28, 36),
    headlineSmall: headline(20, 28),
    titleLarge: headline(20, 28),
    titleMedium: sans(16, FontWeight.w600, 24, title),
    titleSmall: sans(13, FontWeight.w600, 16, title),
    bodyLarge: sans(16, FontWeight.w400, 24, body),
    bodyMedium: sans(16, FontWeight.w400, 24, body),
    bodySmall: sans(13, FontWeight.w400, 16, body),
    labelLarge: sans(16, FontWeight.w600, 24, title),
    labelMedium: sans(13, FontWeight.w600, 16, title),
    labelSmall: sans(13, FontWeight.w400, 16, title),
  );
}

/// Editorial, photo-first (owner, 28 Oct 2026): white canvas, warm neutral
/// fills, ink text and one deep indigo accent, built on Material 3 tokens.
ThemeData circleTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final accents = light ? CircleAccents.light : CircleAccents.dark;
  final generated = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4930A7),
    brightness: brightness,
  );
  final body = light ? const Color(0xFF34323C) : const Color(0xFFD6D2DA);
  final colors = generated.copyWith(
    primary: light ? const Color(0xFF4930A7) : const Color(0xFFC9C0FF),
    onPrimary: light ? Colors.white : const Color(0xFF1E1660),
    primaryContainer: accents.calmContainer,
    onPrimaryContainer: accents.calmText,
    secondary: light ? const Color(0xFF4930A7) : const Color(0xFFC9C0FF),
    onSecondary: light ? Colors.white : const Color(0xFF1E1660),
    secondaryContainer: accents.calmContainer,
    onSecondaryContainer: accents.calmText,
    tertiary: accents.sageText,
    tertiaryContainer: accents.sageContainer,
    onTertiaryContainer: accents.sageText,
    surface: light ? Colors.white : const Color(0xFF121116),
    onSurface: accents.title,
    onSurfaceVariant: body,
    surfaceContainerLowest: light ? Colors.white : const Color(0xFF17161B),
    surfaceContainerLow: light ? Colors.white : const Color(0xFF17161B),
    surfaceContainer: accents.recessed,
    surfaceContainerHigh: light
        ? const Color(0xFFECE8E1)
        : const Color(0xFF26242B),
    surfaceContainerHighest: light
        ? const Color(0xFFE6E1D8)
        : const Color(0xFF2C2A31),
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
      shape: const Border(),
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
      shape: const StadiumBorder(),
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      extendedTextStyle: text.labelLarge?.copyWith(fontSize: 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      shadowColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      // No pill: the indigo icon and semibold label carry selection.
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colors.primary
              : accents.caption,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? colors.primary
              : accents.caption,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: accents.hairline, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      // Flat ink on white: tinted shadows render as hard rings.
      elevation: 0,
      backgroundColor: accents.title,
      contentTextStyle: text.bodyMedium?.copyWith(color: colors.surface),
      actionTextColor: light ? accents.calmContainer : colors.primary,
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
      labelStyle: text.labelMedium,
      unselectedLabelStyle: text.labelMedium?.copyWith(
        fontWeight: FontWeight.w400,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: Space.sm),
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
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
      ),
    ),
  );
}

/// Fades the trailing edge of a horizontally scrolling row (tabs, chips) so
/// an item cut by the screen edge reads as "scroll for more".
class CircleEdgeFade extends StatelessWidget {
  const CircleEdgeFade({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) {
      final rtl = Directionality.of(context) == TextDirection.rtl;
      return LinearGradient(
        begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
        end: rtl ? Alignment.centerLeft : Alignment.centerRight,
        colors: const [Colors.black, Colors.black, Colors.transparent],
        stops: const [0, 0.88, 1],
      ).createShader(rect);
    },
    child: child,
  );
}

/// Corner radii on the 8-point grid. Use these names, never numbers.
abstract final class CircleRadius {
  /// Checkbox corners (the 4px half-step).
  static const xsmall = 4.0;

  /// Core interactive elements, tooltips and input fields.
  static const small = 8.0, input = 8.0;

  /// Buttons are pills: half of the 48px minimum height.
  static const button = 24.0;

  /// Tiles, inner panels, cards, menus and floating buttons.
  static const tile = 16.0, inner = 16.0, card = 16.0;

  /// Sheets, dialogs and hero surfaces.
  static const sheet = 24.0, hero = sheet;

  /// Chips, avatars, badges and micro-tags.
  static const pill = 999.0;
}

/// Standard page padding: 24px editorial margins, with room at the bottom
/// so the floating dock and action button never cover the last item.
abstract final class CircleInsets {
  static const page = EdgeInsets.fromLTRB(
    Space.section,
    Space.sm,
    Space.section,
    Space.hero * 3,
  );

  /// Pages without a floating action button (details, forms, settings).
  static const form = EdgeInsets.fromLTRB(
    Space.section,
    Space.sm,
    Space.section,
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
