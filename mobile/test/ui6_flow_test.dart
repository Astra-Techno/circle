import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/circle_harness.dart';

final fixed = DateTime.utc(2026, 10, 23, 12);

void main() {
  group('search', () {
    testWidgets('results grouped and scoped to your circles', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('search-field'));
      await tester.enterText(field, 's');
      await tester.pumpAndSettle();
      expect(find.text('Type at least 2 characters.'), findsOneWidget);
      await tester.enterText(field, 'sunday');
      await tester.pumpAndSettle();
      expect(find.text('Groups (2)'), findsOneWidget);
      // Chats are searched inside Chats; search covers circles.
      expect(find.textContaining('Messages ('), findsNothing);
      await tester.enterText(field, 'surprise');
      await tester.pumpAndSettle();
      expect(find.text('No results'), findsOneWidget);
      await tester.enterText(field, 'window-seat');
      await tester.pumpAndSettle();
      await tapText(tester, 'The window-seat crew');
      expect(currentUri(container).path, '/groups/g/friends');
    });
  });

  testWidgets('report a Memory to the group’s admins', (tester) async {
    final container = await openCircle(tester, now: fixed);
    await tester.tap(
      find.byTooltip('More options for Memory from Mira in The Sunday table'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(find.text('Report this Memory'), findsOneWidget);
    final send = find.widgetWithText(FilledButton, 'Send report');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.tap(find.text('Private information'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Add a note (optional)'),
      'Shows a home address.',
    );
    await tapText(tester, 'Send report');
    expect(
      find.text('Thanks — admins of this group will review it.'),
      findsOneWidget,
    );
    expect(workspaceOf(container).reportedByMe, contains('memory:table'));
  });

  testWidgets('You lists only what the server offers', (tester) async {
    final container = await openCircle(tester, now: fixed);
    await go(tester, container, '/you');
    for (final entry in ['Privacy and blocking', 'Invitations', 'Account']) {
      await reveal(tester, find.text(entry));
      expect(find.text(entry), findsOneWidget, reason: entry);
    }
    // Activity isn't on the server yet, so it is hidden, not a placeholder.
    expect(find.text('Activity'), findsNothing);
    await tapText(tester, 'Account');
    expect(find.text('Comes before launch'), findsNothing);
    await reveal(tester, find.text('Log out'));
    expect(find.text('Log out'), findsOneWidget);
    expect(find.textContaining('preview'), findsNothing);
  });

  testWidgets('features the server lacks are hidden, not placeholders', (
    tester,
  ) async {
    final container = await openCircle(tester, now: fixed);
    await go(tester, container, '/groups/g/club');
    expect(find.widgetWithText(Tab, 'Albums'), findsNothing);
    await go(tester, container, '/activity');
    expect(find.text('This page is unavailable'), findsOneWidget);
    expect(find.textContaining('on the server yet'), findsNothing);
  });

  group('tablet two-pane', () {
    for (final size in [const Size(900, 1100), const Size(1280, 800)]) {
      testWidgets('groups show detail beside the list at $size', (
        tester,
      ) async {
        final container = await openCircle(tester, now: fixed, size: size);
        await go(tester, container, '/groups');
        await tester.dragUntilVisible(
          find.text('Studio North'),
          find.byType(ListView).first,
          const Offset(0, -200),
        );
        await reveal(tester, find.text('Studio North'));
        await tester.tap(find.text('Studio North'));
        await tester.pumpAndSettle();
        expect(currentUri(container).path, '/groups');
        expect(find.byType(TabBar), findsOneWidget);
        // The list stays beside the detail: the name shows in both.
        expect(find.text('Studio North'), findsAtLeast(2));
        expect(tester.takeException(), isNull);
      });
    }
  });

  for (final route in ['/people/mira', '/search', '/you/account']) {
    testWidgets('$route has accessible labels and touch targets', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, route);
      final handle = tester.ensureSemantics();
      try {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });
  }

  for (final size in [
    const Size(360, 800),
    const Size(393, 852),
    const Size(900, 1100),
  ]) {
    testWidgets('screens support dark, 200% text at $size', (tester) async {
      final container = await openCircle(
        tester,
        now: fixed,
        size: size,
        scale: 2,
        brightness: Brightness.dark,
      );
      for (final route in [
        '/search',
        '/you/account',
        '/you',
        '/people/mira',
        '/people/tomas',
      ]) {
        await go(tester, container, route);
        expect(tester.takeException(), isNull, reason: route);
      }
      await go(tester, container, '/search');
      await tester.enterText(
        find.byKey(const ValueKey('search-field')),
        'mira',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'search results');
      await go(tester, container, '/home/memory/table');
      await tester.tap(
        find.byTooltip('More options for Memory from Mira in The Sunday table'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report').last);
      await tester.pumpAndSettle();
      expect(find.text('Report this Memory'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'report sheet');
    });
  }
}
