import 'package:flutter/material.dart';

/// Builds network-backed content only near the visible screen. Intersects all
/// ancestor scroll viewports, including nested shrink-wrapped grids. Holds no
/// image bytes or authorization state; the child still performs access checks.
class CircleViewportLoad extends StatefulWidget {
  const CircleViewportLoad({
    super.key,
    required this.builder,
    required this.placeholder,
  });
  final WidgetBuilder builder;
  final Widget placeholder;
  @override
  State<CircleViewportLoad> createState() => _CircleViewportLoadState();
}

class _CircleViewportLoadState extends State<CircleViewportLoad> {
  final _positions = <ScrollPosition>[];
  bool _active = false, _scheduled = false, _enabled = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled = TickerMode.valuesOf(context).enabled;
    MediaQuery.sizeOf(context);
    Scrollable.maybeOf(context);
    if (_active) return;
    _detach();
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        if (!_positions.contains(position)) {
          _positions.add(position);
          position.addListener(_schedule);
        }
      }
      return true;
    });
    _schedule();
  }

  void _detach() {
    for (final position in _positions) {
      position.removeListener(_schedule);
    }
    _positions.clear();
  }

  void _schedule() {
    if (_scheduled || _active || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _active || !_enabled) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final mediaSize = MediaQuery.sizeOf(context);
      final view = View.of(context);
      final screenSize = mediaSize.isEmpty
          ? view.physicalSize / view.devicePixelRatio
          : mediaSize;
      var visible = (Offset.zero & screenSize).inflate(192);
      context.visitAncestorElements((element) {
        if (element is StatefulElement && element.state is ScrollableState) {
          final viewport = element.findRenderObject();
          if (viewport is RenderBox && viewport.hasSize) {
            visible = visible.intersect(
              (viewport.localToGlobal(Offset.zero) & viewport.size).inflate(
                192,
              ),
            );
          }
        }
        return true;
      });
      final bounds = box.localToGlobal(Offset.zero) & box.size;
      if (!visible.isEmpty && bounds.overlaps(visible)) {
        _detach();
        setState(() => _active = true);
      }
    });
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _active ? widget.builder(context) : widget.placeholder;
}
