/// Event, RSVP and date-poll models (README §3.3). Pure Dart.
library;

import '../../memories/domain/memory_poll.dart';
import 'event_time.dart';

export 'event_calendar.dart';
export 'event_rules.dart';
export 'event_time.dart';

/// Labels and icons only; the type never changes what an event can do,
/// except that an online event needs a link instead of a venue.
enum EventType {
  familyFunction('Family function'),
  wedding('Wedding'),
  reunion('Reunion'),
  meetup('Meetup'),
  birthday('Birthday'),
  trip('Trip'),
  online('Online'),
  other('Other');

  const EventType(this.label);
  final String label;
}

enum Attendance {
  going('Going'),
  maybe('Maybe'),
  notGoing('Not going');

  const Attendance(this.label);
  final String label;

  /// Only Going and Maybe can bring people along.
  bool get allowsGuests => this != Attendance.notGoing;
}

/// One person's answer. [guests] are people coming with them.
class Rsvp {
  const Rsvp(this.status, {this.guests = 0, this.note});
  final Attendance status;
  final int guests;

  /// Optional short note ("Will arrive after lunch"); null when blank.
  final String? note;

  /// Everyone this answer brings: the person plus their guests.
  int get people => 1 + guests;

  /// An empty [note] clears it (blank notes are stored as null).
  Rsvp copyWith({Attendance? status, int? guests, String? note}) => Rsvp(
    status ?? this.status,
    guests: guests ?? this.guests,
    note: note ?? this.note,
  );

  @override
  bool operator ==(Object other) =>
      other is Rsvp &&
      other.status == status &&
      other.guests == guests &&
      other.note == note;

  @override
  int get hashCode => Object.hash(status, guests, note);
}

/// What the create/edit form collects. Only the group, title, date and
/// place (venue, or a link for online events) are required.
class EventDraft {
  const EventDraft({
    required this.groupId,
    required this.title,
    required this.startsAt,
    required this.timeZoneLabel,
    required this.utcOffset,
    this.type = EventType.other,
    this.venue,
    this.onlineLink,
    this.description,
    this.endsAt,
    this.rsvpDeadline,
    this.capacity,
    this.coHosts = const [],
    this.datePoll,
  });
  final String groupId, title, timeZoneLabel;
  final EventType type;

  /// Instants (UTC). [startsAt] is null until a date and time are chosen.
  final DateTime? startsAt, endsAt, rsvpDeadline;

  /// The planning zone's offset from UTC, used to show local times.
  final Duration utcOffset;
  final String? venue, onlineLink, description;

  /// Maximum people, counting guests. Null means no limit.
  final int? capacity;
  final List<String> coHosts;

  /// Only used when creating an event.
  final DatePollDraft? datePoll;
}

/// "Which date works?" — 2–6 date/time slots (instants, UTC).
class DatePollDraft {
  const DatePollDraft({required this.slots, this.multipleChoice = true});
  final List<DateTime> slots;
  final bool multipleChoice;
}

/// Counts for the attendee summary.
class EventAttendance {
  const EventAttendance({
    this.going = 0,
    this.maybe = 0,
    this.notGoing = 0,
    this.goingGuests = 0,
    this.maybeGuests = 0,
  });
  final int going, maybe, notGoing, goingGuests, maybeGuests;

  /// People expected: everyone going plus their guests. Maybe doesn't count.
  int get expected => going + goingGuests;
}

/// An event as one viewer sees it: RSVPs of current members of the exact
/// group, and the date poll projected for that viewer.
class CircleEvent {
  CircleEvent({
    required this.id,
    required this.groupId,
    required this.createdBy,
    required List<String> hosts,
    required this.type,
    required this.title,
    required this.startsAt,
    required this.timeZoneLabel,
    required this.utcOffset,
    required this.createdAt,
    this.description,
    this.endsAt,
    this.venue,
    this.onlineLink,
    this.rsvpDeadline,
    this.capacity,
    this.cancelledAt,
    this.editedAt,
    this.datePollId,
    this.datePoll,
    Map<String, Rsvp> rsvps = const {},
  }) : hosts = List.unmodifiable(hosts),
       rsvps = Map.unmodifiable(rsvps);

  final String id, groupId, createdBy, title, timeZoneLabel;

  /// The creator first, then co-hosts.
  final List<String> hosts;
  final EventType type;
  final DateTime startsAt, createdAt;
  final DateTime? endsAt, rsvpDeadline, cancelledAt, editedAt;
  final Duration utcOffset;
  final String? description, venue, onlineLink;
  final int? capacity;
  final String? datePollId;
  final PollView? datePoll;

  /// Person → answer.
  final Map<String, Rsvp> rsvps;

  bool get cancelled => cancelledAt != null;
  bool get edited => editedAt != null;

  /// Wall-clock start and end in the event's own zone.
  DateTime get localStart => wallClock(startsAt, utcOffset);
  DateTime? get localEnd =>
      endsAt == null ? null : wallClock(endsAt!, utcOffset);

  /// When the event is over: its end, or its start when it has none.
  DateTime get endsOrStarts => endsAt ?? startsAt;

  Rsvp? rsvpOf(String person) => rsvps[person];

  CircleEvent copyWith({
    List<String>? hosts,
    EventType? type,
    String? title,
    DateTime? startsAt,
    DateTime? endsAt,
    String? description,
    String? venue,
    String? onlineLink,
    DateTime? rsvpDeadline,
    int? capacity,
    DateTime? cancelledAt,
    DateTime? editedAt,
    Map<String, Rsvp>? rsvps,
    PollView? datePoll,
    bool clearOptional = false,
  }) => CircleEvent(
    id: id,
    groupId: groupId,
    createdBy: createdBy,
    hosts: hosts ?? this.hosts,
    type: type ?? this.type,
    title: title ?? this.title,
    startsAt: startsAt ?? this.startsAt,
    timeZoneLabel: timeZoneLabel,
    utcOffset: utcOffset,
    createdAt: createdAt,
    // Edits replace every optional field, so blanks really clear them.
    description: clearOptional ? description : description ?? this.description,
    endsAt: clearOptional ? endsAt : endsAt ?? this.endsAt,
    venue: clearOptional ? venue : venue ?? this.venue,
    onlineLink: clearOptional ? onlineLink : onlineLink ?? this.onlineLink,
    rsvpDeadline: clearOptional
        ? rsvpDeadline
        : rsvpDeadline ?? this.rsvpDeadline,
    capacity: clearOptional ? capacity : capacity ?? this.capacity,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    editedAt: editedAt ?? this.editedAt,
    datePollId: datePollId,
    datePoll: datePoll ?? this.datePoll,
    rsvps: rsvps ?? this.rsvps,
  );
}
