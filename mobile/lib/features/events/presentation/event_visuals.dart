import 'package:flutter/material.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/domain/circle_workspace.dart';

IconData eventTypeIcon(EventType type) => switch (type) {
  EventType.familyFunction => Icons.family_restroom_outlined,
  EventType.wedding => Icons.celebration_outlined,
  EventType.reunion => Icons.handshake_outlined,
  EventType.meetup => Icons.local_cafe_outlined,
  EventType.birthday => Icons.cake_outlined,
  EventType.trip => Icons.luggage_outlined,
  EventType.online => Icons.videocam_outlined,
  EventType.other => Icons.event_outlined,
};

/// Today's date in the event's own zone, so years show only when needed.
DateTime eventToday(CircleEvent event, DateTime now) =>
    wallClock(now, event.utcOffset);

/// "Sat 25 Oct · 12:30 PM – 4:00 PM IST" (or across days with both dates).
String eventWhenLabel(CircleEvent event, DateTime now) {
  final today = eventToday(event, now);
  final start = event.localStart;
  final end = event.localEnd;
  final day = formatDay(start, today: today);
  final zone = event.timeZoneLabel;
  if (end == null) return '$day · ${formatTime(start)} $zone';
  if (sameDay(start, end)) {
    return '$day · ${formatTime(start)} – ${formatTime(end)} $zone';
  }
  return '$day, ${formatTime(start)} – '
      '${formatDay(end, today: today)}, ${formatTime(end)} $zone';
}

/// "You're going with 2 people", "You said maybe", or "Not answered yet".
String rsvpStatusLabel(Rsvp? rsvp) {
  if (rsvp == null) return 'You haven’t answered yet';
  final guests = rsvp.guests == 0
      ? ''
      : ' with ${rsvp.guests} ${rsvp.guests == 1 ? 'person' : 'people'}';
  return switch (rsvp.status) {
    Attendance.going => 'You’re going$guests',
    Attendance.maybe => 'You said maybe$guests',
    Attendance.notGoing => 'You’re not going',
  };
}

/// "3 going · 9 people expected".
String attendanceLine(EventAttendance attendance) =>
    '${attendance.going} going · ${attendance.expected} '
    '${attendance.expected == 1 ? 'person' : 'people'} expected';

/// "Mira and You", "Dev, Lena and You".
String joinNames(List<String> names) {
  if (names.isEmpty) return '';
  if (names.length == 1) return names.single;
  return '${names.take(names.length - 1).join(', ')} and ${names.last}';
}

/// The month and day on event cards. Decorative: the card's time line
/// already reads the full date.
class EventDateBlock extends StatelessWidget {
  const EventDateBlock({super.key, required this.wall});
  final DateTime wall;
  @override
  Widget build(BuildContext context) {
    final palette = circleToneColors(context, CircleTone.calm);
    final text = Theme.of(context).textTheme;
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        decoration: BoxDecoration(
          color: palette.fill,
          borderRadius: BorderRadius.circular(CircleRadius.tile),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMonthShort(wall),
              style: text.labelMedium?.copyWith(color: palette.text),
            ),
            Text(
              '${wall.day}',
              style: text.headlineSmall?.copyWith(color: palette.text),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet status line: "This event has ended", "RSVPs are closed".
class EventNotice extends StatelessWidget {
  const EventNotice({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final palette = circleToneColors(context, CircleTone.neutral);
    return Container(
      margin: const EdgeInsets.only(bottom: Space.md),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: palette.fill,
        borderRadius: BorderRadius.circular(CircleRadius.tile),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.text),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Event pages get their own ink surface, so list tiles on a page that is
/// covered (for example the detail page under a deep-linked attendees page)
/// never paint ink on the shell's surface while not laid out.
class EventPage extends StatelessWidget {
  const EventPage({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Material(type: MaterialType.transparency, child: child);
}
