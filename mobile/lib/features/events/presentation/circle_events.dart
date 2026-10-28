import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/two_pane.dart';
import '../../groups/domain/group_tree.dart';
import '../../groups/domain/membership_rules.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/group_visuals.dart';
import '../../workspace/presentation/workspace_view.dart';
import '../application/events_filter.dart';
import 'event_month_view.dart';
import 'event_visuals.dart';

export '../application/events_filter.dart';
export 'event_attendees.dart';
export 'event_detail.dart';
export 'event_form.dart';

/// E1: upcoming or past events across the viewer's groups, grouped by
/// month, with the same group chips as Home. Upcoming can also be seen as
/// a month calendar ("List | Month").
class CircleEvents extends ConsumerStatefulWidget {
  const CircleEvents({super.key});
  @override
  ConsumerState<CircleEvents> createState() => _CircleEventsState();
}

class _CircleEventsState extends ConsumerState<CircleEvents> {
  bool _past = false;

  /// Upcoming as a month calendar instead of a list.
  bool _calendar = false;

  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      final now = ref.watch(circleClockProvider)().toUtc();
      final selected = ref.watch(eventsGroupFilterProvider);
      final group = workspace.group(selected ?? '');
      final events = [
        for (final event in workspace.events)
          if ((group == null || event.groupId == group.id) &&
              EventRules.isUpcoming(event, now) != _past)
            event,
      ];
      final ordered = _past ? events.reversed.toList() : events;
      final canCreateHere = group == null
          ? null
          : MembershipRules.canCreateEvent(group, workspace.viewer);
      void select(String? id) =>
          ref.read(eventsGroupFilterProvider.notifier).select(id);

      final children = <Widget>[
        const PreviewLabel(
          'Preview: events and RSVPs stay on this device. No invitations or reminders are sent.',
        ),
      ];
      if (workspace.groups.isEmpty) {
        children.add(
          CircleEmpty(
            title: 'Events live inside a group',
            message:
                'Create or join a group first. Only its members will see its events.',
            action: FilledButton.icon(
              onPressed: () => context.go('/groups/new'),
              icon: const Icon(Icons.add),
              label: const Text('Create a group'),
            ),
          ),
        );
      } else {
        children.addAll([
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: group == null,
                  onTap: () => select(null),
                ),
                for (final entry in buildGroupTree(workspace.groups))
                  _FilterChip(
                    label: entry.group.name,
                    selected: group?.id == entry.group.id,
                    onTap: () => select(
                      group?.id == entry.group.id ? null : entry.group.id,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.md,
            runSpacing: Space.sm,
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Upcoming')),
                  ButtonSegment(value: true, label: Text('Past')),
                ],
                selected: {_past},
                onSelectionChanged: (value) =>
                    setState(() => _past = value.first),
              ),
              if (!_past)
                SegmentedButton<bool>(
                  key: const ValueKey('events-view'),
                  showSelectedIcon: false,
                  // Icons only, so both controls share one row.
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.view_agenda_outlined),
                      tooltip: 'List',
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.calendar_month_outlined),
                      tooltip: 'Month',
                    ),
                  ],
                  selected: {_calendar},
                  onSelectionChanged: (value) =>
                      setState(() => _calendar = value.first),
                ),
            ],
          ),
          const SizedBox(height: Space.sm),
          if (canCreateHere != null && !canCreateHere.allowed)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text(
                canCreateHere.reason!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (!_past && _calendar)
            EventMonthView(
              events: ordered,
              workspace: workspace,
              today: ref.watch(circleClockProvider)().toLocal(),
            )
          else if (ordered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.md),
              child: CircleEmpty(
                title: _past ? 'No past events yet' : 'Nothing planned yet',
                message: _past
                    ? 'Events appear here once they have ended.'
                    : 'Plan a lunch, a call or a trip. Only the group you choose will see it.',
              ),
            ),
          if (_past || !_calendar) ..._monthSections(ordered, workspace, now),
        ]);
      }
      return ReadingPane(
        child: ListView(
          key: const PageStorageKey('circle-events'),
          padding: CircleInsets.page,
          children: children,
        ),
      );
    },
  );

  List<Widget> _monthSections(
    List<CircleEvent> events,
    CircleWorkspace workspace,
    DateTime now,
  ) {
    final result = <Widget>[];
    String? month;
    for (final event in events) {
      final label = formatMonth(event.localStart);
      if (label != month) {
        month = label;
        result.add(CircleSectionTitle(label));
      }
      final group = workspace.group(event.groupId)!;
      result.add(
        CircleEventCard(
          key: ValueKey(event.id),
          event: event,
          group: group,
          viewer: workspace.viewer,
          audience: audiencePath(group, workspace.groupsById),
        ),
      );
    }
    return result;
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: Space.sm),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        label: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? colors.onPrimary : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// One event in a list: date block, title, type and audience pills, time
/// with zone, place, the viewer's answer and the attendee count.
class CircleEventCard extends ConsumerWidget {
  const CircleEventCard({
    super.key,
    required this.event,
    required this.group,
    required this.viewer,
    this.audience,
  });
  final CircleEvent event;
  final CircleGroup group;
  final String viewer;

