import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/application/workspace_providers.dart';

/// The viewer's RSVP: Going / Maybe / Not going, people coming with them
/// (Going and Maybe only) and an optional note. Every change saves at once
/// with a calm "Saved" and Undo; there is no Save button.
class RsvpControl extends ConsumerStatefulWidget {
  const RsvpControl({
    super.key,
    required this.event,
    required this.viewer,
    required this.enabled,
  });
  final CircleEvent event;
  final String viewer;

  /// False once RSVPs are closed (cancelled, started, past the deadline).
  final bool enabled;
  @override
  ConsumerState<RsvpControl> createState() => _RsvpControlState();
}

class _RsvpControlState extends ConsumerState<RsvpControl> {
  late final _note = TextEditingController(text: _mine?.note ?? '');
  final _noteFocus = FocusNode();
  bool _writingNote = false;

  Rsvp? get _mine => widget.event.rsvpOf(widget.viewer);

  @override
  void initState() {
    super.initState();
    _noteFocus.addListener(() {
      if (!_noteFocus.hasFocus) _saveNote();
    });
  }

  @override
  void didUpdateWidget(RsvpControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow saved changes (including Undo) unless the person is typing.
    if (!_noteFocus.hasFocus) _note.text = _mine?.note ?? '';
  }

  @override
  void dispose() {
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  Future<void> _save(Rsvp? next) async {
    final previous = _mine;
    if (next == previous) return;
    final controller = ref.read(circleWorkspaceProvider.notifier);
    final id = widget.event.id;
    await runCalmly(
      context,
      () => controller.rsvp(id, next),
      success: next == null ? 'Your answer was cleared.' : 'Saved.',
      onUndo: undoWith(context, () => controller.rsvp(id, previous)),
    );
  }

  void _saveNote() {
    final mine = _mine;
    if (mine == null || !widget.enabled) return;
    final text = _note.text.trim();
    if (text == (mine.note ?? '')) return;
    _save(mine.copyWith(note: text));
  }

  void _choose(Attendance status) {
    final mine = _mine;
    if (mine?.status == status) return;
    _save(
      Rsvp(
        status,
        guests: status.allowsGuests ? mine?.guests ?? 0 : 0,
        note: mine?.note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = _mine;
    final enabled = widget.enabled;
    final title = widget.event.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Your answer for $title',
          container: true,
          child: Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final status in Attendance.values)
                ChoiceChip(
                  label: Text(status.label),
                  selected: mine?.status == status,
                  onSelected: enabled ? (_) => _choose(status) : null,
                ),
            ],
          ),
        ),
        if (mine != null && mine.status.allowsGuests) ...[
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  'People coming with you',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              IconButton(
                tooltip: 'One person fewer',
                icon: const Icon(Icons.remove),
                onPressed: enabled && mine.guests > 0
                    ? () => _save(mine.copyWith(guests: mine.guests - 1))
                    : null,
              ),
              Semantics(
                liveRegion: true,
                label:
                    '${mine.guests} ${mine.guests == 1 ? 'person' : 'people'} coming with you',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                  child: Text(
                    '${mine.guests}',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'One person more',
                icon: const Icon(Icons.add),
                onPressed: enabled && mine.guests < EventRules.maxGuests
                    ? () => _save(mine.copyWith(guests: mine.guests + 1))
                    : null,
              ),
            ],
          ),
        ],
        if (mine != null) ...[
          const SizedBox(height: Space.sm),
          if (_writingNote || (mine.note ?? '').isNotEmpty)
            TextField(
              controller: _note,
              focusNode: _noteFocus,
              enabled: enabled,
              maxLength: EventRules.maxNote,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _noteFocus.unfocus(),
              onTapOutside: (_) => _noteFocus.unfocus(),
              decoration: const InputDecoration(
                labelText: 'Note for the hosts (optional)',
                hintText: 'Will arrive after lunch',
                helperText: 'Saved when you finish typing.',
              ),
            )
          else if (enabled)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _writingNote = true);
                  _noteFocus.requestFocus();
                },
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('Add a note'),
              ),
            ),
          if (enabled)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => _save(null),
                child: const Text('Clear my answer'),
              ),
            ),
        ],
      ],
    );
  }
}
