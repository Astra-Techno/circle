/// Small, dependency-free date helpers for events. Pure Dart.
///
/// Events store instants in UTC plus the time zone they were planned in
/// (its short label and UTC offset). A "wall clock" value is a UTC-flagged
/// [DateTime] whose fields are the local date and time in that zone, so
/// formatting never depends on the device's current zone.
library;

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _monthsLong = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// The wall-clock fields of [instant] in a zone [offset] from UTC.
DateTime wallClock(DateTime instant, Duration offset) =>
    instant.toUtc().add(offset);

/// The UTC instant for wall-clock fields [wall] in a zone [offset] from UTC.
DateTime fromWallClock(DateTime wall, Duration offset) => DateTime.utc(
  wall.year,
  wall.month,
  wall.day,
  wall.hour,
  wall.minute,
).subtract(offset);

/// A short zone label: "IST" stays "IST"; long names such as "India
/// Standard Time" become their initials. Offsets ("+0530") get a "UTC"
/// prefix so they still read as a zone.
String zoneAbbreviation(String name) {
  final value = name.trim();
  if (value.isEmpty) return 'local time';
  if (!value.contains(' ')) {
    return RegExp(r'^[+-]\d').hasMatch(value) ? 'UTC$value' : value;
  }
  return value
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase())
      .join();
}

/// "Sat 25 Oct", with the year added when it differs from [today]'s.
String formatDay(DateTime wall, {DateTime? today}) {
  final base =
      '${_weekdays[wall.weekday - 1]} ${wall.day} ${_monthsShort[wall.month - 1]}';
  return today != null && today.year != wall.year ? '$base ${wall.year}' : base;
}

/// "12:30 PM".
String formatTime(DateTime wall) {
  final hour = wall.hour % 12 == 0 ? 12 : wall.hour % 12;
  final minute = wall.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${wall.hour < 12 ? 'AM' : 'PM'}';
}

/// "October 2026".
String formatMonth(DateTime wall) =>
    '${_monthsLong[wall.month - 1]} ${wall.year}';

/// "OCT", for the date block on event cards.
String formatMonthShort(DateTime wall) =>
    _monthsShort[wall.month - 1].toUpperCase();

/// "45 min", "2 h", "2 h 30 min", "3 days".
String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) return '$minutes min';
  if (duration.inHours >= 24 && minutes % (24 * 60) == 0) {
    final days = duration.inDays;
    return '$days ${days == 1 ? 'day' : 'days'}';
  }
  if (duration.inHours >= 48) return '${duration.inDays} days';
  final rest = minutes % 60;
  return rest == 0
      ? '${duration.inHours} h'
      : '${duration.inHours} h $rest min';
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
