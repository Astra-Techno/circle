import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../design.dart';

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

  /// Spring-like bounce for premium interactions (Apple HIG fluid motion).
  static const springCurve = _SpringCurve(300, 22);

  /// Subtle press scale for tappable cards (0.97).
  static const pressScale = 0.97;
}

/// Attempt at an underdamped spring; falls back to easeOutCubic if the
/// physics produce a NaN.
class _SpringCurve extends Curve {
  const _SpringCurve(this.stiffness, this.damping);
  final double stiffness, damping;

  @override
  double transformInternal(double t) {
    final w = math.sqrt(stiffness);
    final z = damping / (2 * w);
    if (z < 1) {
      final wd = w * math.sqrt(1 - z * z);
      return 1 -
          math.exp(-z * w * t) * (math.cos(wd * t) + z * math.sin(wd * t));
    }
    return 1 - (1 + (w * t)) * math.exp(-w * t);
  }
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
  void initState() {
    super.initState();
    // Initialize while the element is active, including reduced-motion builds.
    _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? widget.child
      : Listener(
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

  Timer? _delayTimer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _delayTimer?.cancel();
      _ctrl.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      if (widget.delay == Duration.zero) {
        _ctrl.forward();
      } else {
        _delayTimer = Timer(widget.delay, () {
          if (mounted) _ctrl.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? widget.child
      : FadeTransition(
          opacity: _opacity,
          child: SlideTransition(position: _slide, child: widget.child),
        );
}

/// Premium frosted-glass surface with real backdrop blur.
/// Clips the child to [borderRadius] and applies a [sigmaX]/[sigmaY] blur
/// behind the translucent [tint]. Use sparingly — each instance adds a
/// compositing layer.
class CircleGlass extends StatelessWidget {
  const CircleGlass({
    super.key,
    required this.child,
    this.sigma = 16,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(CircleRadius.card),
    ),
    this.tint,
    this.border,
  });
  final Widget child;
  final double sigma;
  final BorderRadius borderRadius;
  final Color? tint;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final fill =
        tint ??
        (brightness == Brightness.light
            ? Colors.white.withValues(alpha: 0.72)
            : const Color(0xFF242526).withValues(alpha: 0.72));
    final edge =
        border ??
        Border.all(
          color: brightness == Brightness.light
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.06),
        );
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: borderRadius,
            border: edge,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Subtle pulsing glow ring for premium locked surfaces (capsules, badges).
/// Respects reduced-motion by rendering a static ring.
class CircleShimmerGlow extends StatefulWidget {
  const CircleShimmerGlow({
    super.key,
    required this.color,
    required this.child,
    this.glowRadius = 24,
    this.animate = true,
  });
  final Color color;
  final Widget child;
  final double glowRadius;
  final bool animate;

  @override
  State<CircleShimmerGlow> createState() => _CircleShimmerGlowState();
}

class _CircleShimmerGlowState extends State<CircleShimmerGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animate && !MediaQuery.disableAnimationsOf(context)) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl.value = 0.5;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (context, child) {
      final alpha = 0.08 + _ctrl.value * 0.14;
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: alpha),
              blurRadius: widget.glowRadius,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      );
    },
    child: widget.child,
  );
}

/// Animated circular progress ring for countdown visuals.
/// Draws an arc from 0 to [progress] (0.0–1.0) with a rounded stroke cap.
class CircleProgressRing extends StatelessWidget {
  const CircleProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.trackColor,
    this.size = 80,
    this.strokeWidth = 6,
    required this.child,
  });
  final double progress;
  final Color color;
  final Color? trackColor;
  final double size;
  final double strokeWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: _RingPainter(
            progress: progress.clamp(0, 1),
            color: color,
            trackColor:
                trackColor ??
                Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: strokeWidth,
          ),
        ),
        child,
      ],
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });
  final double progress;
  final Color color, trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
