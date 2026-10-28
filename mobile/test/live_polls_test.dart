import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/theme_controller.dart';
import 'package:mobile/features/polls/application/live_polls.dart';
import 'package:mobile/features/notifications/domain/push_envelope.dart';
import 'support/fake_api.dart';
import 'support/server_harness.dart';

class PollFixture {
  PollFixture() {
    owner = server.addUser(
      '+9995550000331',
      'fictional password',
      'Fictional Owner',
    );
    group = server.addGroup('Fictional circle', owner);
    server.adapter.handler = handle;
  }
  final server = FakeCircleServer();
  late final int owner, group;
  final votes = <int>[];
  final keys = <String>[];
  bool closed = false, anonymous = false, failOnce = false;
  String visibility = 'always', question = 'Where shall we meet?';
  Map<String, Object?> data() {
    final results =
        closed ||
        visibility == 'always' ||
        (visibility == 'after_voting' && votes.isNotEmpty);
    return {
      'id': 81,
      'group_id': group,
      'group_name': 'Fictional circle',
      'question': question,
      'created_by': owner,
      'event_id': null,
      'memory_id': null,
      'poll_type': 'single',
      'anonymous': anonymous,
      'allow_change_vote': true,
      'allow_add_options': true,
      'results_visibility': visibility,
      'results_available': results,
      'closed': closed,
      'closes_at': null,
      'my_votes': votes.toList(),
      'voter_count': results ? (votes.isEmpty ? 0 : 1) : null,
      'can_manage': true,
      'notification_allowed': true,
      'options': [
        for (final (i, label) in ['Park', 'Cafe'].indexed)
          {
            'id': i + 1,
            'label': label,
            if (results) 'votes': votes.contains(i + 1) ? 1 : 0,
          },
      ],
    };
  }

  Future<FakeResponse> handle(FakeRequest r) async {
    if (!server.access.containsKey(r.bearer)) return server.handle(r);
    if (r.path == '/polls') {
      return FakeResponse.ok({
        'items': [data()],
        'has_more': false,
      });
    }
    if (r.path == '/groups/$group/polls' && r.method == 'POST') {
      keys.add(r.json['client_id'] as String);
      question = r.json['question'] as String;
      anonymous = r.json['anonymous'] as bool;
      visibility = r.json['results_visibility'] as String;
      if (failOnce) {
        failOnce = false;
        return FakeResponse.error(503, 'server_error');
      }
      return FakeResponse.ok({'id': 81, 'group_id': group});
    }
    if (r.path == '/polls/81') return FakeResponse.ok(data());
    if (r.path == '/polls/81/votes') {
      votes
        ..clear()
        ..addAll((r.json['option_ids'] as List).cast<int>());
      return FakeResponse.ok(data());
    }
    if (r.path == '/polls/81/close') {
      closed = true;
      return FakeResponse.ok(data());
    }
    if (r.path == '/polls/81/voters') {
      return FakeResponse.ok({
        'items': [
          {
            'id': owner,
            'display_name': 'Fictional Owner',
            'option_id': 1,
            'label': 'Park',
          },
        ],
        'has_more': false,
      });
    }
    return server.handle(r);
  }
}

Future<void> tapPoll(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(target);
  await settle(tester);
}

