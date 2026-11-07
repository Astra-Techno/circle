import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/theme_controller.dart';
import 'package:mobile/features/events/presentation/live_events.dart';
import 'live_chat_events_test.dart' show LiveFixture;
import 'support/server_harness.dart';
import 'support/circle_harness.dart' show currentUri;
import 'screen_audit_visual_review_test.dart' show capture;

void main() {
  for (final surface in [
    'home',
    'circle',
    'profile',
    'saved',
    'detail',
    'events',
  ]) {
    testWidgets(
      'shared event invitation on $surface uses page data and opens RSVP',
      (tester) async {
        final f = LiveFixture();
        f.event['start_at'] = '2026-11-08T01:30:00Z';
        f.event['maybe_count'] = 1;
        final mid = f.server.addMemory(
          f.group,
          f.owner,
          f.event['title'] as String,
        );
        f.server.memories.first['events'] = [f.event];
        f.server.saves[mid] = {f.owner};
        final c = await openServerCircle(
          tester,
          f.server,
          tokens: await storedSession(f.server, f.owner),
        );
        c.read(circleRouterProvider).go(switch (surface) {
          'circle' => '/groups/g/${f.group}',
          'profile' || 'saved' => '/you',
          'detail' => '/home/memory/$mid',
          'events' => '/events',
          _ => '/home',
        });
        await settle(tester);
        if (surface == 'saved') {
          await tester.tap(find.text('Saved'));
          await settle(tester);
        }
        final card = find.byType(LiveEventCard);
        await tester.ensureVisible(card);
        await settle(tester);
        expect(card, findsOneWidget);
        expect(
          find.text('Fictional picnic'),
          findsOneWidget,
          reason: 'No duplicate Memory caption',
        );
        expect(
          f.server.adapter.count('GET', '/events/91'),
          0,
          reason: 'Batched page data avoids detail fan-out',
        );
        await capture(tester, 'event-card-$surface', '393-light');
        final action = find.descendant(
          of: card,
          matching: find.text('View event'),
        );
        await tester.ensureVisible(action);
        await tester.tap(action);
        await settle(tester);
        expect(currentUri(c).path, '/events/e/91');
        expect(find.text('Going'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'separate date and time controls create one publication visible on Home',
    (tester) async {
      final f = LiveFixture();
      f.server.adapter.handler = (r) {
        if (r.path == '/groups/${f.group}/events' && r.method == 'POST') {
          f.event.addAll(r.json);
          if (f.server.memories.isEmpty) {
            final mid = f.server.addMemory(
              f.group,
              f.owner,
              f.event['title'] as String,
            );
            f.server.memories.first['events'] = [f.event];
            expect(mid, isPositive);
          }
        }
        return f.handle(r);
      };
      final c = await openServerCircle(
        tester,
        f.server,
        tokens: await storedSession(f.server, f.owner),
      );
      c.read(circleRouterProvider).go('/events/new?group=${f.group}');
      await settle(tester);
      await tester.enterText(
        find.byType(TextField).at(0),
        'Fictional Sunday game',
      );
      await tester.enterText(find.byType(TextField).at(1), 'Fictional park');
      await tester.tap(find.text('Date'));
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);
      await tester.tap(find.text('Time'));
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);
      await capture(tester, 'event-form-filled', '393-light');
      final create = find.text('Create event');
      await tester.ensureVisible(create);
      await tester.tap(create);
      await settle(tester);
      expect(f.server.adapter.count('POST', '/groups/${f.group}/events'), 1);
      expect(currentUri(c).path, '/events/e/91');
      c.read(circleRouterProvider).go('/home');
      await settle(tester);
      expect(find.byType(LiveEventCard), findsOneWidget);
      expect(find.text('Fictional Sunday game'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final layout in [
    (393.0, 1.0, false),
    (320.0, 2.0, false),
    (320.0, 2.0, true),
    (900.0, 2.0, false),
  ]) {
    testWidgets(
      'selected event form ${layout.$1} scale${layout.$2} dark${layout.$3}',
      (tester) async {
        final f = LiveFixture();
        tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
        tester.platformDispatcher.platformBrightnessTestValue = layout.$3
            ? Brightness.dark
            : Brightness.light;
        addTearDown(() {
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          tester.platformDispatcher.clearPlatformBrightnessTestValue();
        });
        final c = await openServerCircle(
          tester,
          f.server,
          size: Size(layout.$1, 1100),
          tokens: await storedSession(f.server, f.owner),
        );
        c
            .read(themeProvider.notifier)
            .change(layout.$3 ? ThemeMode.dark : ThemeMode.light);
        c.read(circleRouterProvider).go('/events/new?group=${f.group}');
        await settle(tester);
        expect(find.text('When'), findsOneWidget);
        expect(find.text('Where'), findsOneWidget);
        expect(find.text('Date'), findsOneWidget);
        expect(find.text('Time'), findsOneWidget);
        await capture(
          tester,
          'event-form',
          '${layout.$1.toInt()}-${layout.$2}-${layout.$3}',
        );
        final create = find.text('Create event');
        await tester.scrollUntilVisible(
          create,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);
        expect(create, findsOneWidget);
        c.read(circleRouterProvider).go('/events');
        await settle(tester);
        expect(find.byType(LiveEventCard), findsOneWidget);
        await capture(
          tester,
          'event-list',
          '${layout.$1.toInt()}-${layout.$2}-${layout.$3}',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
