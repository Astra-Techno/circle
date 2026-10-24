import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/groups/domain/membership_rules.dart';
import 'package:mobile/features/workspace/domain/circle_workspace.dart';

final now = DateTime.utc(2026, 10, 23, 4, 30); // 10:00 AM IST, a Friday
const ist = Duration(hours: 5, minutes: 30);

EventDraft draft({
  String title = 'Sunday lunch',
  EventType type = EventType.familyFunction,
  DateTime? start,
  bool noStart = false,
  DateTime? end,
  String? venue = 'Grandma’s house',
  String? link,
  String? description,
  DateTime? deadline,
  int? capacity,
  List<String> coHosts = const [],
  DatePollDraft? datePoll,
}) => EventDraft(
  groupId: 'family',
  title: title,
  type: type,
  startsAt: noStart ? null : start ?? now.add(const Duration(days: 2)),
  endsAt: end,
  timeZoneLabel: 'IST',
  utcOffset: ist,
  venue: venue,
  onlineLink: link,
  description: description,
  rsvpDeadline: deadline,
  capacity: capacity,
  coHosts: coHosts,
  datePoll: datePoll,
);

CircleEvent event({
  DateTime? start,
  DateTime? end,
  DateTime? deadline,
  int? capacity,
  Map<String, Rsvp> rsvps = const {},
  DateTime? cancelledAt,
}) => CircleEvent(
  id: 'e',
  groupId: 'family',
  createdBy: 'host',
  hosts: const ['host', 'cohost'],
  type: EventType.meetup,
  title: 'Meetup',
  startsAt: start ?? now.add(const Duration(days: 2)),
  endsAt: end,
  timeZoneLabel: 'IST',
  utcOffset: ist,
  createdAt: now.subtract(const Duration(days: 1)),
  venue: 'Park',
  rsvpDeadline: deadline,
  capacity: capacity,
  rsvps: rsvps,
  cancelledAt: cancelledAt,
);

List<String> messages(EventDraft value, {DateTime? originalStart}) => [
  for (final issue in EventRules.validate(
    value,
    now: now,
    originalStart: originalStart,
  ))
    issue.message,
];

Set<EventField> fields(EventDraft value) => {
  for (final issue in EventRules.validate(value, now: now)) issue.field,
};

