import '../../../core/api/api_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/application/workspace_providers.dart';

/// I3: the shared report flow. A bottom sheet with a reason picker and an
/// optional note; [submit] sends it. On success the sheet closes and
/// [confirmation] is shown. Returns whether a report was sent.
Future<bool> showReportSheet(
  BuildContext context, {
  required String title,
  required String confirmation,
  required Future<void> Function(ReportReason reason, String? note) submit,
  String explanation =
      'Admins of this group see the reason, never who reported it.',
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final sent = await showModalBottomSheet<bool>(
    context: context,
    // Above the shell's navigation bar, so nothing is hidden.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _ReportSheet(title: title, explanation: explanation, submit: submit),
  );
  if (sent == true) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(confirmation)));
  }
  return sent == true;
}

/// Reports something the workspace repository can check itself (a Memory,
/// comment, event, member or subgroup) to the admins of its group.
Future<bool> reportToAdmins(
  BuildContext context,
  WidgetRef ref, {
  required ReportTarget target,
  required String what,
}) {
  final controller = ref.read(circleWorkspaceProvider.notifier);
  final api = ref.read(apiClientProvider);
  final session = api?.sessionRevision;
  final viewer = ref.read(circleViewerProvider);
  return showReportSheet(
    context,
    title: 'Report $what',
    explanation:
        "Only this group’s admins review reports. Your account and optional note aren’t shown in their queue.",
    confirmation: 'Thanks — admins of this group will review it.',
    submit: (reason, note) {
      if (!context.mounted ||
          !identical(ref.read(apiClientProvider), api) ||
          api?.sessionRevision != session ||
          ref.read(circleViewerProvider) != viewer) {
        throw const CircleFailure(
          'Your session changed. Open the report again.',
        );
      }
      return controller.report(
        ReportDraft(target: target, reason: reason, note: note),
      );
    },
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.title,
    required this.explanation,
    required this.submit,
  });
  final String title, explanation;
  final Future<void> Function(ReportReason reason, String? note) submit;
  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final _note = TextEditingController();
  ReportReason? _reason;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null) return;
    final check = ModerationRules.checkNote(_note.text);
    if (!check.allowed) {
      setState(() => _error = check.reason);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.submit(reason, ModerationRules.cleanNote(_note.text));
      if (mounted) Navigator.of(context).pop(true);
    } on CircleFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'That didn’t work. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Space.section,
          0,
          Space.section,
          Space.section,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(widget.title, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: Space.xs),
            Text(widget.explanation, style: theme.textTheme.bodySmall),
            const SizedBox(height: Space.sm),
            Text('What’s wrong?', style: theme.textTheme.titleMedium),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (value) => setState(() {
                _reason = value;
                _error = null;
              }),
              child: Column(
                children: [
                  for (final reason in ReportReason.values)
                    RadioListTile<ReportReason>(
                      contentPadding: EdgeInsets.zero,
                      value: reason,
                      title: Text(reason.label),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 5,
              maxLength: ModerationRules.maxNote,
              decoration: const InputDecoration(
                labelText: 'Add a note (optional)',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            FilledButton(
              onPressed: _reason == null || _busy ? null : _send,
              child: Text(_busy ? 'Sending…' : 'Send report'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown to a group's admins on content they hid ("Hidden by admins"),
/// with Unhide. Everyone else doesn't see the content at all.
class HiddenByAdminsNotice extends ConsumerWidget {
  const HiddenByAdminsNotice({
    super.key,
    required this.groupId,
    required this.target,
    required this.what,
  });
  final String groupId, what;
  final ReportTarget target;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.only(start: Space.md),
      decoration: BoxDecoration(
        color: CircleAccents.of(context).recessed,
        borderRadius: BorderRadius.circular(CircleRadius.tile),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              'Hidden by admins. Only admins see this $what.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () => runCalmly(
              context,
              () => ref
                  .read(circleWorkspaceProvider.notifier)
                  .unhide(groupId, target.key),
              success: 'Shown to everyone again.',
            ),
            child: Text('Unhide', semanticsLabel: 'Unhide this $what'),
          ),
        ],
      ),
    );
  }
}
