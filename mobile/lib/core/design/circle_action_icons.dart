import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The 8 distinct flat bold action icon types used in the Home header.
enum CircleActionIconType {
  search(Color(0xFF1E3A5F)),
  notify(Color(0xFFDC2626)),
  memory(Color(0xFFEA580C)),
  event(Color(0xFFDB2777)),
  poll(Color(0xFF0D9488)),
  capsule(Color(0xFF7C3AED)),
  home(Color(0xFF16A34A)),
  chat(Color(0xFF2563EB));

  const CircleActionIconType(this.color);

  /// The flat solid fill colour for this icon.
  final Color color;
}

/// Flat bold action icon: solid-colour rx=14 squircle with a crisp white symbol.
///
/// Used exclusively in the Home header action strip (34px) and nav icons (26px).
/// No gradients, shadows, glows or overlays — pure flat design.
class CircleActionIcon extends StatelessWidget {
  const CircleActionIcon({super.key, required this.type, this.size = 34});

  final CircleActionIconType type;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _ActionIconPainter(type: type, size: size),
    ),
  );
}

class _ActionIconPainter extends CustomPainter {
  _ActionIconPainter({required this.type, required this.size});

  final CircleActionIconType type;
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final s = size;
    // Scale factor relative to the 48-unit design viewBox.
    final scale = s / 48;
    final radius = 14 * scale;

