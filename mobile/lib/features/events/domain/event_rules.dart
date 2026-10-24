import '../../../core/rule_result.dart';
import '../../memories/domain/memory_poll.dart';
import 'circle_event.dart';

/// Form fields a validation message belongs to.
enum EventField {
  title,
  start,
  end,
  venue,
  onlineLink,
  description,
  deadline,
  capacity,
  coHosts,
  datePoll,
}

class EventIssue {
  const EventIssue(this.field, this.message);
  final EventField field;
  final String message;
}

const _ok = RuleResult.allowed();
const _notShared = RuleResult.denied('This group is not shared with you.');

/// Pure event and RSVP rules (README §3.3). The repository and the UI both
/// use them; membership is always of the event's exact group. Who may
/// create events lives in `MembershipRules.canCreateEvent`, next to the
/// group setting it reads.
abstract final class EventRules {
  static const maxTitle = 100, maxDescription = 2000, maxVenue = 120;
  static const maxLink = 300, maxNote = 140, maxGuests = 20;
  static const maxCapacity = 10000, maxCoHosts = 10;
  static const minDateSlots = 2, maxDateSlots = 6;
  static const datePollQuestion = 'Which date works for you?';

  /// Trimmed text, or null when blank.
  static String? clean(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Every problem with [draft], in form order. [originalStart] is the
  /// saved start when editing; keeping it unchanged is always fine.
  ///
  /// Online events need a link (a venue is optional); every other type
  /// needs a venue (a link is optional, for hybrid plans).
  static List<EventIssue> validate(
    EventDraft draft, {
    required DateTime now,
    DateTime? originalStart,
  }) {
    final issues = <EventIssue>[];
    void add(EventField field, String message) =>
        issues.add(EventIssue(field, message));

    final title = draft.title.trim();
    if (title.isEmpty) {
      add(EventField.title, 'Give your event a title.');
    } else if (title.runes.length > maxTitle) {
      add(EventField.title, 'Keep the title to $maxTitle characters.');
    }

    final start = draft.startsAt;
    if (start == null) {
      add(EventField.start, 'Choose a date and a start time.');
    } else if (start != originalStart && !start.isAfter(now)) {
      add(EventField.start, 'Choose a start time that hasn’t passed yet.');
    }

    final end = draft.endsAt;
    if (start != null && end != null && !end.isAfter(start)) {
      add(EventField.end, 'The end needs to be after the start.');
    }

    final venue = clean(draft.venue);
    final link = clean(draft.onlineLink);
    if (venue != null && venue.runes.length > maxVenue) {
      add(EventField.venue, 'Keep the place to $maxVenue characters.');
    } else if (venue == null && draft.type != EventType.online) {
      add(EventField.venue, 'Add a place, like a home, a hall or a park.');
    }
    if (link != null && link.runes.length > maxLink) {
      add(EventField.onlineLink, 'Keep the link to $maxLink characters.');
    } else if (link != null && link.contains(RegExp(r'\s'))) {
      add(EventField.onlineLink, 'Links can’t contain spaces.');
    } else if (link == null && draft.type == EventType.online) {
      add(EventField.onlineLink, 'Add the link people will use to join.');
    }

    if ((clean(draft.description)?.runes.length ?? 0) > maxDescription) {
      add(
        EventField.description,
        'Keep the description to $maxDescription characters.',
      );
    }

    final deadline = draft.rsvpDeadline;
    if (deadline != null) {
      if (!deadline.isAfter(now)) {
        add(
          EventField.deadline,
          'Choose an RSVP deadline that hasn’t passed yet.',
        );
      } else if (start != null && deadline.isAfter(start)) {
        add(
          EventField.deadline,
          'The RSVP deadline needs to be on or before the start.',
        );
      }
    }

    final capacity = draft.capacity;
    if (capacity != null && (capacity < 1 || capacity > maxCapacity)) {
      add(
        EventField.capacity,
        'Capacity needs to be from 1 to $maxCapacity people.',
      );
    }

    if (draft.coHosts.length > maxCoHosts) {
      add(EventField.coHosts, 'Choose up to $maxCoHosts co-hosts.');
    }

    final poll = draft.datePoll;
    if (poll != null) {
      final check = checkDateSlots(poll.slots, now: now);
      if (!check.allowed) add(EventField.datePoll, check.reason!);
    }
    return issues;
  }

  static RuleResult checkDraft(
    EventDraft draft, {
    required DateTime now,
    DateTime? originalStart,
  }) {
    final issues = validate(draft, now: now, originalStart: originalStart);
    return issues.isEmpty ? _ok : RuleResult.denied(issues.first.message);
  }

  // ------------------------------------------------------------ date polls

  /// 2–6 different future slots (compared to the minute).
  static RuleResult checkDateSlots(
    List<DateTime> slots, {
    required DateTime now,
  }) {
    if (slots.length < minDateSlots || slots.length > maxDateSlots) {
      return const RuleResult.denied(
        'Give $minDateSlots–$maxDateSlots date options.',
      );
    }
    if (slots.any((slot) => !slot.isAfter(now))) {
      return const RuleResult.denied('Choose date options in the future.');
    }
    final unique = {
      for (final slot in slots)
        slot.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute,
    };
    if (unique.length != slots.length) {
      return const RuleResult.denied('Each date option needs to be different.');
    }
    return _ok;
  }

  /// "Sat 25 Oct · 6:00 PM IST", in the event's own zone.
  static String slotLabel(
    DateTime slot, {
    required Duration offset,
    required String zone,
    DateTime? today,
  }) {
    final wall = wallClock(slot, offset);
    return '${formatDay(wall, today: today)} · ${formatTime(wall)} $zone';
  }

  /// The poll for a date poll: named votes, results always visible (people
  /// pick dates together), votes can change, no end date; the slots sorted
  /// in time. The UI-3 [PollRules] still check the result.
  static PollDraft datePollDraft(
    DatePollDraft draft, {
    required Duration offset,
    required String zone,
    DateTime? today,
  }) {
    final slots = [...draft.slots]..sort();
    return PollDraft(
      question: datePollQuestion,
      options: [
        for (final slot in slots)
          slotLabel(slot, offset: offset, zone: zone, today: today),
      ],
      multipleChoice: draft.multipleChoice,
      resultsVisibility: PollResultsVisibility.always,
    );
  }

  // ------------------------------------------------------------- timing

  static bool hasStarted(CircleEvent event, DateTime now) =>
      !now.isBefore(event.startsAt);

  /// Over once its end (or, without one, its start) has passed.
  static bool hasEnded(CircleEvent event, DateTime now) =>
      !now.isBefore(event.endsOrStarts);

  /// Upcoming until it ends, including cancelled ones (shown as cancelled).
  static bool isUpcoming(CircleEvent event, DateTime now) =>
      !hasEnded(event, now);

  // -------------------------------------------------------- permissions

  static bool isHost(CircleEvent event, String person) =>
      event.hosts.contains(person);

  /// Hosts and the group's owner/admins may edit or cancel, until the
  /// event is cancelled or over.
  static RuleResult canManage(
    CircleEvent event,
    String actor, {
    required bool isMember,
    required bool isAdmin,
    required DateTime now,
  }) {
    if (!isMember) return _notShared;
    if (!isHost(event, actor) && !isAdmin) {
      return const RuleResult.denied(
        'Only the hosts or a group admin can change this event.',
      );
    }
    if (event.cancelled) {
      return const RuleResult.denied('This event was cancelled.');
    }
    if (hasEnded(event, now)) {
      return const RuleResult.denied('This event has ended.');
    }
    return _ok;
  }

  /// Whether anyone may answer now: not cancelled, not started, and not
  /// after the RSVP deadline.
  static RuleResult canRespond(
    CircleEvent event, {
    required bool isMember,
    required DateTime now,
  }) {
    if (!isMember) return _notShared;
    if (event.cancelled) {
      return const RuleResult.denied(
        'This event was cancelled, so RSVPs are closed.',
      );
    }
    if (hasEnded(event, now)) {
      return const RuleResult.denied('This event has ended.');
    }
    if (hasStarted(event, now)) {
      return const RuleResult.denied(
        'This event has started, so RSVPs are closed.',
      );
    }
    final deadline = event.rsvpDeadline;
    if (deadline != null && !now.isBefore(deadline)) {
      return const RuleResult.denied('The RSVP deadline has passed.');
    }
    return _ok;
  }

  /// Sets or changes [person]'s answer. Capacity counts everyone going plus
  /// their guests; Maybe and Not going never use a place.
  static RuleResult canRsvp(
    CircleEvent event,
    String person,
    Rsvp rsvp, {
    required bool isMember,
    required DateTime now,
  }) {
    final open = canRespond(event, isMember: isMember, now: now);
    if (!open.allowed) return open;
    if (rsvp.guests < 0 || rsvp.guests > maxGuests) {
      return const RuleResult.denied(
        'You can bring 0–$maxGuests people with you.',
      );
    }
    if (!rsvp.status.allowsGuests && rsvp.guests > 0) {
      return const RuleResult.denied(
        'People coming with you are only for Going or Maybe.',
      );
    }
    if ((clean(rsvp.note)?.runes.length ?? 0) > maxNote) {
      return const RuleResult.denied('Keep the note to $maxNote characters.');
    }
    final capacity = event.capacity;
    if (capacity != null && rsvp.status == Attendance.going) {
      final left = capacity - expectedExcept(event, person);
      if (left <= 0) {
        return const RuleResult.denied(
          'This event is full. You can still answer Maybe.',
        );
      }
      if (rsvp.people > left) {
        return RuleResult.denied(
          left == 1
              ? 'Only 1 place left — just enough for you.'
              : 'Only $left places left — you and up to ${left - 1} '
                    '${left - 1 == 1 ? 'person' : 'people'} with you.',
        );
      }
    }
    return _ok;
  }

  /// Taking an answer back follows the same timing as answering.
  static RuleResult canClearRsvp(
    CircleEvent event,
    String person, {
    required bool isMember,
    required DateTime now,
  }) {
    final open = canRespond(event, isMember: isMember, now: now);
    if (!open.allowed) return open;
    if (!event.rsvps.containsKey(person)) {
      return const RuleResult.denied('You haven’t answered yet.');
    }
    return _ok;
  }

  // ------------------------------------------------------------ counts

  static EventAttendance attendance(Map<String, Rsvp> rsvps) {
    var going = 0, maybe = 0, notGoing = 0, goingGuests = 0, maybeGuests = 0;
    for (final rsvp in rsvps.values) {
      switch (rsvp.status) {
        case Attendance.going:
          going++;
          goingGuests += rsvp.guests;
        case Attendance.maybe:
          maybe++;
          maybeGuests += rsvp.guests;
        case Attendance.notGoing:
          notGoing++;
      }
    }
    return EventAttendance(
      going: going,
      maybe: maybe,
      notGoing: notGoing,
      goingGuests: goingGuests,
      maybeGuests: maybeGuests,
    );
  }

  /// People expected, leaving out [person]'s own answer.
  static int expectedExcept(CircleEvent event, String person) => attendance({
    for (final entry in event.rsvps.entries)
      if (entry.key != person) entry.key: entry.value,
  }).expected;

  /// Places still free, or null without a capacity.
  static int? placesLeft(CircleEvent event) {
    final capacity = event.capacity;
    if (capacity == null) return null;
    final left = capacity - attendance(event.rsvps).expected;
    return left < 0 ? 0 : left;
  }
}
