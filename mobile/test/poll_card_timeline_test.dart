import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/theme_controller.dart';
import 'support/circle_harness.dart' show currentUri;
import 'package:mobile/features/polls/presentation/live_polls.dart';
import 'live_polls_test.dart' show PollFixture, tapPoll;
import 'support/server_harness.dart';
import 'screen_audit_visual_review_test.dart' show capture;

void main() {
  for (final surface in [
    'home',
    'circle',
    'profile',
    'saved',
    'detail',
    'polls',
  ]) {
    testWidgets(
      'live poll card votes inline on $surface without detail fan-out',
      (tester) async {
        final f = PollFixture();
        final mid = f.server.addMemory(f.group, f.owner, f.question);
        f.server.memories.first['polls'] = [
          {...f.data(), 'memory_id': mid},
        ];
        f.server.saves[mid] = {f.owner};
        final c = await openServerCircle(
          tester,
          f.server,
          tokens: await storedSession(f.server, f.owner),
        );
        final route = switch (surface) {
          'circle' => '/groups/g/${f.group}',
          'profile' || 'saved' => '/you',
          'detail' => '/home/memory/$mid',
          'polls' => '/polls',
          _ => '/home',
        };
        c.read(circleRouterProvider).go(route);
        await settle(tester);
        if (surface == 'saved') {
          await tapPoll(tester, find.text('Saved'));
        }
        final card = find.byType(LivePollCard);
        await tester.ensureVisible(card);
        await settle(tester);
        expect(card, findsOneWidget);
        expect(
          find.byTooltip('Poll options'),
          surface == 'polls' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('View voters'),
          findsNothing,
          reason: 'Empty voter list has no useful action',
        );
        expect(find.textContaining('Choose one'), findsNothing);
        expect(find.textContaining('Names visible'), findsNothing);
        expect(
          find.text(f.question),
          findsOneWidget,
          reason: 'No duplicated Memory caption',
        );
        expect(
          f.server.adapter.count('GET', '/polls/81'),
          0,
          reason: 'Use batched Memory payload',
        );
        expect(
          find.byType(LinearProgressIndicator),
          findsNothing,
          reason: 'No empty result bars',
        );
        await tapPoll(tester, find.text('Park'));
        await capture(tester, 'poll-card-$surface', 'selected-393-light');
        await tapPoll(tester, find.text('Submit vote'));
        expect(f.votes, [1]);
        expect(find.text('1 vote'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final layout in [(393.0, 1.0, false), (320.0, 2.0, true)]) {
    testWidgets('contained poll supports Bold Text ${layout.$1} ${layout.$2}', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(boldText: true);
      addTearDown(() {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      final f = PollFixture()
        ..question = 'Who is coming to the fictional game tomorrow?';
      final mid = f.server.addMemory(f.group, f.owner, f.question);
      f.server.memories.first['polls'] = [f.data()];
      final c = await openServerCircle(
        tester,
        f.server,
        size: Size(layout.$1, 1100),
        tokens: await storedSession(f.server, f.owner),
      );
      c
          .read(themeProvider.notifier)
          .change(layout.$3 ? ThemeMode.dark : ThemeMode.light);
      c.read(circleRouterProvider).go('/home');
      await settle(tester);
      await capture(
        tester,
        'poll-refined-bold',
        '${layout.$1.toInt()}-${layout.$2}-${layout.$3}',
      );
      expect(find.byTooltip('Poll options'), findsNothing);
      final card = find.byType(LivePollCard);
      await tester.ensureVisible(find.byKey(const ValueKey('open-poll-81')));
      await tester.tap(find.byKey(const ValueKey('open-poll-81')));
      await settle(tester);
      expect(currentUri(c).path, '/polls/p/81');
      expect(find.byTooltip('Poll options'), findsOneWidget);
      expect(card, findsOneWidget);
      expect(mid, isPositive);
      expect(tester.takeException(), isNull);
    });
  }
}