void main() {
  group('event validation', () {
    test('title, date and place are enough', () {
      expect(messages(draft()), isEmpty);
      expect(EventRules.checkDraft(draft(), now: now).allowed, isTrue);
    });

    test('title needs 1–100 characters', () {
      expect(fields(draft(title: '   ')), {EventField.title});
      expect(fields(draft(title: 'a' * 101)), {EventField.title});
      expect(messages(draft(title: 'a' * 100)), isEmpty);
    });

    test('start is required and must be in the future', () {
      expect(messages(draft(noStart: true)), [
        'Choose a date and a start time.',
      ]);
      final past = now.subtract(const Duration(hours: 1));
      expect(fields(draft(start: past)), {EventField.start});
      expect(fields(draft(start: now)), {EventField.start});
      // Editing may keep an unchanged start.
      expect(messages(draft(start: past), originalStart: past), isEmpty);
    });

    test('end must be after the start', () {
      final start = now.add(const Duration(days: 2));
      expect(fields(draft(start: start, end: start)), {EventField.end});
      expect(
        fields(
          draft(start: start, end: start.subtract(const Duration(minutes: 1))),
        ),
        {EventField.end},
      );
      expect(
        messages(draft(start: start, end: start.add(const Duration(hours: 3)))),
        isEmpty,
      );
    });

    test('RSVP deadline is in the future and on or before the start', () {
      final start = now.add(const Duration(days: 2));
      expect(messages(draft(start: start, deadline: start)), isEmpty);
      expect(
        messages(
          draft(start: start, deadline: start.add(const Duration(minutes: 1))),
        ),
        ['The RSVP deadline needs to be on or before the start.'],
      );
      expect(fields(draft(deadline: now)), {EventField.deadline});
    });

    test('capacity is at least 1 person', () {
      expect(fields(draft(capacity: 0)), {EventField.capacity});
      expect(fields(draft(capacity: -3)), {EventField.capacity});
      expect(fields(draft(capacity: EventRules.maxCapacity + 1)), {
        EventField.capacity,
      });
      expect(messages(draft(capacity: 1)), isEmpty);
    });

    test('venue is required except for online events, which need a link', () {
      expect(messages(draft(venue: '  ')), [
        'Add a place, like a home, a hall or a park.',
      ]);
      expect(fields(draft(venue: 'a' * 121)), {EventField.venue});
      expect(messages(draft(venue: 'a' * 120)), isEmpty);
      // A link alone is not a place for an in-person event.
      expect(fields(draft(venue: null, link: 'meet.example.invalid/x')), {
        EventField.venue,
      });
      expect(messages(draft(type: EventType.online, venue: null)), [
        'Add the link people will use to join.',
      ]);
      expect(
        messages(
          draft(
            type: EventType.online,
            venue: null,
            link: 'meet.example.invalid/x',
          ),
        ),
        isEmpty,
      );
      expect(
        fields(draft(type: EventType.online, link: 'a link with spaces')),
        {EventField.onlineLink},
      );
      expect(fields(draft(link: 'a' * 301)), {EventField.onlineLink});
    });

    test('description up to 2000 characters, co-hosts up to 10', () {
      expect(fields(draft(description: 'a' * 2001)), {EventField.description});
      expect(messages(draft(description: 'a' * 2000)), isEmpty);
      expect(fields(draft(coHosts: [for (var i = 0; i < 11; i++) 'p$i'])), {
        EventField.coHosts,
      });
    });

    test('several problems are all reported, in form order', () {
      expect(
        fields(draft(title: '', noStart: true, venue: null, capacity: 0)),
        {
          EventField.title,
          EventField.start,
          EventField.venue,
          EventField.capacity,
        },
      );
    });
  });

  group('date polls', () {
    final a = now.add(const Duration(days: 3));
    final b = now.add(const Duration(days: 4));

    test('need 2–6 different future slots', () {
      expect(EventRules.checkDateSlots([a, b], now: now).allowed, isTrue);
      expect(
        EventRules.checkDateSlots([a], now: now).reason,
        'Give 2–6 date options.',
      );
      expect(
        EventRules.checkDateSlots([
          for (var i = 1; i <= 7; i++) now.add(Duration(days: i)),
        ], now: now).allowed,
        isFalse,
      );
      expect(
        EventRules.checkDateSlots([
          a,
          a.add(const Duration(seconds: 20)),
        ], now: now).reason,
        'Each date option needs to be different.',
      );
      expect(
        EventRules.checkDateSlots([a, now], now: now).reason,
        'Choose date options in the future.',
      );
      expect(fields(draft(datePoll: DatePollDraft(slots: [a]))), {
        EventField.datePoll,
      });
    });

    test('become a UI-3 poll with sorted, labelled slots', () {
      final poll = EventRules.datePollDraft(
        DatePollDraft(slots: [b, a], multipleChoice: false),
        offset: ist,
        zone: 'IST',
        today: wallClock(now, ist),
      );
      expect(poll.question, 'Which date works for you?');
      expect(poll.options, [
        'Mon 26 Oct · 10:00 AM IST',
        'Tue 27 Oct · 10:00 AM IST',
      ]);
      expect(poll.multipleChoice, isFalse);
      expect(poll.resultsVisibility, PollResultsVisibility.always);
      expect(poll.anonymous, isFalse);
      expect(PollRules.checkDraft(poll).allowed, isTrue);
    });

    test(
      'slot labels use the event zone and add the year only when needed',
      () {
        final slot = DateTime.utc(2026, 10, 25, 7);
        expect(
          EventRules.slotLabel(
            slot,
            offset: ist,
            zone: 'IST',
            today: wallClock(now, ist),
          ),
          'Sun 25 Oct · 12:30 PM IST',
        );
        expect(
          EventRules.slotLabel(
            DateTime.utc(2027, 1, 2, 18, 30),
            offset: ist,
            zone: 'IST',
            today: wallClock(now, ist),
          ),
          'Sun 3 Jan 2027 · 12:00 AM IST',
        );
      },
    );
  });

  group('who can create and manage', () {
    CircleGroup group(EventCreationPolicy policy) => CircleGroup(
      id: 'family',
      name: 'The Sunday table',
      type: CircleType.family,
      depth: 1,
      roles: const {
        'owner': CircleRole.owner,
        'admin': CircleRole.admin,
        'member': CircleRole.member,
      },
      settings: GroupSettings(eventCreation: policy),
    );

    test('members by default; admins only when the group says so', () {
      final open = group(EventCreationPolicy.members);
      expect(MembershipRules.canCreateEvent(open, 'member').allowed, isTrue);
      expect(MembershipRules.canCreateEvent(open, 'stranger').allowed, isFalse);
      final limited = group(EventCreationPolicy.admins);
      expect(
        MembershipRules.canCreateEvent(limited, 'member').reason,
        'Only admins can create events in The Sunday table.',
      );
      expect(MembershipRules.canCreateEvent(limited, 'admin').allowed, isTrue);
      expect(MembershipRules.canCreateEvent(limited, 'owner').allowed, isTrue);
      expect(const GroupSettings().eventCreation, EventCreationPolicy.members);
    });

    RuleResult manage(
      CircleEvent value,
      String actor, {
      bool member = true,
      bool admin = false,
    }) => EventRules.canManage(
      value,
      actor,
      isMember: member,
      isAdmin: admin,
      now: now,
    );

    test('hosts and group admins edit or cancel; others cannot', () {
      expect(manage(event(), 'host').allowed, isTrue);
      expect(manage(event(), 'cohost').allowed, isTrue);
      expect(manage(event(), 'admin', admin: true).allowed, isTrue);
      expect(
        manage(event(), 'member').reason,
        'Only the hosts or a group admin can change this event.',
      );
      expect(manage(event(), 'host', member: false).allowed, isFalse);
    });

    test('cancelled or ended events can no longer be changed', () {
      expect(manage(event(cancelledAt: now), 'host').allowed, isFalse);
      final past = event(
        start: now.subtract(const Duration(days: 2)),
        end: now.subtract(const Duration(days: 1)),
      );
      expect(manage(past, 'host').reason, 'This event has ended.');
      expect(EventRules.isUpcoming(past, now), isFalse);
      expect(EventRules.isUpcoming(event(), now), isTrue);
    });
  });

  group('RSVP', () {
    RuleResult rsvp(
      CircleEvent value,
      Rsvp answer, {
      String person = 'me',
      bool member = true,
      DateTime? at,
    }) => EventRules.canRsvp(
      value,
      person,
      answer,
      isMember: member,
      now: at ?? now,
    );
    const going = Rsvp(Attendance.going);

    test('only members of the exact group', () {
      expect(
        rsvp(event(), going, member: false).reason,
        'This group is not shared with you.',
      );
      expect(rsvp(event(), going).allowed, isTrue);
    });

    test('closed for cancelled, started, past and after the deadline', () {
      expect(rsvp(event(cancelledAt: now), going).allowed, isFalse);
      final started = event(
        start: now.subtract(const Duration(hours: 1)),
        end: now.add(const Duration(hours: 1)),
      );
      expect(
        rsvp(started, going).reason,
        'This event has started, so RSVPs are closed.',
      );
      final past = event(start: now.subtract(const Duration(days: 1)));
      expect(rsvp(past, going).reason, 'This event has ended.');
      final deadline = now.add(const Duration(days: 1));
      final closing = event(deadline: deadline);
      expect(
        rsvp(
          closing,
          going,
          at: deadline.subtract(const Duration(minutes: 1)),
        ).allowed,
        isTrue,
      );
      expect(
        rsvp(closing, going, at: deadline).reason,
        'The RSVP deadline has passed.',
      );
    });

    test('guests 0–20, only for Going or Maybe; notes up to 140', () {
      expect(
        rsvp(event(), const Rsvp(Attendance.going, guests: 20)).allowed,
        isTrue,
      );
      expect(
        rsvp(event(), const Rsvp(Attendance.maybe, guests: 3)).allowed,
        isTrue,
      );
      expect(
        rsvp(event(), const Rsvp(Attendance.going, guests: 21)).allowed,
        isFalse,
      );
      expect(
        rsvp(event(), const Rsvp(Attendance.going, guests: -1)).allowed,
        isFalse,
      );
      expect(
        rsvp(event(), const Rsvp(Attendance.notGoing, guests: 1)).allowed,
        isFalse,
      );
      expect(
        rsvp(event(), Rsvp(Attendance.going, note: 'a' * 140)).allowed,
        isTrue,
      );
      expect(
        rsvp(event(), Rsvp(Attendance.going, note: 'a' * 141)).reason,
        'Keep the note to 140 characters.',
      );
    });

    test('capacity counts going people and their guests, not maybe', () {
      final value = event(
        capacity: 6,
        rsvps: const {
          'a': Rsvp(Attendance.going, guests: 2), // 3 people
          'b': Rsvp(Attendance.maybe, guests: 5), // doesn't count
          'c': Rsvp(Attendance.notGoing),
        },
      );
      expect(EventRules.placesLeft(value), 3);
      expect(
        rsvp(value, const Rsvp(Attendance.going, guests: 2)).allowed,
        isTrue,
      );
      expect(
        rsvp(value, const Rsvp(Attendance.going, guests: 3)).reason,
        'Only 3 places left — you and up to 2 people with you.',
      );
      // Maybe never uses a place, whatever the guests.
      expect(
        rsvp(value, const Rsvp(Attendance.maybe, guests: 10)).allowed,
        isTrue,
      );
      // Changing your own answer doesn't count you twice.
      expect(
        rsvp(
          value,
          const Rsvp(Attendance.going, guests: 5),
          person: 'a',
        ).allowed,
        isTrue,
      );
      expect(
        rsvp(
          value,
          const Rsvp(Attendance.going, guests: 6),
          person: 'a',
        ).allowed,
        isFalse,
      );
      final full = event(
        capacity: 3,
        rsvps: const {'a': Rsvp(Attendance.going, guests: 2)},
      );
      expect(
        rsvp(full, going).reason,
        'This event is full. You can still answer Maybe.',
      );
      final one = event(capacity: 1);
      expect(
        rsvp(one, const Rsvp(Attendance.going, guests: 1)).reason,
        'Only 1 place left — just enough for you.',
      );
    });

    test('clearing needs an answer and follows the same timing', () {
      final answered = event(rsvps: const {'me': Rsvp(Attendance.maybe)});
      expect(
        EventRules.canClearRsvp(
          answered,
          'me',
          isMember: true,
          now: now,
        ).allowed,
        isTrue,
      );
      expect(
        EventRules.canClearRsvp(event(), 'me', isMember: true, now: now).reason,
        'You haven’t answered yet.',
      );
      final closed = event(
        deadline: now.add(const Duration(hours: 1)),
        rsvps: const {'me': Rsvp(Attendance.maybe)},
      );
      expect(
        EventRules.canClearRsvp(
          closed,
          'me',
          isMember: true,
          now: now.add(const Duration(hours: 2)),
        ).allowed,
        isFalse,
      );
    });

    test('attendance summary', () {
      final summary = EventRules.attendance(const {
        'a': Rsvp(Attendance.going, guests: 3),
        'b': Rsvp(Attendance.going, guests: 4),
        'c': Rsvp(Attendance.maybe, guests: 1),
        'd': Rsvp(Attendance.notGoing),
      });
      expect((summary.going, summary.maybe, summary.notGoing), (2, 1, 1));
      expect((summary.goingGuests, summary.maybeGuests), (7, 1));
      expect(summary.expected, 9);
      expect(EventRules.placesLeft(event()), isNull);
    });
  });

  group('event time helpers', () {
    test('zone labels are short', () {
      expect(zoneAbbreviation('IST'), 'IST');
      expect(zoneAbbreviation('India Standard Time'), 'IST');
      expect(zoneAbbreviation('+0530'), 'UTC+0530');
      expect(zoneAbbreviation(''), 'local time');
    });

    test('wall clock round-trips through UTC', () {
      final wall = DateTime.utc(2026, 10, 25, 12, 30);
      final instant = fromWallClock(wall, ist);
      expect(instant, DateTime.utc(2026, 10, 25, 7));
      expect(wallClock(instant, ist), wall);
    });

    test('times, months and durations', () {
      expect(formatTime(DateTime.utc(2026, 1, 1)), '12:00 AM');
      expect(formatTime(DateTime.utc(2026, 1, 1, 12, 5)), '12:05 PM');
      expect(formatTime(DateTime.utc(2026, 1, 1, 18, 30)), '6:30 PM');
      expect(formatMonth(DateTime.utc(2026, 10, 1)), 'October 2026');
      expect(formatMonthShort(DateTime.utc(2026, 10, 1)), 'OCT');
      expect(formatDuration(const Duration(minutes: 45)), '45 min');
      expect(formatDuration(const Duration(hours: 2)), '2 h');
      expect(
        formatDuration(const Duration(hours: 3, minutes: 30)),
        '3 h 30 min',
      );
      expect(formatDuration(const Duration(days: 2)), '2 days');
    });
  });
}