  /// "Root › Group"; defaults to the group's name.
  final String? audience;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = ref.watch(circleClockProvider)().toUtc();
    final attendance = EventRules.attendance(event.rsvps);
    final place = event.venue ?? (event.onlineLink != null ? 'Online' : null);
    Widget detail(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (!CirclePaneScope.select(context, 'events', event.id)) {
            context.push('/events/e/${event.id}');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EventDateBlock(wall: event.localStart),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: Space.sm),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.xs,
                      children: [
                        if (event.cancelled)
                          const CirclePill(
                            'Cancelled',
                            icon: Icons.event_busy_outlined,
                            tone: CircleTone.strong,
                          ),
                        CirclePill(
                          event.type.label,
                          icon: eventTypeIcon(event.type),
                        ),
                        CirclePill(
                          audience ?? group.name,
                          icon: Icons.lock_outline,
                          tone: circleTypeTone(group.type),
                          semanticsLabel: 'For ${group.name} only',
                        ),
                      ],
                    ),
                    detail(Icons.schedule, eventWhenLabel(event, now)),
                    if (place != null)
                      detail(
                        event.venue == null
                            ? Icons.videocam_outlined
                            : Icons.place_outlined,
                        place,
                      ),
                    if (!event.cancelled)
                      detail(
                        Icons.how_to_reg_outlined,
                        rsvpStatusLabel(event.rsvpOf(viewer)),
                      ),
                    detail(Icons.groups_outlined, attendanceLine(attendance)),
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

/// The Events tab of a group space: that exact group's upcoming events and
/// "Create event" when the group allows the viewer to create one.
class GroupEventsTab extends ConsumerWidget {
  const GroupEventsTab({
    super.key,
    required this.group,
    required this.workspace,
  });
  final CircleGroup group;
  final CircleWorkspace workspace;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(circleClockProvider)().toUtc();
    final events = workspace.events
        .where(
          (event) =>
              event.groupId == group.id && EventRules.isUpcoming(event, now),
        )
        .toList();
    final canCreate = MembershipRules.canCreateEvent(group, workspace.viewer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canCreate.allowed)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => context.push(eventCreateLocation(group.id)),
              icon: const Icon(Icons.add),
              label: const Text('Create event'),
            ),
          )
        else
          Text(canCreate.reason!, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Space.lg),
        if (events.isEmpty)
          const CircleEmpty(
            title: 'Make time for each other',
            message:
                'Upcoming events for this exact group will appear here. Past ones are under Events › Past.',
          ),
        for (final event in events)
          CircleEventCard(
            key: ValueKey(event.id),
            event: event,
            group: group,
            viewer: workspace.viewer,
          ),
      ],
    );
  }
}
