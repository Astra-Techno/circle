import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
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
        expect(find.text('1 voter'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
