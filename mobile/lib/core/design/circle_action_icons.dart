import 'package:flutter/material.dart';
import 'circle_icons.dart';

/// Coloured icon tiles (owner choice, 10 Nov 2026: style A). A rounded
/// square in the icon's own colour with a crisp white Lucide glyph; the
/// tinted form (pale fill, coloured glyph) marks unselected states, such as
/// the other tabs in the bottom bar. Used for Home quick actions, the bottom
/// bar, root header actions and Memory React/Comment/Save.
enum CircleActionIconType {
  // Home quick actions.
  memory(Color(0xFFEA580C), Color(0xFFC2410C), CircleIcons.photo),
  event(Color(0xFFDB2777), Color(0xFFBE185D), CircleIcons.eventAdd),
  poll(Color(0xFF0D9488), Color(0xFF0F766E), CircleIcons.pollBars),

  /// Drawn as an upright two-tone pill (no font glyph).
  capsule(Color(0xFF7C3AED), Color(0xFF6D28D9), null),

  // Bottom bar.
  home(Color(0xFF16A34A), Color(0xFF15803D), CircleIcons.home),
  circles(Color(0xFF4930A7), Color(0xFF5B45C2), CircleIcons.circles),
  chats(Color(0xFF2563EB), Color(0xFF1D4ED8), CircleIcons.chat),
  events(Color(0xFFDB2777), Color(0xFFBE185D), CircleIcons.events),

  // Header actions.
  search(Color(0xFF1E3A5F), Color(0xFF334E73), CircleIcons.search),
  alerts(Color(0xFFDC2626), Color(0xFFB91C1C), CircleIcons.notifications),
  settings(Color(0xFF475569), Color(0xFF52627A), CircleIcons.settings),

  // Memory actions.
  react(Color(0xFFE11D48), Color(0xFFBE123C), CircleIcons.react),
  comment(Color(0xFF0284C7), Color(0xFF0369A1), CircleIcons.comment),
  save(Color(0xFFD97706), Color(0xFFB45309), CircleIcons.bookmark);

  const CircleActionIconType(this.light, this.dark, this.glyph);

  /// Tile fill in light and dark themes; white glyphs stay at 3:1 or better.
  final Color light, dark;
  final IconData? glyph;

  Color colorFor(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// One coloured icon tile at [size] (34px by default). Callers provide the
/// tap target (48px minimum) and the accessible name.
class CircleActionIcon extends StatelessWidget {
  const CircleActionIcon({
    super.key,
    required this.type,
    this.size = 34,
    this.tinted = false,
    this.glyph,
  });

  final CircleActionIconType type;
  final double size;

  /// Pale fill with a coloured glyph instead of a solid tile.
  final bool tinted;

  /// Replaces the type's glyph, e.g. a filled bookmark once saved.
  final IconData? glyph;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final color = type.colorFor(theme.brightness);
    final fill = tinted
        ? Color.alphaBlend(
            color.withValues(alpha: dark ? 0.28 : 0.14),
            theme.colorScheme.surface,
          )
        : color;
    final ink = tinted
        ? (dark ? Color.lerp(color, Colors.white, 0.4)! : color)
        : Colors.white;
    final symbol = size * 0.6;
    final icon = glyph ?? type.glyph;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: icon == null
            ? CustomPaint(
                size: Size.square(symbol),
                painter: _UprightCapsulePainter(ink),
              )
            : Icon(icon, size: symbol, color: ink),
      ),
    );
  }
}

/// Upright two-tone capsule pill: a solid top half and an outlined bottom
/// half, split by a band.
class _UprightCapsulePainter extends CustomPainter {
  _UprightCapsulePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final width = s * 0.5, height = s;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(s / 2, s / 2),
        width: width,
        height: height,
      ),
      Radius.circular(width / 2),
    );
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, s, s / 2));
    canvas.drawRRect(body, Paint()..color = color);
    canvas.restore();
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.11;
    canvas.drawRRect(body.deflate(s * 0.055), stroke);
    canvas.drawLine(
      Offset(s / 2 - width / 2, s / 2),
      Offset(s / 2 + width / 2, s / 2),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_UprightCapsulePainter old) => old.color != color;
}
