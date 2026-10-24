import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/circle_harness.dart';

/// 9 AM local time on Friday 23 October 2026. Seeds are relative to it.
final now = DateTime(2026, 10, 23, 9);

Future<void> pickDate(WidgetTester tester, String button, String day) async {
  await tapText(tester, button);
  await tester.tap(find.text(day).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

/// Accepts the time picker's initial time (6:00 PM for a new start).
Future<void> acceptTime(WidgetTester tester) async {
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> enterField(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextField, label);
  await reveal(tester, field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> tapChip(WidgetTester tester, String label) async {
  final target = find.widgetWithText(ChoiceChip, label);
  await reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

ChoiceChip chip(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

void main() {
  testWidgets(
    'create an event with only the required fields from a group tab',
    (tester) async {
      final container = await openCircle(tester, now: now);
      await go(tester, container, '/groups/g/family');
      await openTab(tester, 'Events');
      await tapText(tester, 'Create event');
      expect(currentUri(container).toString(), '/events/new?group=family');
      // The group comes from context; it is shown, not guessed.
      expect(find.text('The Sunday table'), findsOneWidget);
      await enterField(tester, 'Title', 'Diwali lunch');
      await pickDate(tester, 'Choose date', '28');
      await tapText(tester, 'Start time');
      await acceptTime(tester);
      await enterField(tester, 'Place', 'Grandma’s house');
      await tapText(tester, 'Create event');
      final event = workspaceOf(
        container,
      ).events.firstWhere((event) => event.title == 'Diwali lunch');
      expect(currentUri(container).path, '/events/e/${event.id}');
      expect(event.groupId, 'family');
      expect(event.hosts, ['you']);
      expect(event.startsAt, DateTime(2026, 10, 28, 18).toUtc());
      expect(event.venue, 'Grandma’s house');
      expect(find.text('Event created.'), findsOneWidget);
      expect(find.text('Diwali lunch'), findsWidgets);

      await go(tester, container, '/events');
      await reveal(tester, find.text('Diwali lunch'));
      expect(find.text('Diwali lunch'), findsOneWidget);
      await go(tester, container, '/groups/g/family');
      await openTab(tester, 'Events');
      await reveal(tester, find.text('Diwali lunch'));
      // Cards in the group tab open the event.
      await tester.tap(find.text('Diwali lunch'));
      await tester.pumpAndSettle();
      expect(currentUri(container).path, '/events/e/${event.id}');
    },
  );

  testWidgets('validation is calm and specific; no silent group default', (
    tester,
  ) async {
    final container = await openCircle(tester, now: now);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Events'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New event'));
    await tester.pumpAndSettle();
    expect(currentUri(container).toString(), '/events/new');
    expect(find.text('Choose a group'), findsOneWidget);
    final before = workspaceOf(container).events.length;
    await tapText(tester, 'Create event');
    expect(find.text('Choose which group this event is for.'), findsOneWidget);
    expect(find.text('Give your event a title.'), findsOneWidget);
    expect(find.text('Choose a date and a start time.'), findsOneWidget);
    expect(
      find.text('Add a place, like a home, a hall or a park.'),
      findsOneWidget,
    );
    expect(workspaceOf(container).events, hasLength(before));
    // Online events ask for a link instead of a place.
    await tapChip(tester, 'Online');
    await tapText(tester, 'Create event');
    expect(find.text('Add the link people will use to join.'), findsOneWidget);
    // Groups limited to admins are not offered.
    final picker = find.byType(DropdownButtonFormField<String>);
    await reveal(tester, picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(find.text('Studio North'), findsNothing);
    expect(find.text('Sunday miles'), findsWidgets);
  });

  testWidgets('More options: end, details, capacity, co-host and a date poll', (
    tester,
  ) async {
    final container = await openCircle(tester, now: now);
    await go(tester, container, '/events/new?group=club');
    await enterField(tester, 'Title', 'Hill ride');
    await tapChip(tester, 'Trip');
    await pickDate(tester, 'Choose date', '30');
    await tapText(tester, 'Start time');
    await acceptTime(tester);
    await enterField(tester, 'Place', 'Old bridge · Fictional venue');
    await tapText(tester, 'More options');
    await enterField(
      tester,
      'Description (optional)',
      'Slow pace, long lunch.',
    );
    await enterField(tester, 'Capacity (optional)', '12');
    await tapText(tester, 'Mira');
    await tapText(tester, 'Not sure of the date? Ask with a date poll');
    await pickDate(tester, 'Add a date option', '29');
    await acceptTime(tester);
    // One option is not enough.
    await tapText(tester, 'Create event');
    expect(find.text('Give 2–6 date options.'), findsOneWidget);
    // The next option starts a week later, in November.
    await pickDate(tester, 'Add a date option', '6');
    await acceptTime(tester);
    await tapText(tester, 'Create event');
    final event = workspaceOf(
      container,
    ).events.firstWhere((event) => event.title == 'Hill ride');
    expect(event.type, EventType.trip);
    expect(event.capacity, 12);
    expect(event.description, 'Slow pace, long lunch.');
    expect(event.hosts, ['you', 'mira']);
    expect(event.datePoll!.options, hasLength(2));
    expect(event.datePoll!.multipleChoice, isTrue);
    expect(currentUri(container).path, '/events/e/${event.id}');
    await reveal(tester, find.text('Which date works for you?'));
    expect(find.text('Date poll'), findsOneWidget);
  });

  testWidgets('RSVP going with guests and a note saves instantly, with Undo', (
    tester,
  ) async {
    final container = await openCircle(tester, now: now);
    await go(tester, container, '/events/e/lunch');
    Rsvp? mine() => workspaceOf(container).event('lunch')!.rsvpOf('you');
    expect(find.text('Going 2 · Maybe 1 · Not going 0'), findsOneWidget);
    expect(find.text('9 people expected, including guests'), findsOneWidget);
    await tapText(tester, 'Going');
    expect(mine(), const Rsvp(Attendance.going));
    expect(find.text('Saved.'), findsOneWidget);
    expect(find.text('People coming with you'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await reveal(tester, find.byTooltip('One person more'));
      await tester.tap(find.byTooltip('One person more'));
      await tester.pumpAndSettle();
    }
    expect(mine()!.guests, 2);
    expect(find.text('12 people expected, including guests'), findsOneWidget);
    await tapText(tester, 'Add a note');
    await tester.enterText(
      find.widgetWithText(TextField, 'Note for the hosts (optional)'),
      'Arriving after the temple',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(mine()!.note, 'Arriving after the temple');
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(mine(), const Rsvp(Attendance.going, guests: 2));
    // Not going drops the people coming along.
    await tapText(tester, 'Not going');
    expect(mine(), const Rsvp(Attendance.notGoing));
    expect(find.text('People coming with you'), findsNothing);
    await tapText(tester, 'Clear my answer');
    expect(mine(), isNull);
  });

  testWidgets('a full event says so calmly; Maybe still works', (tester) async {
    final container = await openCircle(tester, now: now);
    await go(tester, container, '/events/e/workshop');
    expect(find.text('Full — you can still answer Maybe.'), findsOneWidget);
    await tapText(tester, 'Going');
    expect(
      find.text('This event is full. You can still answer Maybe.'),
      findsOneWidget,
    );
    expect(workspaceOf(container).event('workshop')!.rsvpOf('you'), isNull);
    // Members who aren't hosts get no edit/cancel menu.
    expect(find.byTooltip('Event options'), findsNothing);
    await tapText(tester, 'Maybe');
    expect(
      workspaceOf(container).event('workshop')!.rsvpOf('you')!.status,
      Attendance.maybe,
    );
  });

  testWidgets('hosts edit (marked Edited) and cancel with confirmation', (
    tester,
  ) async {
    final container = await openCircle(tester, now: now);
    await go(tester, container, '/events/e/cycling');
    await tester.tap(find.byTooltip('Event options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit event'));
    await tester.pumpAndSettle();
    expect(currentUri(container).path, '/events/e/cycling/edit');
    await enterField(tester, 'Title', 'Take the longer way home');
    await tapText(tester, 'Save changes');
    expect(currentUri(container).path, '/events/e/cycling');
    expect(find.text('Take the longer way home'), findsOneWidget);
    expect(find.text('Edited'), findsOneWidget);

    await tester.tap(find.byTooltip('Event options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel event'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this event?'), findsOneWidget);
    await tester.tap(find.text('Keep event'));
    await tester.pumpAndSettle();
    expect(workspaceOf(container).event('cycling')!.cancelled, isFalse);
    await tester.tap(find.byTooltip('Event options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel event'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel event'));
    await tester.pumpAndSettle();
    expect(workspaceOf(container).event('cycling')!.cancelled, isTrue);
    expect(
      find.text('This event was cancelled. RSVPs are closed.'),
      findsOneWidget,
    );
    expect(find.text('Cancelled'), findsOneWidget);
    expect(chip(tester, 'Going').onSelected, isNull);
    expect(find.byTooltip('Event options'), findsNothing);
  });

  testWidgets('past events: RSVP disabled and labelled as ended', (
    tester,
  ) async {
    final container = await openCircle(tester, now: now);
    await go(tester, container, '/events/e/picnic');
    expect(find.text('This event has ended.'), findsOneWidget);
    for (final label in ['Going', 'Maybe', 'Not going']) {
      expect(chip(tester, label).onSelected, isNull, reason: label);
    }
    expect(chip(tester, 'Going').selected, isTrue);
    expect(find.text('Clear my answer'), findsNothing);
    expect(find.byTooltip('One person more'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
          .onPressed,
      isNull,
    );
    expect(find.byTooltip('Event options'), findsNothing);
  });

  testWidgets('deep links open event pages straight from another tab', (
    tester,
  ) async {
    final container = await openCircle(tester, now: now);
    for (final route in [
      '/events/e/lunch/attendees',
      '/events/e/cycling/edit',
      '/events/new?group=club',
    ]) {
      await go(tester, container, '/home');
      await go(tester, container, route);
      expect(tester.takeException(), isNull, reason: route);
      expect(currentUri(container).toString(), route);
    }
  });

  testWidgets('attendees in Going, Maybe and Not going tabs', (tester) async {
    final container = await openCircle(tester, now: now);
    await go(tester, container, '/events/e/lunch');
    await tapText(tester, 'See attendees');
    expect(currentUri(container).path, '/events/e/lunch/attendees');
    expect(find.text('Going (2)'), findsOneWidget);
    expect(find.text('Mira'), findsOneWidget);
    expect(
      find.text('+3 people with them · “Bringing the kids”'),
      findsOneWidget,
    );
    expect(find.text('Priya'), findsOneWidget);
    await tester.tap(find.text('Maybe (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Dev'), findsOneWidget);
    expect(find.text('+1 person with them'), findsOneWidget);
    await tester.tap(find.text('Not going (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Nobody has said Not going yet.'), findsOneWidget);
  });

  testWidgets('copy the place and the online link; no fake map links', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final container = await openCircle(tester, now: now);
    await go(tester, container, '/events/e/catch-up');
    await tester.tap(find.byTooltip('Copy link'));
    await tester.pumpAndSettle();
    expect(copied, ['meet.example.invalid/cse-catch-up']);
    expect(find.text('Link copied.'), findsOneWidget);
    expect(find.textContaining('maps'), findsNothing);
    expect(find.textContaining('calendar'), findsNothing);
    await go(tester, container, '/events/e/lunch');
    await tester.tap(find.byTooltip('Copy place'));
    await tester.pumpAndSettle();
    expect(copied.last, 'The family table · Fictional venue');
  });

  testWidgets('Events: Upcoming/Past, month headers and group filters', (
    tester,
  ) async {
    await openCircle(tester, now: now);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Events'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('A Sunday well spent'), findsOneWidget);
    expect(find.text('Autumn picnic'), findsNothing);
    expect(find.text('Surprise party'), findsNothing);
    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    expect(find.text('Autumn picnic'), findsOneWidget);
    expect(find.text('A Sunday well spent'), findsNothing);
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();
    await reveal(tester, find.widgetWithText(ChoiceChip, 'Sunday miles'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sunday miles'));
    await tester.pumpAndSettle();
    expect(find.text('Take the long way home'), findsOneWidget);
    expect(find.text('A Sunday well spent'), findsNothing);
    await reveal(tester, find.widgetWithText(ChoiceChip, 'Studio North'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Studio North'));
    await tester.pumpAndSettle();
    expect(find.text('Pottery afternoon'), findsOneWidget);
    expect(
      find.text('Only admins can create events in Studio North.'),
      findsOneWidget,
    );
    // The filter is context for "New event" when allowed there.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sunday miles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New event'));
    await tester.pumpAndSettle();
    expect(find.text('Sunday miles'), findsOneWidget);
  });

  testWidgets('admins-only event creation hides Create for members', (
    tester,
  ) async {
    final container = await openCircle(tester, now: now);
    await go(tester, container, '/groups/g/work');
    await openTab(tester, 'Events');
    expect(find.text('Create event'), findsNothing);
    expect(
      find.text('Only admins can create events in Studio North.'),
      findsOneWidget,
    );
    await go(tester, container, '/events/new?group=work');
    expect(find.text('Choose a group'), findsOneWidget);

    // The owner limits The Sunday table to admins, with Undo.
    await go(tester, container, '/groups/g/family/settings');
    await reveal(tester, find.text('Everyone'));
    await tester.tap(find.text('Everyone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admins only').last);
    await tester.pumpAndSettle();
    expect(
      workspaceOf(container).group('family')!.settings.eventCreation,
      EventCreationPolicy.admins,
    );
    expect(find.text('Only admins can now create events.'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      workspaceOf(container).group('family')!.settings.eventCreation,
      EventCreationPolicy.members,
    );
    // Members see the setting read-only.
    await go(tester, container, '/groups/g/cse/settings');
    await reveal(tester, find.text('Who can create events'));
    final field = tester.widget<DropdownButtonFormField<EventCreationPolicy>>(
      find.byType(DropdownButtonFormField<EventCreationPolicy>),
    );
    expect(field.onChanged, isNull);
  });

  testWidgets('event pages have accessible labels and touch targets', (
    tester,
  ) async {
    final container = await openCircle(tester, now: now);
    for (final route in ['/events', '/events/e/lunch']) {
      await go(tester, container, route);
      final handle = tester.ensureSemantics();
      try {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    }
  });

  for (final size in [
    const Size(360, 800),
    const Size(393, 852),
    const Size(900, 1100),
  ]) {
    testWidgets('event screens support dark, 200% text at $size', (
      tester,
    ) async {
      final container = await openCircle(
        tester,
        size: size,
        scale: 2,
        brightness: Brightness.dark,
        now: now,
      );
      for (final route in [
        '/events',
        '/events/new',
        '/events/new?group=family',
        '/events/e/lunch',
        '/events/e/reunion',
        '/events/e/catch-up',
        '/events/e/workshop',
        '/events/e/picnic',
        '/events/e/surprise',
        '/events/e/lunch/attendees',
        '/events/e/cycling/edit',
        '/groups/g/work',
      ]) {
        await go(tester, container, route);
        expect(tester.takeException(), isNull, reason: route);
      }
      await go(tester, container, '/events');
      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'past');
      await go(tester, container, '/events/new?group=family');
      await tapText(tester, 'More options');
      await tapText(tester, 'Not sure of the date? Ask with a date poll');
      await tapText(tester, 'Create event');
      expect(tester.takeException(), isNull, reason: 'form errors');
      await go(tester, container, '/events/e/lunch');
      await tapText(tester, 'Going');
      await tapText(tester, 'Add a note');
      expect(tester.takeException(), isNull, reason: 'rsvp');
      await go(tester, container, '/groups/g/family');
      await openTab(tester, 'Events');
      expect(tester.takeException(), isNull, reason: 'group tab');
    });
  }
}
