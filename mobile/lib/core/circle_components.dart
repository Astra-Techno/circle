import 'package:flutter/material.dart';
import 'design.dart';

abstract final class CircleRadius {
  static const input = 8.0, tile = 12.0, card = 16.0, hero = 24.0;
}

class CircleCover extends StatelessWidget {
  const CircleCover({
    super.key,
    required this.title,
    required this.icon,
    this.compact = false,
  });
  final String title;
  final IconData icon;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: 'Original fictional illustration: $title',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? Space.xl : Space.hero),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CircleRadius.hero),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.primaryContainer, colors.tertiaryContainer],
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: compact ? 40 : 64,
              color: colors.onPrimaryContainer,
            ),
            const SizedBox(height: Space.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CircleHeading extends StatelessWidget {
  const CircleHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
  });
  final String title, subtitle;
  final String? eyebrow;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.section),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(eyebrow!, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: Space.sm),
        ],
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: Space.sm),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}

class CircleEmpty extends StatelessWidget {
  const CircleEmpty({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Space.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.blur_circular,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: Space.lg),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.sm),
          Text(message),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.lg),
              child: action,
            ),
        ],
      ),
    ),
  );
}
