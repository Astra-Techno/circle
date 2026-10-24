import 'package:flutter/material.dart';
import 'circle_components.dart';
import 'design.dart';

/// Tablets and large screens (README §4.1) get two panes from this width.
const twoPaneMinWidth = 840.0;

/// Tells lists inside a two-pane layout to show a chosen item in the right
/// pane instead of opening a new page. [kind] keeps scopes apart (a group
/// space in the right pane still opens its events as pages).
class CirclePaneScope extends InheritedWidget {
  const CirclePaneScope({
    super.key,
    required this.kind,
    required this.selected,
    required this.onSelect,
    required super.child,
  });
  final String kind;
  final String? selected;
  final ValueChanged<String> onSelect;

  static CirclePaneScope? of(BuildContext context, String kind) {
    final scope = context.dependOnInheritedWidgetOfExactType<CirclePaneScope>();
    return scope?.kind == kind ? scope : null;
  }

  /// Shows [id] in the right pane when there is one. Returns false on
  /// phones, where the caller opens a page as usual.
  static bool select(BuildContext context, String kind, String id) {
    final scope = of(context, kind);
    if (scope == null) return false;
    scope.onSelect(id);
    return true;
  }

  /// Whether [id] is the item showing in the right pane.
  static bool isSelected(BuildContext context, String kind, String id) =>
      of(context, kind)?.selected == id;

  @override
  bool updateShouldNotify(CirclePaneScope oldWidget) =>
      selected != oldWidget.selected || kind != oldWidget.kind;
}

/// A branch root that is a list on phones and list + detail on tablets.
/// [initial] is the item a deep link asked for: on phones it opens as a
/// page; on tablets it is selected in the right pane.
class CircleAdaptivePane extends StatefulWidget {
  const CircleAdaptivePane({
    super.key,
    required this.kind,
    required this.list,
    required this.detail,
    required this.placeholder,
    this.initial,
  });
  final String kind;
  final String? initial;
  final Widget list;
  final Widget Function(String id) detail;

  /// Shown on the right before anything is chosen.
  final Widget placeholder;

  @override
  State<CircleAdaptivePane> createState() => _CircleAdaptivePaneState();
}

class _CircleAdaptivePaneState extends State<CircleAdaptivePane> {
  late String? _selected = widget.initial;

  @override
  void didUpdateWidget(CircleAdaptivePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initial != oldWidget.initial && widget.initial != null) {
      _selected = widget.initial;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width < twoPaneMinWidth) {
        final id = widget.initial;
        return id == null ? widget.list : widget.detail(id);
      }
      final listWidth = (width * 0.4).clamp(320.0, 420.0);
      final selected = _selected;
      return CirclePaneScope(
        kind: widget.kind,
        selected: selected,
        onSelect: (id) => setState(() => _selected = id),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: listWidth,
              child: KeyedSubtree(
                key: ValueKey('${widget.kind}-list'),
                child: widget.list,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: selected == null
                  ? widget.placeholder
                  : KeyedSubtree(
                      key: ValueKey('${widget.kind}-detail-$selected'),
                      child: widget.detail(selected),
                    ),
            ),
          ],
        ),
      );
    },
  );
}

/// The right pane before anything is chosen.
class CirclePanePlaceholder extends StatelessWidget {
  const CirclePanePlaceholder({
    super.key,
    required this.title,
    required this.message,
  });
  final String title, message;
  @override
  Widget build(BuildContext context) => ReadingPane(
    child: ListView(
      padding: CircleInsets.form,
      children: [CircleEmpty(title: title, message: message)],
    ),
  );
}