void main() {
  testWidgets(
    'create retries preserve send id; vote, named results and close persist through API',
    (tester) async {
      final f = PollFixture()..failOnce = true;
      final c = await openServerCircle(
        tester,
        f.server,
        tokens: await storedSession(f.server, f.owner),
      );
      c.read(circleRouterProvider).go('/polls/new?group=${f.group}');
      await settle(tester);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Fictional meetup?');
      await tester.enterText(fields.at(1), 'Park');
      await tester.enterText(fields.at(2), 'Cafe');
      await tapPoll(tester, find.text('Post poll'));
      await tapPoll(tester, find.text('Post poll'));
      expect(f.keys, hasLength(2));
      expect(f.keys[0], f.keys[1]);
      expect(find.text('Fictional meetup?'), findsOneWidget);
      await tapPoll(tester, find.text('Park'));
      await tapPoll(tester, find.text('Submit vote'));
      expect(f.votes, [1]);
      expect(find.text('1 voter(s)'), findsOneWidget);
      await tapPoll(tester, find.text('See who voted'));
      expect(find.text('Fictional Owner'), findsOneWidget);
      expect(find.text('Park'), findsOneWidget);
      c.read(circleRouterProvider).go('/polls/p/81');
      await settle(tester);
      await tapPoll(tester, find.text('Close poll'));
      expect(f.closed, isTrue);
      expect(find.text('Submit vote'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'anonymous hidden results do not show voter names or counts before closing',
    (tester) async {
      final f = PollFixture()
        ..anonymous = true
        ..visibility = 'after_closing';
      final c = await openServerCircle(
        tester,
        f.server,
        tokens: await storedSession(f.server, f.owner),
      );
      c.read(circleRouterProvider).go('/polls/p/81');
      await settle(tester);
      expect(find.text('See who voted'), findsNothing);
      expect(find.textContaining('voter(s)'), findsNothing);
      expect(
        find.text('Results appear when this poll closes.'),
        findsOneWidget,
      );
      await tapPoll(tester, find.text('Park'));
      await tapPoll(tester, find.text('Submit vote'));
      expect(find.textContaining('voter(s)'), findsNothing);
      await tapPoll(tester, find.text('Close poll'));
      expect(find.text('1 voter(s)'), findsOneWidget);
      expect(find.text('See who voted'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('stale poll service cannot write in a replacement session', (
    tester,
  ) async {
    final f = PollFixture();
    final c = await openServerCircle(
      tester,
      f.server,
      tokens: await storedSession(f.server, f.owner),
    );
    final api = c.read(livePollApiProvider);
    await api.scope.api.clearTokens();
    await expectLater(api.vote('81', [1]), throwsA(anything));
    expect(f.server.adapter.count('PUT', '/polls/81/votes'), 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'poll push is strict, scope-bound and authorizes only the current poll state',
    () {
      const scope = PushScope(
        server: 'https://fictional.example/api/v1',
        account: '7',
        sessionHash: 'fictional-session',
      );
      final now = DateTime.utc(2030, 1, 1);
      final payload = <String, dynamic>{
        'event_id': 'a' * 64,
        'type': 'poll.closed',
        'api_base_url': scope.server,
        'recipient_id': '7',
        'session_scope': scope.sessionHash,
        'group_id': '2',
        'poll_ref': '81',
        'expires_at': '${now.millisecondsSinceEpoch ~/ 1000 + 600}',
      };
      final p = PushEnvelope.parse(payload, scope, now)!;
      expect(p.destination, '/polls/p/81');
      expect(p.authorizationPath, '/polls/81');
      expect(p.toData(), payload);
      expect(
        p.authorizes({
          'id': 81,
          'group_id': 2,
          'closed': true,
          'notification_allowed': true,
        }, now),
        isTrue,
      );
      expect(
        p.authorizes({
          'id': 81,
          'group_id': 2,
          'closed': false,
          'notification_allowed': true,
        }, now),
        isFalse,
      );
      expect(
        PushEnvelope.parse(
          {...payload, 'question': 'Private text'},
          scope,
          now,
        ),
        isNull,
      );
      expect(
        PushEnvelope.parse({...payload, 'recipient_id': '8'}, scope, now),
        isNull,
      );
    },
  );
  for (final width in [320.0, 900.0]) {
    for (final dark in [false, true]) {
      for (final form in [false, true]) {
        testWidgets(
          'poll ${form ? 'form' : 'detail'} $width dark=$dark 200% text',
          (tester) async {
            final f = PollFixture();
            final c = await openServerCircle(
              tester,
              f.server,
              tokens: await storedSession(f.server, f.owner),
              size: Size(width, 1000),
            );
            tester.platformDispatcher.textScaleFactorTestValue = 2;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            c
                .read(themeProvider.notifier)
                .change(dark ? ThemeMode.dark : ThemeMode.light);
            c
                .read(circleRouterProvider)
                .go(form ? '/polls/new?group=${f.group}' : '/polls/p/81');
            await settle(tester);
            expect(tester.takeException(), isNull);
            if (Platform.environment['CIRCLE_CAPTURE_UI'] == 'true') {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byType(RepaintBoundary).first,
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '/tmp/circle-poll-${form ? 'form' : 'detail'}-$width-${dark ? 'dark' : 'light'}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
