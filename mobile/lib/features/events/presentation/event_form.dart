import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../groups/domain/group_tree.dart';
import '../../groups/domain/membership_rules.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/workspace_view.dart';
import 'event_detail.dart';
import 'event_visuals.dart';

/// E3: create (no [eventId]) or edit an event. Only the group, a title, a
/// date with a start time and a place (or a link for online events) are
/// required; everything else sits under "More options". The group comes
/// from context (`?group=`) when the viewer may create there; otherwise the
/// person chooses it, unless only one group is possible.
class EventFormScreen extends StatelessWidget {
  const EventFormScreen({super.key, this.initialGroupId, this.eventId});
  final String? initialGroupId, eventId;
  @override
  Widget build(BuildContext context) => EventPage(
    child: WorkspaceView(
      builder: (workspace) {
        final id = eventId;
        if (id == null) {
          return _EventForm(
            key: const ValueKey('new-event'),
            workspace: workspace,
            initialGroupId: initialGroupId,
          );
        }
        final event = workspace.event(id);
        if (event == null) return const EventUnavailable();
        return _EventForm(
          key: ValueKey('edit-$id'),
          workspace: workspace,
          event: event,
        );
      },
    ),
  );
}

class _EventForm extends ConsumerStatefulWidget {
  const _EventForm({
    super.key,
    required this.workspace,
    this.event,
    this.initialGroupId,
  });
  final CircleWorkspace workspace;
  final CircleEvent? event;
  final String? initialGroupId;
  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  final _title = TextEditingController();
  final _venue = TextEditingController();
  final _link = TextEditingController();
  final _description = TextEditingController();
  final _capacity = TextEditingController();
  final _more = ExpansibleController();
  String? _groupId;
  EventType _type = EventType.other;

  /// Wall-clock values in the planning zone ([_offset], [_zone]).
  DateTime? _date, _end, _deadline;
  TimeOfDay? _time;
  final Set<String> _coHosts = {};

  /// Null until "Ask with a date poll" is chosen.
  List<DateTime>? _slots;
  bool _pollMultiple = true;
  late Duration _offset;
  late String _zone;
  Map<EventField, String> _errors = {};
  String? _groupError, _capacityError;
  bool _busy = false;

  CircleEvent? get _editing => widget.event;
  DateTime Function() get _clock => ref.read(circleClockProvider);
  DateTime get _today => wallClock(_clock(), _offset);

  @override
  void initState() {
    super.initState();
    final event = _editing;
    if (event == null) {
      // New events use the device's zone at creation (README §4.0).
      final local = _clock().toLocal();
      _offset = local.timeZoneOffset;
      _zone = zoneAbbreviation(local.timeZoneName);
      return;
    }
    _offset = event.utcOffset;
    _zone = event.timeZoneLabel;
    _groupId = event.groupId;
    _type = event.type;
    _title.text = event.title;
    _venue.text = event.venue ?? '';
    _link.text = event.onlineLink ?? '';
    _description.text = event.description ?? '';
    _capacity.text = event.capacity?.toString() ?? '';
    final start = event.localStart;
    _date = DateTime.utc(start.year, start.month, start.day);
    _time = TimeOfDay(hour: start.hour, minute: start.minute);
    _end = event.localEnd;
    _deadline = event.rsvpDeadline == null
        ? null
        : wallClock(event.rsvpDeadline!, _offset);
    _coHosts.addAll(event.hosts.where((host) => host != event.createdBy));
  }

  @override
  void dispose() {
    for (final controller in [_title, _venue, _link, _description, _capacity]) {
      controller.dispose();
    }
    _more.dispose();
    super.dispose();
  }

  DateTime? get _start {
    final date = _date, time = _time;
    if (date == null || time == null) return null;
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  DateTime _dateOnly(DateTime wall) =>
      DateTime(wall.year, wall.month, wall.day);

  Future<DateTime?> _pickDate(DateTime? initial) {
    final today = _dateOnly(_today);
    final wanted = initial == null ? null : _dateOnly(initial);
    // Editing keeps an already-chosen earlier date selectable.
    final first = wanted != null && wanted.isBefore(today) ? wanted : today;
    return showDatePicker(
      context: context,
      initialDate: wanted ?? today,
      firstDate: first,
      lastDate: DateTime(today.year + 3, today.month, today.day),
      currentDate: today,
    );
  }

  /// Date, then time; null if either is dismissed.
  Future<DateTime?> _pickDateTime(DateTime? initial, TimeOfDay time) async {
    final date = await _pickDate(initial);
    if (date == null || !mounted) return null;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial == null
          ? time
          : TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (picked == null) return null;
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
      picked.hour,
      picked.minute,
    );
  }

