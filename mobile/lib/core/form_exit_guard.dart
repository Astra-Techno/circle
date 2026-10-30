import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// In-memory, route-scoped protection only; never persists private form values.
class FormExitController {
  VoidCallback? _commit;
  void commit() => _commit?.call();
}

final _forms = <String, _UnsavedFormState>{};

Future<bool> confirmCircleFormExit(BuildContext context, String path) async =>
    await _forms[path]?.confirm() ?? true;

class UnsavedForm extends StatefulWidget {
  const UnsavedForm({
    super.key,
    required this.controller,
    required this.fields,
    required this.fingerprint,
    required this.child,
  });
  final FormExitController controller;
  final List<TextEditingController> fields;
  final String Function() fingerprint;
  final Widget child;
  @override
  State<UnsavedForm> createState() => _UnsavedFormState();
}

class _UnsavedFormState extends State<UnsavedForm> {
  late String _baseline;
  String? _path;
  Future<bool>? _confirmation;
  bool get dirty => _baseline != widget.fingerprint();
  @override
  void initState() {
    super.initState();
    _baseline = widget.fingerprint();
    widget.controller._commit = commit;
    for (final field in widget.fields) {
      field.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void commit() {
    if (mounted) setState(() => _baseline = widget.fingerprint());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _path ??= GoRouterState.of(context).uri.path;
    _forms[_path!] = this;
  }

  @override
  void didUpdateWidget(UnsavedForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final field in oldWidget.fields) {
      if (!widget.fields.contains(field)) {
        field.removeListener(_changed);
      }
    }
    for (final field in widget.fields) {
      if (!oldWidget.fields.contains(field)) {
        field.addListener(_changed);
      }
    }
  }

  Future<bool> confirm() async {
    if (!dirty) return true;
    return _confirmation ??= _ask();
  }

  Future<bool> _ask() async {
    final discard =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard your changes?'),
            content: const Text('Your changes have not been saved.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard changes'),
              ),
            ],
          ),
        ) ??
        false;
    _confirmation = null;
    if (discard && mounted) commit();
    return discard;
  }

  @override
  void dispose() {
    for (final field in widget.fields) {
      field.removeListener(_changed);
    }
    if (identical(_forms[_path], this)) _forms.remove(_path);
    widget.controller._commit = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
