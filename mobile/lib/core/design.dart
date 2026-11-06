import 'package:flutter/material.dart';
import 'design/circle_typography.dart';
import 'design/circle_icons.dart';
import 'design/circle_motion.dart';
export 'design/circle_motion.dart';

/// Decode budgets for private image previews. Full-screen viewing keeps the
/// original image resolution for pinch-to-zoom.
abstract final class CirclePhotoMetrics {
  static const thumbnailPixels = 320.0;
  static const previewMaxDecodeWidth = 1080;
  // Cover list tiles crop wide banners. Keep medium on high-DPI displays
  // instead of enlarging a short 320px-wide banner crop.
  static bool coverThumbnailFits(double pixelRatio) =>
      Space.large * 2 * pixelRatio * CircleProfileLayout.coverAspectRatio <=
      thumbnailPixels;
  static int previewDecodeWidth(double pixels) =>
      ((pixels.clamp(1, previewMaxDecodeWidth) / 64).ceil() * 64).clamp(
        1,
        previewMaxDecodeWidth,
      );
}

abstract final class CircleProfileLayout {
  static const coverAspectRatio = 3.2;
  static const minCoverHeight = 88.0, maxCoverHeight = 160.0;
}

abstract final class CircleLayout {
  static const double quickActionPaint = 40;
  static double quickActionWidth(BuildContext context, String label) {
    final style = CircleTextStyles.metadata(
      Theme.of(context).colorScheme.onSurface,
    );
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width
        .clamp(CircleSizes.minTouchTarget, double.infinity)
        .toDouble();
    painter.dispose();
    return width;
  }

  static int memoryActionColumns(BuildContext context, double width) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Comment',
        style: CircleTextStyles.label(Theme.of(context).colorScheme.onSurface),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final minimum =
        painter.width + CircleSizes.iconAction + Space.xs + Space.sm * 2;
    painter.dispose();
    return (width / minimum).floor().clamp(1, 3);
  }

  static const largeTextThreshold = 1.4;
  static const homeHeaderHeight = 56.0;
  static double headerHeight(BuildContext context, {String? title}) {
    final style = CircleTextStyles.pageTitle(
      Theme.of(context).colorScheme.onSurface,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final line = scaler.scale(style.fontSize!) * style.height!;
    var contentHeight = line;
    if (title != null) {
      final painter =
          TextPainter(
            text: TextSpan(text: title, style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 2,
          )..layout(
            maxWidth: (MediaQuery.sizeOf(context).width - Space.large * 2)
                .clamp(Space.large, double.infinity),
          );
      contentHeight = painter.height;
      painter.dispose();
    }
    final height = contentHeight + Space.sm * 2;
    return height > homeHeaderHeight ? height : homeHeaderHeight;
  }

  static const homeLogoSize = 28.0;
  static const headerActionPaintSize = 36.0;
  static const homeActionMinHeight = 48.0;
  // Minimum interactive row, not an extra block above the device inset.
  static const homeDockHeight = 48.0;
  static double navigationBottomPadding(double deviceInset) =>
      deviceInset.clamp(0.0, Space.md).toDouble();
  static double navigationItemWidth(BuildContext context) {
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    var width = Space.large;
    for (final label in ['Home', 'Circles', 'Chats', 'Events', 'Profile']) {
      painter.text = TextSpan(
        text: label,
        style: CircleTextStyles.navLabel(
          Theme.of(context).colorScheme.onSurface,
        ),
      );
      painter.layout();
      final measured = painter.width + Space.md;
      if (measured > width) width = measured;
    }
    painter.dispose();
    return width;
  }

  static const homeMosaicAspect = 2.8;
  static const homeGridBreakpoint = 840.0;
  static const homeComposerMaxWidth = 720.0;
  static const homeDockMaxWidth = 640.0;
}

/// Shared geometry for every standard input and primary form action.
abstract final class CircleFormMetrics {
  static double photoActionWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Add photos',
        style: Theme.of(context).textTheme.labelMedium,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final measured = painter.width.ceilToDouble() + Space.section;
    painter.dispose();
    return measured > 112 ? measured : 112;
  }

  static const minFieldHeight = 56.0;
  static const fieldGap = 16.0;
  static const sectionGap = 24.0;
  static const actionNoticeMargin = EdgeInsets.fromLTRB(
    Space.md,
    0,
    Space.md,
    Space.hero * 3,
  );
  static const fieldPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 16,
  );
}

