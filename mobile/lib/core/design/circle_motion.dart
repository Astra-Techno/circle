import 'package:flutter/material.dart';

/// Shared animation tokens. Durations follow Material motion guidance:
/// micro 150ms, standard 250ms, emphasis 350ms, exit 60–70% of enter.
abstract final class CircleMotion {
  static const micro = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 250);
  static const emphasis = Duration(milliseconds: 350);
  static const staggerDelay = Duration(milliseconds: 50);

  static const enterCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;
  static const emphasizedCurve = Curves.easeInOutCubic;

  /// Subtle press scale for tappable cards (0.97).
  static const pressScale = 0.97;
}

/// Wrap any tappable widget to get a subtle press-scale effect.
/// Uses [Listener] so the inner InkWell/GestureDetector still receives taps.
class CirclePressable extends StatefulWidget {
  const CirclePressable({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  State<CirclePressable> createState() => _CirclePressableState();
}

class _CirclePressableState extends State<CirclePressable>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: CircleMotion.micro,
    reverseDuration: const Duration(milliseconds: 100),
    lowerBound: CircleMotion.pressScale,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _ctrl.reverse(),
        onPointerUp: (_) {
          _ctrl.forward();
          widget.onTap?.call();
        },
        onPointerCancel: (_) => _ctrl.forward(),
        child: ScaleTransition(scale: _ctrl, child: widget.child),
      );
}

/// Animates a child in with fade + slide-up when first built.
/// Use inside lists for a staggered entrance effect.
class CircleFadeIn extends StatefulWidget {
  const CircleFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });
  final Widget child;
  final Duration delay;
  @override
  State<CircleFadeIn> createState() => _CircleFadeInState();
}

class _CircleFadeInState extends State<CircleFadeIn>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: CircleMotion.standard,
  );
  late final _opacity = CurvedAnimation(
    parent: _ctrl,
    curve: CircleMotion.enterCurve,
  );
  late final _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(_opacity);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}