  String _wallLabel(DateTime wall) =>
      '${formatDay(wall, today: _today)} · ${formatTime(wall)}';

  EventDraft _draft() {
    final capacityText = _capacity.text.trim();
    final capacity = capacityText.isEmpty ? null : int.tryParse(capacityText);
    _capacityError = capacityText.isNotEmpty && capacity == null
        ? 'Use a whole number of people.'
        : null;
    final slots = _slots;
    // With a date poll the date can wait: the earliest option is used
    // until the hosts decide and edit the event.
    final start =
        _start ??
        (slots != null && slots.isNotEmpty
            ? (slots.toList()..sort()).first
            : null);
    DateTime? instant(DateTime? wall) =>
        wall == null ? null : fromWallClock(wall, _offset);
    return EventDraft(
      groupId: _groupId ?? '',
      title: _title.text,
      type: _type,
      startsAt: instant(start),
      endsAt: instant(_end),
      timeZoneLabel: _zone,
      utcOffset: _offset,
      venue: _venue.text,
      onlineLink: _link.text,
      description: _description.text,
      rsvpDeadline: instant(_deadline),
      capacity: capacity,
      coHosts: [..._coHosts],
      datePoll: slots == null || _editing != null
          ? null
          : DatePollDraft(
              slots: [for (final slot in slots) instant(slot)!],
              multipleChoice: _pollMultiple,
            ),
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    final draft = _draft();
    final editing = _editing;
    final issues = EventRules.validate(
      draft,
      now: _clock().toUtc(),
      originalStart: editing?.startsAt,
    );
    setState(() {
      _errors = {
        for (final issue in issues.reversed) issue.field: issue.message,
      };
      _groupError = _groupId == null
          ? 'Choose which group this event is for.'
          : null;
    });
    const main = {EventField.title, EventField.start, EventField.venue};
    final optionalProblem =
        _capacityError != null ||
        _errors.keys.any(
          (field) =>
              !main.contains(field) &&
              !(field == EventField.onlineLink && _type == EventType.online),
        );
    if (optionalProblem) _more.expand();
    if (_errors.isNotEmpty || _groupError != null || _capacityError != null) {
      showCircleMessage(context, 'Please check the highlighted fields.');
      return;
    }
    setState(() => _busy = true);
    final controller = ref.read(circleWorkspaceProvider.notifier);
    if (editing == null) {
      final id = await runCalmly(
        context,
        () => controller.createEvent(draft),
        success: 'Event created.',
      );
      if (!mounted) return;
      if (id != null) {
        context.go('/events/e/$id');
        return;
      }
    } else {
      final saved = await runCalmly(context, () async {
        await controller.editEvent(editing.id, draft);
        return true;
      }, success: 'Changes saved.');
      if (!mounted) return;
      if (saved == true) {
        context.canPop()
            ? context.pop()
            : context.go('/events/e/${editing.id}');
        return;
      }
    }
    setState(() => _busy = false);
  }

  Future<void> _addSlot() async {
    final slots = _slots ?? [];
    final picked = await _pickDateTime(
      slots.isEmpty ? _start : slots.last.add(const Duration(days: 7)),
      _time ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _slots = [...slots, picked]..sort();
      _errors.remove(EventField.datePoll);
    });
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.workspace;
    final viewer = workspace.viewer;
    final editing = _editing;
    final theme = Theme.of(context);
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final allowed = [
      for (final entry in buildGroupTree(workspace.groups))
        if (MembershipRules.canCreateEvent(entry.group, viewer).allowed)
          entry.group,
    ];
    if (editing != null) {
      final group = workspace.group(editing.groupId)!;
      final manage = EventRules.canManage(
        editing,
        viewer,
        isMember: true,
        isAdmin: group.roles[viewer]?.isAdmin ?? false,
        now: _clock().toUtc(),
      );
      if (!manage.allowed) {
        return ReadingPane(
          child: ListView(
            padding: CircleInsets.form,
            children: [
              CircleEmpty(
                title: 'This event can’t be edited',
                message: manage.reason!,
              ),
            ],
          ),
        );
      }
    } else if (allowed.isEmpty) {
      return ReadingPane(
        child: ListView(
          padding: CircleInsets.form,
          children: [
            CircleEmpty(
              title: 'No group to plan in yet',
              message: workspace.groups.isEmpty
                  ? 'Create a group first. Only its members will see its events.'
                  : 'In your groups, only admins can create events. Ask an admin to plan it.',
              action: workspace.groups.isEmpty
                  ? FilledButton(
                      onPressed: () => context.go('/groups/new'),
                      child: const Text('Create a group'),
                    )
                  : null,
            ),
          ],
        ),
      );
    }
    final allowedIds = {for (final group in allowed) group.id};
    if (editing == null && _groupId == null) {
      // Context or the only possible group; never a silent guess.
      if (allowedIds.contains(widget.initialGroupId)) {
        _groupId = widget.initialGroupId;
      } else if (allowed.length == 1) {
        _groupId = allowed.single.id;
      }
    }
    final group = workspace.group(_groupId ?? '');
    final creator = editing?.createdBy ?? viewer;
    final candidates = [
      for (final person in group?.roles.keys ?? const <String>[])
        if (person != creator) person,
    ];
    final online = _type == EventType.online;
    final hasExtras =
        editing != null &&
        (editing.endsAt != null ||
            editing.description != null ||
            editing.rsvpDeadline != null ||
            editing.capacity != null ||
            editing.hosts.length > 1 ||
            (online ? editing.venue : editing.onlineLink) != null);

    return ReadingPane(
      child: SingleChildScrollView(
        padding: CircleInsets.form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleHeading(
              title: editing == null ? 'Plan something together' : 'Edit event',
              subtitle: editing == null
                  ? 'A title, a date and a place are enough. Everything else is optional.'
                  : 'Everyone in the group sees the update, marked as edited.',
            ),
            if (editing != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline),
                title: Text('For ${group?.name ?? 'this group'} only'),
                subtitle: const Text(
                  'An event stays in the group it was made in.',
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _groupId,
                isExpanded: true,
                hint: const Text('Choose a group'),
                decoration: InputDecoration(
                  labelText: 'Group',
                  helperText: 'Only members of this exact group will see it.',
                  helperMaxLines: 3,
                  errorText: _groupError,
                  errorMaxLines: 3,
                ),
                items: [
                  for (final item in allowed)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        audiencePath(item, workspace.groupsById),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) => setState(() {
                  _groupId = id;
                  _groupError = null;
                  final members = workspace.group(id ?? '')?.roles ?? const {};
                  _coHosts.removeWhere(
                    (person) => !members.containsKey(person),
                  );
                }),
              ),
            const SizedBox(height: Space.lg),
            TextField(
              controller: _title,
              maxLength: EventRules.maxTitle,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'Sunday lunch at home',
                errorText: _errors[EventField.title],
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: Space.sm),
            Text('Type', style: theme.textTheme.titleSmall),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final type in EventType.values)
                  ChoiceChip(
                    // Keep the type icon visible instead of a tick.
                    showCheckmark: false,
                    avatar: Icon(
                      eventTypeIcon(type),
                      color: _type == type ? theme.colorScheme.onPrimary : null,
                    ),
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: (_) => setState(() {
                      _type = type;
                      _errors
                        ..remove(EventField.venue)
                        ..remove(EventField.onlineLink);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            Text('When', style: theme.textTheme.titleSmall),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await _pickDate(_date);
                    if (date == null || !mounted) return;
                    setState(() {
                      _date = DateTime.utc(date.year, date.month, date.day);
                      _errors.remove(EventField.start);
                    });
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    _date == null
                        ? 'Choose date'
                        : formatDay(_date!, today: _today),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime:
                          _time ?? const TimeOfDay(hour: 18, minute: 0),
                    );
                    if (time == null || !mounted) return;
                    setState(() {
                      _time = time;
                      _errors.remove(EventField.start);
                    });
                  },
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    _time == null
                        ? 'Start time'
                        : formatTime(
                            DateTime.utc(
                              2000,
                              1,
                              1,
                              _time!.hour,
                              _time!.minute,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            if (_errors[EventField.start] != null)
              Text(
                _errors[EventField.start]!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else
              Text(
                _slots != null && editing == null
                    ? 'Times are in $_zone. With a date poll, the date can wait — the earliest option is used until you decide.'
                    : 'Times are in $_zone.',
                style: caption,
              ),
            const SizedBox(height: Space.lg),
            if (online)
              TextField(
                key: const ValueKey('event-link'),
                controller: _link,
                maxLength: EventRules.maxLink,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Online link',
                  hintText: 'meet.example.invalid/our-call',
                  errorText: _errors[EventField.onlineLink],
                  errorMaxLines: 3,
                ),
              )
            else
              TextField(
                key: const ValueKey('event-venue'),
                controller: _venue,
                maxLength: EventRules.maxVenue,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Place',
                  hintText: 'Grandma’s house',
                  errorText: _errors[EventField.venue],
                  errorMaxLines: 3,
                ),
              ),
            ExpansionTile(
              controller: _more,
              maintainState: true,
              initiallyExpanded: hasExtras,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: Space.md),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              title: const Text('More options'),
              subtitle: Text(
                editing == null
                    ? 'End time, details, RSVP limits, co-hosts, date poll'
                    : 'End time, details, RSVP limits, co-hosts',
                style: caption,
              ),
              children: [
                _OptionalDateTime(
                  label: 'Ends',
                  empty: 'Add an end time',
                  value: _end == null ? null : _wallLabel(_end!),
                  error: _errors[EventField.end],
                  onPick: () async {
                    final start = _start;
                    final picked = await _pickDateTime(
                      _end ?? start?.add(const Duration(hours: 2)),
                      const TimeOfDay(hour: 20, minute: 0),
                    );
                    if (picked == null || !mounted) return;
                    setState(() {
                      _end = picked;
                      _errors.remove(EventField.end);
                    });
                  },
                  onClear: () => setState(() => _end = null),
                ),
                const SizedBox(height: Space.md),
                TextField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 6,
                  maxLength: EventRules.maxDescription,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    errorText: _errors[EventField.description],
                    errorMaxLines: 3,
                  ),
                ),
                const SizedBox(height: Space.sm),
                if (online)
                  TextField(
                    controller: _venue,
                    maxLength: EventRules.maxVenue,
                    decoration: InputDecoration(
                      labelText: 'Place (optional)',
                      errorText: _errors[EventField.venue],
                      errorMaxLines: 3,
                    ),
                  )
                else
                  TextField(
                    controller: _link,
                    maxLength: EventRules.maxLink,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'Online link (optional)',
                      helperText: 'For people joining by video.',
                      errorText: _errors[EventField.onlineLink],
                      errorMaxLines: 3,
                    ),
                  ),
                const SizedBox(height: Space.sm),
                _OptionalDateTime(
                  label: 'RSVP by',
                  empty: 'Add an RSVP deadline',
                  value: _deadline == null ? null : _wallLabel(_deadline!),
                  error: _errors[EventField.deadline],
                  onPick: () async {
                    final start = _start;
                    final picked = await _pickDateTime(
                      _deadline ?? start?.subtract(const Duration(days: 1)),
                      const TimeOfDay(hour: 20, minute: 0),
                    );
                    if (picked == null || !mounted) return;
                    setState(() {
                      _deadline = picked;
                      _errors.remove(EventField.deadline);
                    });
                  },
                  onClear: () => setState(() => _deadline = null),
                ),
                const SizedBox(height: Space.md),
                TextField(
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Capacity (optional)',
                    helperText: 'Counts everyone, including people they bring.',
                    helperMaxLines: 3,
                    errorText: _capacityError ?? _errors[EventField.capacity],
                    errorMaxLines: 3,
                  ),
                ),
                if (candidates.isNotEmpty) ...[
                  const SizedBox(height: Space.md),
                  Text(
                    'Co-hosts (optional)',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    'Co-hosts can edit or cancel the event with you.',
                    style: caption,
                  ),
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final person in candidates)
                        FilterChip(
                          label: Text(workspace.nameOf(person)),
                          selected: _coHosts.contains(person),
                          onSelected: (selected) => setState(
                            () => selected
                                ? _coHosts.add(person)
                                : _coHosts.remove(person),
                          ),
                        ),
                    ],
                  ),
                  if (_errors[EventField.coHosts] != null)
                    Text(
                      _errors[EventField.coHosts]!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
                if (editing == null) ...[
                  const SizedBox(height: Space.lg),
                  if (_slots == null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _slots = []),
                        icon: const Icon(Icons.how_to_vote_outlined),
                        label: const Text(
                          'Not sure of the date? Ask with a date poll',
                        ),
                      ),
                    )
                  else
                    _DatePollEditor(
                      labels: [for (final slot in _slots!) _wallLabel(slot)],
                      multiple: _pollMultiple,
                      error: _errors[EventField.datePoll],
                      onAdd: _slots!.length < EventRules.maxDateSlots
                          ? _addSlot
                          : null,
                      onRemoveAt: (index) =>
                          setState(() => _slots!.removeAt(index)),
                      onMultiple: (value) =>
                          setState(() => _pollMultiple = value),
                      onRemovePoll: () => setState(() {
                        _slots = null;
                        _errors.remove(EventField.datePoll);
                      }),
                    ),
                ] else if (editing.datePoll != null) ...[
                  const SizedBox(height: Space.md),
                  Text(
                    'The date poll stays as it is; its options can’t be changed after creating.',
                    style: caption,
                  ),
                ],
              ],
            ),
            const SizedBox(height: Space.md),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(
                _busy
                    ? 'Saving locally…'
                    : editing == null
                    ? 'Create event'
                    : 'Save changes',
              ),
            ),
            const SizedBox(height: Space.lg),
            const PreviewLabel(
              'Preview: events stay on this device. Nobody is invited, notified or reminded.',
            ),
          ],
        ),
      ),
    );
  }
}

