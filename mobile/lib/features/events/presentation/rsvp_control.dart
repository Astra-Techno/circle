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
    this.showChoices = true,
  });
  final CircleEvent event;
  final String viewer;

  /// False once RSVPs are closed (cancelled, started, past the deadline).
  final bool enabled;

  /// False when [RsvpBar] already offers Going / Maybe / Not going in the
  /// thumb zone; this control then keeps only guests, note and clear.
  final bool showChoices;
  @override
  ConsumerState<RsvpControl> createState() => _RsvpControlState();
}

/// Saves [next] as the viewer's answer with a calm "Saved" and Undo.
Future<void> saveRsvp(
  BuildContext context,
  WidgetRef ref,
  CircleEvent event,
  Rsvp? next,
) async {
  final previous = event.rsvpOf(ref.read(circleViewerProvider));
  if (next == previous) return;
  final controller = ref.read(circleWorkspaceProvider.notifier);
  await runCalmly(
    context,
    () => controller.rsvp(event.id, next),
    success: next == null ? 'Your answer was cleared.' : 'Saved.',
    onUndo: undoWith(context, () => controller.rsvp(event.id, previous)),
  );
}

/// The answer as a new [Rsvp], keeping guests (when allowed) and the note.
Rsvp rsvpChoice(Rsvp? mine, Attendance status) => Rsvp(
  status,
  guests: status.allowsGuests ? mine?.guests ?? 0 : 0,
  note: mine?.note,
);

/// Going / Maybe / Not going pinned to the bottom of an open event, in the
/// thumb zone. The chosen answer is the one filled button.
class RsvpBar extends ConsumerWidget {
  const RsvpBar({super.key, required this.event, required this.viewer});
  final CircleEvent event;
  final String viewer;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mine = event.rsvpOf(viewer);
    final now = ref.watch(circleClockProvider)().toUtc();
    // Choices the rules refuse (a full event) are disabled with the reason
    // shown here, so no message ever covers the buttons.
    RuleResult check(Attendance option) => EventRules.canRsvp(
      event,
      viewer,
      rsvpChoice(mine, option),
      isMember: true,
      now: now,
    );
    final blocked = [
      for (final option in Attendance.values)
        if (mine?.status != option && !check(option).allowed) option,
    ];
    final status = switch (mine?.status) {
      null => 'Are you coming?',
      Attendance.going => 'You’re going',
      Attendance.maybe => 'You might go',
      Attendance.notGoing => 'You’re not going',
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: CircleAccents.of(context).hairline),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.section,
          Space.sm,
          Space.section,
          Space.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                blocked.isEmpty ? status : check(blocked.first).reason!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: CircleAccents.of(context).caption,
                ),
              ),
            ),
            const SizedBox(height: Space.sm),
            Semantics(
              label: 'Your answer for ${event.title}',
              container: true,
              child: Row(
                children: [
                  for (final (index, option) in Attendance.values.indexed) ...[
                    if (index > 0) const SizedBox(width: Space.sm),
                    Expanded(
                      child: Semantics(
                        selected: mine?.status == option,
                        child: mine?.status == option
                            ? FilledButton(
                                onPressed: () {},
                                child: _BarLabel(option.label),
                              )
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Space.sm,
                                    vertical: Space.md,
                                  ),
                                ),
                                onPressed: blocked.contains(option)
                                    ? null
                                    : () => saveRsvp(
                                        context,
                                        ref,
                                        event,
                                        rsvpChoice(mine, option),
                                      ),
                                child: _BarLabel(option.label),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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

  Future<void> _save(Rsvp? next) => saveRsvp(context, ref, widget.event, next);

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
    _save(rsvpChoice(mine, status));
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
        if (widget.showChoices)
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
          if (widget.showChoices) const SizedBox(height: Space.md),
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

/// A one-line answer label that shrinks instead of breaking a word at very
/// large text sizes (the bar keeps three equal choices side by side).
class _BarLabel extends StatelessWidget {
  const _BarLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(label, maxLines: 1, softWrap: false),
  );
}