/// 8-point grid. [xs] (4) is the only half-step, kept for icon-to-text
/// micro gaps; every other padding, margin and gap is a multiple of 8.
abstract final class Space {
  static const double xs = 4,
      sm = 8,
      contentInset = 12,
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
  static const _ink = Color(0xFF1C1E21);

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
  static BoxDecoration dock(BuildContext context) => BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    border: Border(top: BorderSide(color: CircleAccents.of(context).hairline)),
  );

  static WidgetStateProperty<double> get buttonLift =>
      const WidgetStatePropertyAll(0);
}

/// Immersive dark overlay colours for photo viewers and full-screen media.
abstract final class CircleOverlay {
  static const background = Colors.black;
  static const foreground = Colors.white;
  static final muted = Colors.white.withValues(alpha: 0.7);
  static final divider = Colors.white.withValues(alpha: 0.2);
  static const chipBackground = Colors.black54;
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
    recessed: Color(0xFFF0F2F5),
    hairline: Color(0xFFCED0D4),
    title: Color(0xFF1C1E21),
    caption: Color(0xFF65676B),
    activeDot: Color(0xFF3F7A68),
    chatWallpaper: Colors.white,
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
    recessed: Color(0xFF18191A),
    hairline: Color(0xFF3E4042),
    title: Color(0xFFE4E6EB),
    caption: Color(0xFFB0B3B8),
    activeDot: Color(0xFF9CCFB9),
    chatWallpaper: Color(0xFF18191A),
    chatIncoming: Color(0xFF242526),
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

/// Theme-based and explicitly styled screens resolve to exactly the same roles.
TextTheme _textTheme({required Color title, required Color body}) => TextTheme(
  displaySmall: CircleTextStyles.brand(title),
  headlineLarge: CircleTextStyles.brand(title),
  headlineMedium: CircleTextStyles.pageTitle(title),
  headlineSmall: CircleTextStyles.sectionTitle(title),
  titleLarge: CircleTextStyles.pageTitle(title),
  titleMedium: CircleTextStyles.cardTitle(title),
  titleSmall: CircleTextStyles.label(title),
  bodyLarge: CircleTextStyles.body(body),
  bodyMedium: CircleTextStyles.body(body),
  bodySmall: CircleTextStyles.metadata(body),
  labelLarge: CircleTextStyles.button(title),
  labelMedium: CircleTextStyles.label(title),
  labelSmall: CircleTextStyles.caption(body),
);

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
    surface: light ? Colors.white : const Color(0xFF242526),
    onSurface: accents.title,
    onSurfaceVariant: body,
    surfaceContainerLowest: light ? Colors.white : const Color(0xFF242526),
    surfaceContainerLow: light ? Colors.white : const Color(0xFF242526),
    surfaceContainer: accents.recessed,
    surfaceContainerHigh: light
        ? const Color(0xFFECE8E1)
        : const Color(0xFF26242B),
    surfaceContainerHighest: light
        ? const Color(0xFFE6E1D8)
        : const Color(0xFF3E4042),
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
    fontFamily: CircleTextStyles.fontFamily,
    useMaterial3: true,
    colorScheme: colors,
    textTheme: text,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _CirclePageTransitionsBuilder(),
        TargetPlatform.iOS: _CirclePageTransitionsBuilder(),
      },
    ),
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) => const Icon(CircleIcons.back),
      closeButtonIconBuilder: (_) => const Icon(CircleIcons.close),
    ),
    iconTheme: IconThemeData(
      size: CircleSizes.iconDefault,
      color: accents.title,
    ),
    extensions: [accents],
    scaffoldBackgroundColor: colors.surface,
    splashColor: pressedWash,
    highlightColor: pressedWash,
    hoverColor: pressedWash,
    appBarTheme: AppBarTheme(
      toolbarHeight: CircleLayout.homeHeaderHeight,
      centerTitle: false,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      shape: const Border(),
      titleTextStyle: text.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      constraints: const BoxConstraints(
        minHeight: CircleFormMetrics.minFieldHeight,
      ),
      labelStyle: text.bodyMedium?.copyWith(color: accents.caption),
      floatingLabelStyle: text.bodySmall?.copyWith(color: accents.caption),
      helperStyle: text.bodySmall?.copyWith(color: accents.caption),
      errorStyle: text.bodySmall?.copyWith(color: colors.error),
      errorMaxLines: 3,
      helperMaxLines: 3,
      prefixIconConstraints: const BoxConstraints(
        minWidth: Space.large,
        minHeight: CircleFormMetrics.minFieldHeight,
      ),
      suffixIconConstraints: const BoxConstraints(
        minWidth: Space.large,
        minHeight: CircleFormMetrics.minFieldHeight,
      ),
      filled: true,
      fillColor: colors.surfaceContainerLowest,
      hintStyle: text.bodyMedium?.copyWith(color: accents.caption),
      contentPadding: CircleFormMetrics.fieldPadding,
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
            minimumSize: const Size(
              Space.large,
              CircleFormMetrics.minFieldHeight,
            ),
            shape: rounded(CircleRadius.button),
            textStyle: text.labelLarge,
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
        minimumSize: const Size(Space.large, CircleFormMetrics.minFieldHeight),
        shape: rounded(CircleRadius.button),
        backgroundColor: colors.surfaceContainerLowest,
        foregroundColor: accents.title,
        side: hairline,
        textStyle: text.labelLarge,
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
      extendedTextStyle: text.labelLarge,
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
      style: IconButton.styleFrom(
        iconSize: CircleSizes.iconDefault,
        minimumSize: const Size(48, 48),
      ),
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

/// Fade + gentle slide-up for all page transitions.
class _CirclePageTransitionsBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final fade = CurvedAnimation(
      parent: animation,
      curve: CircleMotion.enterCurve,
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(fade);
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
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
  static const small = 8.0, input = 10.0;

  /// Buttons are pills: half of the 48px minimum height.
  static const button = 10.0;

  /// Photo mosaics and image tiles.
  static const photo = 4.0;

  /// Tiles, inner panels, cards, menus and floating buttons.
  static const tile = 12.0, inner = 12.0, card = 12.0;

  /// Sheets, dialogs and hero surfaces.
  static const sheet = 16.0, hero = sheet;

  /// Chips, avatars, badges and micro-tags.
  static const pill = 999.0;
}

/// Standard page padding: 24px editorial margins, with room at the bottom
/// so the floating dock and action button never cover the last item.
abstract final class CircleInsets {
  static const content = EdgeInsets.symmetric(horizontal: Space.contentInset);

  /// Root lists share Home's compact side inset and clear the floating dock.
  static const rootPage = EdgeInsets.fromLTRB(
    Space.contentInset,
    Space.sm,
    Space.contentInset,
    Space.hero * 3,
  );
  static const page = EdgeInsets.fromLTRB(
    Space.contentInset,
    Space.sm,
    Space.contentInset,
    Space.hero * 3,
  );

  /// Pages without a floating action button (details, forms, settings).
  static const form = EdgeInsets.fromLTRB(
    Space.contentInset,
    Space.md,
    Space.contentInset,
    Space.hero,
  );
}

/// Centers content within a responsive reading column.
///
/// On compact phones (<600dp) the content fills available width.
/// On tablets and wider screens the column caps at 720dp for feeds
/// or 640dp for forms, keeping text readable without wasting space.
/// Root pages that need full width should use [CirclePageLayout] instead.
class ReadingPane extends StatelessWidget {
  const ReadingPane({super.key, required this.child, this.maxWidth});

  /// Override the default responsive cap. Pass `double.infinity` for
  /// truly uncapped width (e.g. photo grids on tablets).
  final double? maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final available = MediaQuery.sizeOf(context).width;
    final cap = maxWidth ?? (available < 600 ? available : 720.0);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cap),
        child: child,
      ),
    );
  }
}