/// An optional date and time: one button picks the date, then the time.
class _OptionalDateTime extends StatelessWidget {
  const _OptionalDateTime({
    required this.label,
    required this.empty,
    required this.value,
    required this.onPick,
    required this.onClear,
    this.error,
  });
  final String label, empty;
  final String? value, error;
  final VoidCallback onPick, onClear;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.event_outlined),
              label: Text(value == null ? empty : '$label: $value'),
            ),
            if (value != null)
              TextButton(
                onPressed: onClear,
                child: Text(
                  'Remove',
                  semanticsLabel: 'Remove ${label.toLowerCase()}',
                ),
              ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// 2–6 date/time options for "Which date works for you?". Results are
/// always visible and votes are named, so people can find a date together.
class _DatePollEditor extends StatelessWidget {
  const _DatePollEditor({
    required this.labels,
    required this.multiple,
    required this.onAdd,
    required this.onRemoveAt,
    required this.onMultiple,
    required this.onRemovePoll,
    this.error,
  });
  final List<String> labels;
  final bool multiple;
  final String? error;
  final VoidCallback? onAdd;
  final ValueChanged<int> onRemoveAt;
  final ValueChanged<bool> onMultiple;
  final VoidCallback onRemovePoll;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: CircleAccents.of(context).hairline),
        borderRadius: BorderRadius.circular(CircleRadius.inner),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Date poll',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onRemovePoll,
                  child: const Text('Remove date poll'),
                ),
              ],
            ),
            Text(
              '“${EventRules.datePollQuestion}” Add ${EventRules.minDateSlots}–${EventRules.maxDateSlots} options. Everyone sees the results.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final (index, label) in labels.indexed)
                  InputChip(
                    label: Text(label),
                    deleteButtonTooltipMessage: 'Remove option $label',
                    onDeleted: () => onRemoveAt(index),
                  ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add a date option'),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('People can pick more than one date'),
              value: multiple,
              onChanged: onMultiple,
            ),
            if (error != null)
              Text(
                error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
