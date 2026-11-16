import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/design.dart';
import 'package:mobile/core/design/circle_typography.dart';
import 'package:mobile/features/memories/application/home_filter.dart';
import 'package:mobile/features/memories/presentation/circle_memories.dart';
import 'screen_audit_visual_review_test.dart' show capture;
import 'support/circle_harness.dart';

void activateInkWell(WidgetTester tester, Finder target) {
  final control = find
      .ancestor(of: target, matching: find.byType(InkWell))
      .first;
  tester.widget<InkWell>(control).onTap!();
}

void main() {
  final now = DateTime(2026, 10, 15, 14, 30);

  testWidgets('Circle Pulse uses real workspace modules on a white canvas', (
    tester,
  ) async {
    await openCircle(tester, now: now);
    expect(find.text('All Circles'), findsOneWidget);
    expect(find.text('Create something'), findsOneWidget);
    expect(find.text('A Sunday well spent'), findsOneWidget);
    expect(find.text('Where should the reunion dinner be?'), findsOneWidget);
    expect(find.text('Your people are here'), findsOneWidget);
    expect(find.textContaining('online', findRichText: true), findsNothing);

    final home = find.byType(CircleHome);
    final canvas = tester.widget<ColoredBox>(
      find.descendant(of: home, matching: find.byType(ColoredBox)).first,
    );
    final pane = tester.widget<ReadingPane>(
      find.descendant(of: home, matching: find.byType(ReadingPane)).first,
    );
    expect(canvas.color, Colors.white);
    expect(pane.color, Colors.white);
    final greeting = tester.widget<Text>(find.text('Good afternoon'));
    expect(greeting.style?.fontWeight, FontWeight.w700);
    expect(CircleTextStyles.navLabel(Colors.black).fontWeight, FontWeight.w700);
    expect(tester.takeException(), isNull);
    await reveal(tester, find.text('Memories'));
    await capture(tester, 'home-pulse-modules', '393-1.0-light');
  });

  testWidgets('Circle selector filters Home and keeps compose in that Circle', (
    tester,
  ) async {
    final container = await openCircle(tester, now: now);
    activateInkWell(tester, find.text('The Sunday table'));
    await tester.pumpAndSettle();
    expect(container.read(homeGroupFilterProvider), 'family');
    expect(find.byTooltip('The Sunday table'), findsOneWidget);

    activateInkWell(tester, find.text('Share a memory…'));
    await tester.pumpAndSettle();
    expect(currentUri(container).path, '/compose');
    expect(currentUri(container).queryParameters['group'], 'family');
  });

  testWidgets('Pulse Event and Poll cards open their real destinations', (
    tester,
  ) async {
    final container = await openCircle(tester, now: now);
    activateInkWell(tester, find.text('A Sunday well spent'));
    await tester.pumpAndSettle();
    expect(currentUri(container).path, '/events/e/lunch');

    await go(tester, container, '/home');
    activateInkWell(tester, find.text('Where should the reunion dinner be?'));
    await tester.pumpAndSettle();
    expect(currentUri(container).path, '/home/memory/reunion-poll');
  });

  test('Home greetings use local time and a real first name', () {
    expect(
      homeGreeting(DateTime(2026, 10, 15, 8), 'Arjun Rao'),
      'Good morning, Arjun',
    );
    expect(homeGreeting(DateTime(2026, 10, 15, 14), ''), 'Good afternoon');
    expect(homeGreeting(DateTime(2026, 10, 15, 20), 'You'), 'Good evening');
  });
}
