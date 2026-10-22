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

ThemeData circleTheme(Brightness brightness) {
  final generated = ColorScheme.fromSeed(
    seedColor: const Color(0xFF245748),
    brightness: brightness,
    surface: brightness == Brightness.light
        ? const Color(0xFFFAF8F2)
        : const Color(0xFF171D1A),
  );
  final colors = generated.copyWith(
    tertiaryContainer: brightness == Brightness.light
        ? const Color(0xFFF1DFC4)
        : const Color(0xFF53432D),
    onTertiaryContainer: brightness == Brightness.light
        ? const Color(0xFF3A2D1A)
        : const Color(0xFFF8E3BF),
  );
  return ThemeData(
    fontFamily: 'CircleRoboto',
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: const AppBarTheme(centerTitle: false),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: Space.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.section,
          vertical: Space.md,
        ),
      ),
    ),
  );
}

class ReadingPane extends StatelessWidget {
  const ReadingPane({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: child,
    ),
  );
}

class ArchiveArt extends StatelessWidget {
  const ArchiveArt({
    super.key,
    this.label = 'The places that made us',
    this.icon = Icons.school_outlined,
  });
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Fictional archive illustration: $label',
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.hero),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
          const SizedBox(height: Space.lg),
          Text(
            label,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Space.section),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Space.md),
        Text(message, textAlign: TextAlign.center),
        if (action != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.lg),
            child: action,
          ),
      ],
    ),
  );
}
