import 'package:flutter/material.dart';

/// Adaptive breakpoints from the CIRCLE design blueprint §16.
enum CircleBreakpoint { compact, medium, expanded, large }

/// Breakpoint width thresholds (logical pixels).
abstract final class CircleBreakpoints {
  static const compactMax = 600.0;
  static const mediumMax = 840.0;
  static const expandedMax = 1200.0;
}

/// Responsive utilities: breakpoint classification and page padding.
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

/// Full-width page layout with responsive outer padding.
///
/// Use for root list/feed pages. Does NOT cap content width — for forms
/// use [CircleFormLayout] instead.
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

/// Width-capped form layout: 560dp on medium, 640dp on expanded+.
///
/// Use for create/edit forms where a reading column is preferred.
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

/// Adaptive card grid: minimum 280dp per card, 1-3 columns.
class CircleContentGrid extends StatelessWidget {
  const CircleContentGrid({super.key, required this.children, this.gap = 16});
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
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
