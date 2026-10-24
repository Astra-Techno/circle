import 'package:flutter/material.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../groups/domain/group_tree.dart';
import '../../workspace/domain/circle_workspace.dart';
import 'circle_events.dart' show CircleEventCard;

/// E1's month calendar: Monday-first weeks, today ringed, days with events
/// dotted. Tapping a day lists its events underneath. Starts at [today]'s
/// month; earlier months are under Past, so Previous stops there.
class EventMonthView extends StatefulWidget {
  const EventMonthView({
    super.key,
    required this.events,
    required this.workspace,
    required this.today,
  });

  /// Already filtered (group chip, upcoming), soonest first.
  final List<CircleEvent> events;
  final CircleWorkspace workspace;

  /// The viewer's local date.
  final DateTime today;
  @override
  State<EventMonthView> createState() => _EventMonthViewState();
}

class _EventMonthViewState extends State<EventMonthView> {
  late DateTime _month = EventCalendar.monthOf(widget.today);
  late DateTime? _selected = EventCalendar.dateOnly(widget.today);

  DateTime get _first => EventCalendar.monthOf(widget.today);

  void _showMonth(int delta) => setState(() {
    _month = EventCalendar.addMonths(_month, delta);
    final today = EventCalendar.dateOnly(widget.today);
    // Keep a selection only inside the month on screen.
    _selected = EventCalendar.monthOf(today) == _month ? today : null;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byDay = EventCalendar.byDay(widget.events);
    final today = EventCalendar.dateOnly(widget.today);
    final selected = _selected;
    final dayEvents = selected == null ? null : byDay[selected] ?? const [];
    final monthLabel = EventCalendar.monthLabel(_month);
    final inMonth = byDay.entries
        .where((entry) => EventCalendar.monthOf(entry.key) == _month)
        .fold<int>(0, (sum, entry) => sum + entry.value.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: _month.isAfter(_first) ? () => _showMonth(-1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Semantics(
                header: true,
                liveRegion: true,
                label:
                    '$monthLabel, '
                    '${inMonth == 0
                        ? 'no events'
                        : inMonth == 1
                        ? '1 event'
                        : '$inMonth events'}',
                excludeSemantics: true,
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => _showMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: Space.xs),
        _MonthGrid(
          month: _month,
          today: today,
          selected: selected,
          counts: {
            for (final entry in byDay.entries) entry.key: entry.value.length,
          },
          onSelect: (day) => setState(() => _selected = day),
        ),
        if (selected != null) ...[
          CircleSectionTitle(EventCalendar.dayTitle(selected)),
          if (dayEvents!.isEmpty)
            Text(
              selected == today
                  ? 'Nothing planned today.'
                  : 'Nothing planned on this day.',
              style: theme.textTheme.bodySmall,
            ),
          for (final event in dayEvents) _card(event),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: Space.md),
            child: Text(
              'Choose a day to see its events.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _card(CircleEvent event) {
    final workspace = widget.workspace;
    final group = workspace.group(event.groupId)!;
    return CircleEventCard(
      key: ValueKey('calendar-${event.id}'),
      event: event,
      group: group,
      viewer: workspace.viewer,
      audience: audiencePath(group, workspace.groupsById),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.selected,
    required this.counts,
    required this.onSelect,
  });
  final DateTime month, today;
  final DateTime? selected;
  final Map<DateTime, int> counts;
  final ValueChanged<DateTime> onSelect;

  /// Every day stays a 48px target; narrower screens scroll sideways.
  static const _minCell = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = theme.textTheme.labelSmall?.copyWith(
      color: CircleAccents.of(context).caption,
    );
    final weeks = EventCalendar.weeks(EventCalendar.monthGrid(month));
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth / 7;
        final cell = width < _minCell ? _minCell : width;
        final grid = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The days already say their weekday to screen readers.
            ExcludeSemantics(
              child: Row(
                children: [
                  for (final label in EventCalendar.weekdayLabels)
                    SizedBox(
                      width: cell,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Space.xs),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(label, style: caption),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (final week in weeks)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final day in week)
                    SizedBox(
                      width: cell,
                      child: day.month != month.month
                          ? const SizedBox(height: _minCell)
                          : _DayCell(
                              day: day,
                              count: counts[day] ?? 0,
                              today: day == today,
                              selected: day == selected,
                              onTap: () => onSelect(day),
                            ),
                    ),
                ],
              ),
          ],
        );
        return cell * 7 > constraints.maxWidth + 0.5
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: grid,
              )
            : grid;
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.count,
    required this.today,
    required this.selected,
    required this.onTap,
  });
  final DateTime day;
  final int count;
  final bool today, selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      key: ValueKey('calendar-day-${day.year}-${day.month}-${day.day}'),
      button: true,
      selected: selected,
      label: EventCalendar.daySemantics(day, events: count, today: today),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CircleRadius.tile),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _MonthGrid._minCell),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: const BoxConstraints(
                    minWidth: Space.hero,
                    minHeight: Space.hero,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(Space.xs),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? colors.primary : null,
                    border: today && !selected
                        ? Border.all(color: colors.primary, width: 1.5)
                        : null,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${day.day}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected ? colors.onPrimary : colors.onSurface,
                        fontWeight: today || count > 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.xs / 2),
                // One quiet dot for "something planned"; the count is in
                // the spoken label.
                Container(
                  width: Space.xs + Space.xs / 2,
                  height: Space.xs + Space.xs / 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: count > 0 ? colors.primary : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
