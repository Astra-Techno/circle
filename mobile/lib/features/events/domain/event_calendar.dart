/// Pure month-calendar helpers for the Events tab (E1). Pure Dart.
///
/// Every value is a *date only*: a UTC-flagged [DateTime] at midnight.
/// Arithmetic happens in UTC, where every day has 24 hours, so daylight
/// saving changes can never skip or repeat a day. Weeks start on Monday,
/// and labels are simple English names (no locale data needed).
library;

import 'circle_event.dart';

const _weekdaysLong = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', //
  'Saturday', 'Sunday',
];
const _weekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthsLong = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

abstract final class EventCalendar {
  /// Column headers, Monday first.
  static const weekdayLabels = _weekdaysShort;

  /// Spoken column headers, Monday first.
  static const weekdayNames = _weekdaysLong;

  /// The date of [value]'s own fields (whatever its zone flag), as a
  /// UTC midnight.
  static DateTime dateOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  /// The first day of [value]'s month.
  static DateTime monthOf(DateTime value) =>
      DateTime.utc(value.year, value.month);

  /// The first day of the month [delta] months after [month]'s.
  static DateTime addMonths(DateTime month, int delta) =>
      DateTime.utc(month.year, month.month + delta);

  static bool isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  static int daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  /// Whole weeks (Monday–Sunday) covering [month]: 4 to 6 rows of 7 days,
  /// including the leading and trailing days of the neighbouring months.
  static List<DateTime> monthGrid(DateTime month) {
    final first = monthOf(month);
    // DateTime.weekday: Monday = 1 … Sunday = 7.
    final lead = first.weekday - 1;
    final days = daysInMonth(first.year, first.month);
    final cells = ((lead + days) / 7).ceil() * 7;
    return [
      for (var i = 0; i < cells; i++)
        DateTime.utc(first.year, first.month, 1 - lead + i),
    ];
  }

  /// [days] split into weeks of 7.
  static List<List<DateTime>> weeks(List<DateTime> days) => [
    for (var i = 0; i < days.length; i += 7) days.sublist(i, i + 7),
  ];

  /// Events by the date they start, in the zone they were planned in
  /// (the same date their cards show). Each list keeps [events]' order.
  static Map<DateTime, List<CircleEvent>> byDay(Iterable<CircleEvent> events) {
    final result = <DateTime, List<CircleEvent>>{};
    for (final event in events) {
      (result[dateOnly(event.localStart)] ??= []).add(event);
    }
    return result;
  }

  /// "October 2026".
  static String monthLabel(DateTime month) =>
      '${_monthsLong[month.month - 1]} ${month.year}';

  /// "Sunday 25 October".
  static String dayTitle(DateTime day) =>
      '${_weekdaysLong[day.weekday - 1]} ${day.day} '
      '${_monthsLong[day.month - 1]}';

  /// What a screen reader hears for one day: "Sunday 25 October, today,
  /// 2 events" or "Monday 26 October, no events".
  static String daySemantics(
    DateTime day, {
    required int events,
    bool today = false,
  }) => [
    dayTitle(day),
    if (today) 'today',
    switch (events) {
      0 => 'no events',
      1 => '1 event',
      _ => '$events events',
    },
  ].join(', ');
}
