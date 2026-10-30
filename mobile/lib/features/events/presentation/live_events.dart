import '../../profile/application/profile_providers.dart'
    show profilePhotoPickerProvider;
import '../../../core/private_photo.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import 'event_visuals.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../notifications/application/push_settings.dart'
    show deviceTimezoneProvider;
import '../application/live_events.dart';

void refreshLiveEvents(WidgetRef ref) {
  ref.invalidate(liveEventsProvider);
  ref.invalidate(liveEventProvider);
  ref.invalidate(liveAttendeesProvider);
}

class LiveEventsScreen extends ConsumerStatefulWidget {
  const LiveEventsScreen({super.key, this.id, this.group});
  final String? id, group;
  @override
  ConsumerState<LiveEventsScreen> createState() => _LiveEventsState();
}

class _LiveEventsState extends ConsumerState<LiveEventsScreen> {
  int _offset = 0;
  bool _busy = false;

  /// Events from earlier pages; the list grows as it scrolls.
  final _earlier = <Map<String, Object?>>[];

  Widget _eventList(List<Map<String, Object?>> items, {Widget? end}) =>
      RefreshIndicator(
        // The header's + plans an event; pull down to refresh.
        onRefresh: () async {
          setState(() {
            _offset = 0;
            _earlier.clear();
          });
          refreshLiveEvents(ref);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Collapsing pinned header: large title shrinks to compact bar.
            const CircleCollapsingHeader(),
            SliverPadding(
              padding: CircleInsets.page,
              sliver: SliverList.list(
                children: [
                  if (items.isEmpty)
                    const CircleEmpty(
                      title: 'Something to look forward to',
                      message: 'Plan the first event for one of your circles.',
                    ),
                  for (final item in items)
                    _LiveEventCard(
                      item: item,
                      onTap: () => context.go('/events/e/${item['id']}'),
                    ),
                  ?end,
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final load = id == null
        ? ref.watch(liveEventsProvider((offset: _offset, group: widget.group)))
        : ref.watch(liveEventProvider(id));
    return ReadingPane(
      child: load.when(
        loading: () => id == null && _earlier.isNotEmpty
            ? _eventList(
                _earlier,
                end: const Padding(
                  padding: EdgeInsets.all(Space.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            : const CircleSkeletonPage(
                shape: CircleSkeletonShape.cards,
                count: 3,
                label: 'Loading events',
              ),
        error: (_, _) => CircleEmpty(
          title: 'Events couldn’t load',
          message: 'Check your connection and group access.',
          action: TextButton(
            onPressed: () => refreshLiveEvents(ref),
            child: const Text('Try again'),
          ),
        ),
        data: (e) {
          if (id == null) {
            final items = ApiJson.list(e['items']).map(ApiJson.map).toList();
            return _eventList(
              [..._earlier, ...items],
              end: e['has_more'] == true
                  ? CircleLoadMore(
                      key: ValueKey('more-$_offset'),
                      onLoad: () => setState(() {
                        _earlier.addAll(items);
                        _offset += 30;
                      }),
                    )
                  : null,
            );
          }
          final mine = e['my_rsvp'],
              active = e['status'] == 'active',
              manage = e['can_manage'] == true;
          final canRsvp =
              active &&
              DateTime.parse(
                e['start_at'] as String,
              ).isAfter(DateTime.now().toUtc());
          final chosen = mine is Map ? mine['status'] : null;
          Widget choiceButton(MapEntry<String, String> choice) {
            // One line that shrinks rather than wrapping a word.
            final label = FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(choice.value, maxLines: 1, softWrap: false),
            );
            return chosen == choice.key
                ? FilledButton(onPressed: () {}, child: label)
                : OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final api = ref.read(liveEventsApiProvider);
                            setState(() => _busy = true);
                            await runCalmly(
                              context,
                              () => api.rsvp(
                                id,
                                choice.key,
                                choice.key == 'going' && mine is Map
                                    ? (mine['guest_count'] as int? ?? 0)
                                    : 0,
                                mine is Map
                                    ? (mine['note'] as String? ?? '')
                                    : '',
                              ),
                              success: 'RSVP saved.',
                            );
                            if (mounted) {
                              setState(() => _busy = false);
                              refreshLiveEvents(ref);
                            }
                          },
                    child: label,
                  );
          }

          final theme = Theme.of(context);
          final caption = theme.textTheme.bodySmall?.copyWith(
            color: CircleAccents.of(context).caption,
          );
          final zone = e['timezone'] as String;
          final venue = e['venue'] as String? ?? '';
          final link = e['online_link'] as String? ?? '';
          Future<void> busy(Future<void> Function() work) async {
            setState(() => _busy = true);
            await work();
            if (!mounted) return;
            setState(() => _busy = false);
            refreshLiveEvents(ref);
          }

          Future<void> manageAction(String action) async {
            final api = ref.read(liveEventsApiProvider);
            final version = e['version'] as int;
            switch (action) {
              case 'cover':
                final picker = ref.read(profilePhotoPickerProvider);
                await busy(
                  () =>
                      runCalmly(context, () => api.cover(id, version, picker)),
                );
              case 'remove-cover':
                await busy(
                  () => runCalmly(context, () => api.removeCover(id, version)),
                );
              case 'edit':
                context.go('/events/e/$id/edit');
              case 'cancel':
                if (!await confirmCircleAction(
                  context,
                  title: 'Cancel this event?',
                  message:
                      'The group will see the cancellation. Existing RSVPs stay on record.',
                  confirm: 'Cancel event',
                )) {
                  return;
                }
                if (!context.mounted) return;
                await busy(
                  () => runCalmly(
                    context,
                    () => api.update(id, {
                      'version': version,
                      'status': 'cancelled',
                    }),
                    success: 'Event cancelled.',
                  ),
                );
            }
          }

          Widget row(
            IconData icon,
            String title, {
            String? subtitle,
            VoidCallback? onTap,
          }) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon),
            title: Text(title),
            subtitle: subtitle == null ? null : Text(subtitle),
            trailing: onTap == null ? null : const Icon(Icons.chevron_right),
            onTap: onTap,
          );
          final going = (e['going_count'] as num?)?.toInt() ?? 0;
          final details = RefreshIndicator(
            onRefresh: () async => refreshLiveEvents(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: CircleInsets.form,
              children: [
                if (e['cover_id'] case final String cover)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.lg),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(CircleRadius.card),
                      child: PrivatePhoto(
                        load: ref.watch(
                          liveEventCoverProvider((event: id, cover: cover)),
                        ),
                        label: 'Event cover',
                      ),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EventDateBlock(
                      wall: liveEventWall(e['start_at'] as String, zone),
                    ),
                    const SizedBox(width: Space.lg),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          e['title'] as String,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ),
                    if (manage && active)
                      PopupMenuButton<String>(
                        tooltip: 'Event options',
                        enabled: !_busy,
                        onSelected: manageAction,
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'cover',
                            child: Text(
                              e['cover_id'] == null
                                  ? 'Add cover photo'
                                  : 'Change cover photo',
                            ),
                          ),
                          if (e['cover_id'] != null)
                            const PopupMenuItem(
                              value: 'remove-cover',
                              child: Text('Remove cover'),
                            ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit event'),
                          ),
                          const PopupMenuItem(
                            value: 'cancel',
                            child: Text('Cancel event'),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                if (!active)
                  const EventNotice(
                    icon: Icons.event_busy_outlined,
                    text: 'This event is cancelled.',
                  ),
                row(
                  Icons.schedule_rounded,
                  liveEventLabel(e),
                  subtitle: e['end_at'] == null
                      ? null
                      : 'Ends ${formatDay(liveEventWall(e['end_at'] as String, zone), today: DateTime.now())} · ${formatTime(liveEventWall(e['end_at'] as String, zone))}',
                ),
                if (venue.isNotEmpty) row(Icons.place_outlined, venue),
                if (link.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link),
                    title: SelectableText(link),
                  ),
                if (e['rsvp_deadline'] != null)
                  row(
                    Icons.event_available_outlined,
                    'RSVP by ${formatDay(liveEventWall(e['rsvp_deadline'] as String, zone), today: DateTime.now())} · ${formatTime(liveEventWall(e['rsvp_deadline'] as String, zone))}',
                  ),
                row(
                  Icons.groups_outlined,
                  'Who’s coming?',
                  subtitle:
                      '$going going${e['max_capacity'] == null ? '' : ' · room for ${e['max_capacity']}'}',
                  onTap: () => context.go('/events/e/$id/attendees'),
                ),
                row(
                  Icons.poll_outlined,
                  'Event polls',
                  onTap: () =>
                      context.push('/polls?group=${e['group_id']}&event=$id'),
                ),
                if (canRsvp && mine is Map)
                  row(
                    Icons.edit_note_outlined,
                    'Guests and RSVP note',
                    onTap: _busy
                        ? null
                        : () {
                            final api = ref.read(liveEventsApiProvider);
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => _RsvpSheet(
                                api: api,
                                id: id,
                                mine: Map<String, Object?>.from(mine),
                              ),
                            );
                          },
                  ),
                if ((e['description'] as String? ?? '').isNotEmpty) ...[
                  const CircleSectionTitle('About'),
                  Text(
                    e['description'] as String,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
                if (!canRsvp)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.lg),
                    child: Text(
                      mine is Map
                          ? 'Your RSVP: ${_answerLabel(mine['status'])}'
                          : 'You haven’t replied yet.',
                      style: caption,
                    ),
                  ),
              ],
            ),
          );
          // Answers sit in the thumb zone, pinned below the details.
          return Column(
            children: [
              Expanded(child: details),
              if (canRsvp)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: CircleAccents.of(context).hairline,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.section,
                      Space.md,
                      Space.section,
                      Space.lg,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          chosen == null
                              ? 'Are you coming?'
                              : 'Your answer: ${_answerLabel(chosen)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: CircleAccents.of(context).caption,
                              ),
                        ),
                        const SizedBox(height: Space.sm),
                        Row(
                          children: [
                            for (final (index, choice) in {
                              'going': 'Going',
                              'maybe': 'Maybe',
                              'not_going': 'Can’t go',
                            }.entries.indexed) ...[
                              if (index > 0) const SizedBox(width: Space.sm),
                              Expanded(child: choiceButton(choice)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One upcoming event in the live list: optional cover, the date badge,
/// title and when/where, like the preview cards.
class _LiveEventCard extends ConsumerWidget {
  const _LiveEventCard({required this.item, required this.onTap});
  final Map<String, Object?> item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: CircleAccents.of(context).caption,
    );
    final cancelled = item['status'] == 'cancelled';
    final venue = item['venue'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CircleRadius.card),
          side: BorderSide(color: CircleAccents.of(context).hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (item['cover_id'] case final String cover)
                PrivatePhoto(
                  load: ref.watch(
                    liveEventCoverProvider((
                      event: '${item['id']}',
                      cover: cover,
                    )),
                  ),
                  label: 'Event cover',
                ),
              Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Row(
                  children: [
                    EventDateBlock(
                      wall: liveEventWall(
                        item['start_at'] as String,
                        item['timezone'] as String,
                      ),
                    ),
                    const SizedBox(width: Space.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: Space.xs),
                          Text(liveEventLabel(item), style: caption),
                          if (cancelled || venue.isNotEmpty)
                            Text(
                              cancelled ? 'Cancelled' : venue,
                              style: caption,
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: CircleAccents.of(context).caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiveEventForm extends ConsumerWidget {
  const LiveEventForm({super.key, this.id, this.group});
  final String? id, group;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(liveEventsApiProvider);
    if (id == null) {
      return _EventEditor(
        key: ValueKey('${api.scope.account}-${api.scope.session}'),
        group: group,
        api: api,
      );
    }
    return ref
        .watch(liveEventProvider(id!))
        .when(
          loading: () => const CircleSkeletonPage(label: 'Loading event'),
          error: (_, _) => CircleEmpty(
            title: 'Event couldn’t load',
            message: 'Refresh and try again.',
            action: TextButton(
              onPressed: () => ref.invalidate(liveEventProvider(id!)),
              child: const Text('Try again'),
            ),
          ),
          data: (e) => e['can_manage'] == true && e['status'] == 'active'
              ? _EventEditor(
                  key: ValueKey(
                    '${api.scope.account}-${api.scope.session}-$id-${e['version']}',
                  ),
                  id: id,
                  saved: e,
                  api: api,
                )
              : const CircleEmpty(
                  title: 'Editing unavailable',
                  message:
                      'Only the organizer or current group admins can edit.',
                ),
        );
  }
}

class _EventEditor extends ConsumerStatefulWidget {
  const _EventEditor({
    super.key,
    this.id,
    this.group,
    this.saved,
    required this.api,
  });
  final String? id, group;
  final Map<String, Object?>? saved;
  final LiveEventsApi api;
  @override
  ConsumerState<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends ConsumerState<_EventEditor> {
  final _title = TextEditingController(),
      _venue = TextEditingController(),
      _description = TextEditingController(),
      _link = TextEditingController(),
      _capacity = TextEditingController();
  String _zone = 'UTC', _type = 'other';
  String? _group, _key, _signature;
  DateTime? _start, _end, _deadline;
  bool _busy = false, _zoneTouched = false;
  @override
  void initState() {
    super.initState();
    final e = widget.saved;
    _group = widget.group;
    if (e != null) {
      _group = ApiJson.id(e['group_id']);
      _zone = e['timezone'] as String;
      _type = e['event_type'] as String;
      _title.text = e['title'] as String;
      _venue.text = e['venue'] as String? ?? '';
      _description.text = e['description'] as String? ?? '';
      _link.text = e['online_link'] as String? ?? '';
      _capacity.text = e['max_capacity']?.toString() ?? '';
      _start = liveEventWall(e['start_at'] as String, _zone);
      if (e['end_at'] != null) {
        _end = liveEventWall(e['end_at'] as String, _zone);
      }
      if (e['rsvp_deadline'] != null) {
        _deadline = liveEventWall(e['rsvp_deadline'] as String, _zone);
      }
    } else {
      Future.microtask(() async {
        final zone = await ref.read(deviceTimezoneProvider).read();
        if (mounted &&
            !_zoneTouched &&
            zone != null &&
            liveEventZones().contains(zone)) {
          setState(() => _zone = zone);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _venue, _description, _link, _capacity]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime? initial) async {
    final d = initial ?? DateTime.now().add(const Duration(days: 1));
    final day = await showDatePicker(
      context: context,
      initialDate: DateTime(d.year, d.month, d.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2037, 12, 31),
    );
    if (day == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: d.hour, minute: d.minute),
    );
    if (time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(circleWorkspaceProvider).value;
    final groups =
        workspace?.groups
            .where(
              (g) =>
                  g.isMember(workspace.viewer) &&
                  (g.roles[workspace.viewer]?.isAdmin == true ||
                      g.settings.eventCreation == EventCreationPolicy.members),
            )
            .toList() ??
        [];
    final selected = groups.any((g) => g.id == _group)
        ? _group
        : groups.length == 1
        ? groups.single.id
        : null;
    Widget date(
      String label,
      DateTime? value,
      void Function(DateTime?) save, {
      bool optional = false,
    }) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        value == null
            ? 'Choose date and time · $_zone'
            : '${value.year}-${value.month}-${value.day} ${value.hour}:${value.minute.toString().padLeft(2, '0')} · $_zone',
      ),
      trailing: optional
          ? IconButton(
              onPressed: _busy ? null : () => setState(() => save(null)),
              icon: const Icon(Icons.close),
              tooltip: 'Clear $label',
            )
          : const Icon(Icons.calendar_today_outlined),
      onTap: _busy
          ? null
          : () async {
              final d = await _pick(value);
              if (d != null && mounted) setState(() => save(d));
            },
    );
    return ReadingPane(
      child: ListView(
        padding: CircleInsets.form,
        children: [
          CircleHeading(
            title: widget.id == null ? 'Plan an event' : 'Edit event',
            subtitle: 'A place and time for your circle.',
          ),
          if (widget.id == null)
            DropdownButtonFormField<String>(
              initialValue: selected,
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Group'),
              items: [
                for (final g in groups)
                  DropdownMenuItem(value: g.id, child: Text(g.name)),
              ],
              onChanged: _busy ? null : (v) => setState(() => _group = v),
            ),
          TextField(
            controller: _title,
            enabled: !_busy,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Event title'),
          ),
          TextField(
            controller: _venue,
            enabled: !_busy,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Place'),
          ),
          date('Start', _start, (v) => _start = v),
          ExpansionTile(
            title: const Text('More options'),
            children: [
              TextField(
                controller: _description,
                enabled: !_busy,
                maxLength: 10000,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: _link,
                enabled: !_busy,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Meeting link',
                  helperText:
                      'Optional HTTPS URL. Use instead of a place for online events.',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _type,
                isExpanded: true,
                itemHeight: null,
                decoration: const InputDecoration(labelText: 'Event type'),
                items: [
                  for (final type in [
                    'function',
                    'wedding',
                    'reunion',
                    'meetup',
                    'birthday',
                    'trip',
                    'online',
                    'other',
                  ])
                    DropdownMenuItem(value: type, child: Text(type)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _type = v!),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(_zone),
                initialValue: _zone,
                isExpanded: true,
                itemHeight: null,
                decoration: const InputDecoration(labelText: 'Event time zone'),
                items: [
                  for (final zone in liveEventZones())
                    DropdownMenuItem(value: zone, child: Text(zone)),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _zoneTouched = true;
                        _zone = v!;
                      }),
              ),
              date('End', _end, (v) => _end = v, optional: true),
              date(
                'RSVP deadline',
                _deadline,
                (v) => _deadline = v,
                optional: true,
              ),
              TextField(
                controller: _capacity,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capacity',
                  helperText: 'Optional. Includes guests.',
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    if (selected == null ||
                        _start == null ||
                        _title.text.trim().isEmpty) {
                      showCircleMessage(
                        context,
                        'Choose a group, title and start time.',
                      );
                      return;
                    }
                    setState(() => _busy = true);
                    final result = await runCalmly(context, () async {
                      final capacity = _capacity.text.trim().isEmpty
                          ? null
                          : int.tryParse(_capacity.text.trim());
                      if (_capacity.text.trim().isNotEmpty &&
                          capacity == null) {
                        throw const CircleFailure(
                          'Capacity must be a whole number.',
                        );
                      }
                      final body = <String, Object?>{
                        'title': _title.text.trim(),
                        'description': _description.text.trim(),
                        'event_type': _type,
                        'venue': _venue.text.trim(),
                        'online_link': _link.text.trim(),
                        'timezone': _zone,
                        'start_at': liveEventInstant(_start!, _zone),
                        'end_at': _end == null
                            ? null
                            : liveEventInstant(_end!, _zone),
                        'rsvp_deadline': _deadline == null
                            ? null
                            : liveEventInstant(_deadline!, _zone),
                        'max_capacity': capacity,
                      };
                      if (widget.id != null) {
                        await widget.api.update(widget.id!, {
                          ...body,
                          'version': widget.saved!['version'],
                        });
                        return widget.id!;
                      }
                      final signature = jsonEncode([selected, body]);
                      if (signature != _signature) {
                        _signature = signature;
                        _key =
                            'event-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
                      }
                      return ApiJson.id(
                        (await widget.api.create(selected, {
                          ...body,
                          'client_id': _key,
                        }))['id'],
                      );
                    });
                    if (!context.mounted) return;
                    setState(() => _busy = false);
                    if (result != null) {
                      refreshLiveEvents(ref);
                      context.go('/events/e/$result');
                    }
                  },
            child: Text(
              _busy
                  ? 'Saving…'
                  : widget.id == null
                  ? 'Create event'
                  : 'Save event',
            ),
          ),
        ],
      ),
    );
  }
}

class _RsvpSheet extends ConsumerStatefulWidget {
  const _RsvpSheet({required this.api, required this.id, required this.mine});
  final LiveEventsApi api;
  final String id;
  final Map<String, Object?> mine;
  @override
  ConsumerState<_RsvpSheet> createState() => _RsvpState();
}

class _RsvpState extends ConsumerState<_RsvpSheet> {
  late final TextEditingController _note;
  late int _guests;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.mine['note'] as String? ?? '');
    _guests = widget.mine['guest_count'] as int? ?? 0;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: ListView(
      shrinkWrap: true,
      padding: CircleInsets.form,
      children: [
        const CircleHeading(
          title: 'Guests and note',
          subtitle: 'Saving sets your RSVP to Going.',
        ),
        DropdownButtonFormField<int>(
          initialValue: _guests,
          isExpanded: true,
          itemHeight: null,
          decoration: const InputDecoration(labelText: 'Guests'),
          items: [
            for (var i = 0; i <= 10; i++)
              DropdownMenuItem(value: i, child: Text('$i')),
          ],
          onChanged: _busy ? null : (v) => setState(() => _guests = v!),
        ),
        TextField(
          controller: _note,
          enabled: !_busy,
          maxLength: 500,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Private note',
            helperText: 'Only you can view this note.',
          ),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  final ok = await runCalmly(context, () async {
                    await widget.api.rsvp(
                      widget.id,
                      'going',
                      _guests,
                      _note.text,
                    );
                    return true;
                  }, success: 'RSVP saved.');
                  if (!context.mounted) return;
                  if (ok == true) {
                    refreshLiveEvents(ref);
                    Navigator.pop(context);
                  } else {
                    setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? 'Saving…' : 'Save RSVP'),
        ),
      ],
    ),
  );
}

class LiveAttendeesScreen extends ConsumerStatefulWidget {
  const LiveAttendeesScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<LiveAttendeesScreen> createState() => _AttendeesState();
}

class _AttendeesState extends ConsumerState<LiveAttendeesScreen> {
  int _offset = 0;

  /// People from earlier pages; the list grows as it scrolls.
  final _earlier = <Map<String, Object?>>[];

  Widget _list(List<Map<String, Object?>> people, {Widget? end}) => ListView(
    padding: CircleInsets.form,
    children: [
      const CircleHeading(
        title: 'Who’s coming?',
        subtitle: 'Notes and mobile numbers stay private.',
      ),
      if (people.isEmpty)
        const CircleEmpty(
          title: 'No answers yet',
          message:
              'When people answer Going, Maybe or Can’t go, they show up here.',
        ),
      for (final person in people)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleInitialAvatar(name: person['display_name'] as String),
          title: Text(person['display_name'] as String),
          subtitle: Text(
            [
              _answerLabel(person['status']),
              if (((person['guest_count'] as num?)?.toInt() ?? 0) > 0)
                '+${person['guest_count']} with them',
            ].join(' · '),
          ),
        ),
      ?end,
    ],
  );

  @override
  Widget build(BuildContext context) => ReadingPane(
    child: ref
        .watch(liveAttendeesProvider((id: widget.id, offset: _offset)))
        .when(
          loading: () => _earlier.isNotEmpty
              ? _list(
                  _earlier,
                  end: const Padding(
                    padding: EdgeInsets.all(Space.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              : const CircleSkeletonPage(label: 'Loading attendees'),
          error: (_, _) => CircleEmpty(
            title: 'Attendees couldn’t load',
            message: 'Check your connection and membership.',
            action: TextButton(
              onPressed: () => ref.invalidate(liveAttendeesProvider),
              child: const Text('Try again'),
            ),
          ),
          data: (data) {
            final people = ApiJson.list(
              data['items'],
            ).map(ApiJson.map).toList();
            return _list(
              [..._earlier, ...people],
              end: data['has_more'] == true
                  ? CircleLoadMore(
                      key: ValueKey('more-$_offset'),
                      onLoad: () => setState(() {
                        _earlier.addAll(people);
                        _offset += 30;
                      }),
                    )
                  : null,
            );
          },
        ),
  );
}

/// "Going", "Maybe" or "Can’t go" for a saved RSVP status.
String _answerLabel(Object? status) => switch (status) {
  'going' => 'Going',
  'maybe' => 'Maybe',
  'not_going' => 'Can’t go',
  _ => '$status',
};