    // Squircle background.
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2 * scale, 2 * scale, 44 * scale, 44 * scale),
      Radius.circular(radius),
    );
    canvas.drawRRect(bgRect, Paint()..color = type.color);

    // White symbol paint.
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    switch (type) {
      case CircleActionIconType.search:
        _drawSearch(canvas, scale, stroke);
      case CircleActionIconType.notify:
        _drawNotify(canvas, scale, stroke, fill);
      case CircleActionIconType.memory:
        _drawMemory(canvas, scale, stroke);
      case CircleActionIconType.event:
        _drawEvent(canvas, scale, stroke, fill);
      case CircleActionIconType.poll:
        _drawPoll(canvas, scale, fill);
      case CircleActionIconType.capsule:
        _drawCapsule(canvas, scale, stroke, fill);
      case CircleActionIconType.home:
        _drawHome(canvas, scale, stroke, fill);
      case CircleActionIconType.chat:
        _drawChat(canvas, scale, stroke, fill);
    }
  }

  void _drawSearch(Canvas canvas, double s, Paint stroke) {
    canvas.drawCircle(Offset(21 * s, 21 * s), 7 * s, stroke);
    canvas.drawLine(Offset(26 * s, 26 * s), Offset(31.5 * s, 31.5 * s), stroke);
  }

  void _drawNotify(Canvas canvas, double s, Paint stroke, Paint fill) {
    // Bell body.
    final bell = Path()
      ..moveTo(18 * s, 19 * s)
      ..cubicTo(18 * s, 15.69 * s, 20.69 * s, 13 * s, 24 * s, 13 * s)
      ..cubicTo(27.31 * s, 13 * s, 30 * s, 15.69 * s, 30 * s, 19 * s)
      ..cubicTo(30 * s, 25 * s, 33 * s, 27 * s, 33 * s, 27 * s)
      ..lineTo(15 * s, 27 * s)
      ..cubicTo(15 * s, 27 * s, 18 * s, 25 * s, 18 * s, 19 * s);
    canvas.drawPath(bell, stroke);
    // Clapper.
    final clapper = Path()
      ..moveTo(21.3 * s, 30 * s)
      ..cubicTo(21.3 * s, 31.38 * s, 22.32 * s, 32.5 * s, 24 * s, 32.5 * s)
      ..cubicTo(25.68 * s, 32.5 * s, 26.7 * s, 31.38 * s, 26.7 * s, 30 * s);
    canvas.drawPath(clapper, stroke);
    // Badge.
    canvas.drawCircle(Offset(33 * s, 14 * s), 5 * s, fill);
    canvas.drawCircle(
      Offset(33 * s, 14 * s),
      3 * s,
      Paint()..color = const Color(0xFFFACC15),
    );
  }

  void _drawMemory(Canvas canvas, double s, Paint stroke) {
    // Frame.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(13 * s, 15 * s, 22 * s, 16 * s),
        Radius.circular(3 * s),
      ),
      stroke,
    );
    // Sun.
    canvas.drawCircle(
      Offset(20 * s, 21 * s),
      2.5 * s,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s,
    );
    // Mountain path.
    final mountain = Path()
      ..moveTo(13 * s, 27 * s)
      ..lineTo(18.5 * s, 22.5 * s)
      ..cubicTo(19 * s, 22 * s, 20 * s, 22 * s, 21 * s, 22.5 * s)
      ..lineTo(25.5 * s, 26 * s)
      ..lineTo(28.5 * s, 23.5 * s)
      ..cubicTo(29 * s, 23 * s, 30 * s, 23 * s, 31 * s, 23.5 * s)
      ..lineTo(35 * s, 27 * s);
    canvas.drawPath(
      mountain,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawEvent(Canvas canvas, double s, Paint stroke, Paint fill) {
    // Calendar body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(14 * s, 17 * s, 20 * s, 16 * s),
        Radius.circular(3 * s),
      ),
      stroke,
    );
    // Pins.
    canvas.drawLine(Offset(20 * s, 14 * s), Offset(20 * s, 19 * s), stroke);
    canvas.drawLine(Offset(28 * s, 14 * s), Offset(28 * s, 19 * s), stroke);
    // Divider.
    canvas.drawLine(
      Offset(14 * s, 23 * s),
      Offset(34 * s, 23 * s),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s,
    );
    // Star.
    final star = _starPath(24 * s, 29.9 * s, 3.2 * s, 1.3 * s, 5);
    canvas.drawPath(star, fill);
  }

  void _drawPoll(Canvas canvas, double s, Paint fill) {
    final barFill80 = Paint()..color = Colors.white.withValues(alpha: 0.8);
    final barFill55 = Paint()..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12 * s, 15 * s, 17 * s, 4.5 * s),
        Radius.circular(2.25 * s),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12 * s, 22 * s, 24 * s, 4.5 * s),
        Radius.circular(2.25 * s),
      ),
      barFill80,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12 * s, 29 * s, 11 * s, 4.5 * s),
        Radius.circular(2.25 * s),
      ),
      barFill55,
    );
  }

  void _drawCapsule(Canvas canvas, double s, Paint stroke, Paint fill) {
    // Capsule body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(16 * s, 10 * s, 16 * s, 28 * s),
        Radius.circular(8 * s),
      ),
      stroke,
    );
    // Dashed seal.
    final dashStroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s;
    _drawDashedLine(
      canvas,
      Offset(16 * s, 24 * s),
      Offset(32 * s, 24 * s),
      dashStroke,
      3 * s,
      2 * s,
    );
    // Clock hands.
    canvas.drawLine(Offset(24 * s, 15 * s), Offset(24 * s, 19 * s), stroke);
    canvas.drawLine(Offset(24 * s, 19 * s), Offset(26.5 * s, 20.5 * s), stroke);
    // Lock keyhole.
    canvas.drawCircle(Offset(24 * s, 30.5 * s), 2.5 * s, fill);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(22.75 * s, 32.5 * s, 2.5 * s, 2.5 * s),
        Radius.circular(1.25 * s),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  void _drawHome(Canvas canvas, double s, Paint stroke, Paint fill) {
    // Roof.
    final roof = Path()
      ..moveTo(14 * s, 23 * s)
      ..lineTo(24 * s, 14 * s)
      ..lineTo(34 * s, 23 * s);
    canvas.drawPath(roof, stroke);
    // Walls.
    final walls = Path()
      ..moveTo(16 * s, 21.5 * s)
      ..lineTo(16 * s, 33 * s)
      ..cubicTo(16 * s, 33.55 * s, 16.45 * s, 34 * s, 17 * s, 34 * s)
      ..lineTo(31 * s, 34 * s)
      ..cubicTo(31.55 * s, 34 * s, 32 * s, 33.55 * s, 32 * s, 33 * s)
      ..lineTo(32 * s, 21.5 * s);
    canvas.drawPath(walls, stroke);
    // Heart.
    final heart = Path()
      ..moveTo(24 * s, 26 * s)
      ..cubicTo(22.5 * s, 26 * s, 21.5 * s, 27 * s, 21.5 * s, 28.2 * s)
      ..cubicTo(21.5 * s, 30.2 * s, 24 * s, 31.5 * s, 24 * s, 31.5 * s)
      ..cubicTo(24 * s, 31.5 * s, 26.5 * s, 30.2 * s, 26.5 * s, 28.2 * s)
      ..cubicTo(26.5 * s, 27 * s, 25.5 * s, 26 * s, 24 * s, 26 * s);
    canvas.drawPath(heart, fill);
  }

  void _drawChat(Canvas canvas, double s, Paint stroke, Paint fill) {
    // Bubble.
    final bubble = Path()
      ..moveTo(33 * s, 21 * s)
      ..cubicTo(33 * s, 25.5 * s, 29 * s, 29 * s, 24 * s, 29 * s)
      ..lineTo(22 * s, 29 * s)
      ..lineTo(18 * s, 33 * s)
      ..lineTo(18 * s, 29 * s)
      ..cubicTo(16 * s, 27.8 * s, 15 * s, 25.5 * s, 15 * s, 23.5 * s)
      ..cubicTo(15 * s, 19 * s, 19 * s, 15 * s, 24 * s, 15 * s)
      ..cubicTo(29 * s, 15 * s, 33 * s, 18 * s, 33 * s, 21 * s);
    canvas.drawPath(bubble, stroke);
    // Dots.
    canvas.drawCircle(Offset(20 * s, 21.5 * s), 1.25 * s, fill);
    canvas.drawCircle(Offset(24 * s, 21.5 * s), 1.25 * s, fill);
    canvas.drawCircle(Offset(28 * s, 21.5 * s), 1.25 * s, fill);
  }

  Path _starPath(
    double cx,
    double cy,
    double outerR,
    double innerR,
    int points,
  ) {
    final path = Path();
    final step = math.pi / points;
    for (var i = 0; i < 2 * points; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = -math.pi / 2 + i * step;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashWidth,
    double dashGap,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    final ux = dx / length;
    final uy = dy / length;
    var pos = 0.0;
    while (pos < length) {
      final segEnd = math.min(pos + dashWidth, length);
      canvas.drawLine(
        Offset(start.dx + ux * pos, start.dy + uy * pos),
        Offset(start.dx + ux * segEnd, start.dy + uy * segEnd),
        paint,
      );
      pos += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(_ActionIconPainter old) =>
      old.type != type || old.size != size;
}
