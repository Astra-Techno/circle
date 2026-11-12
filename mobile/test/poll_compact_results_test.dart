import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/design.dart';
import 'package:mobile/features/polls/presentation/live_polls.dart';
import 'live_polls_test.dart' show PollFixture;
import 'support/server_harness.dart';
import 'support/fake_api.dart';

Map<String, Object?> ballot(PollFixture f) => {
  ...f.data(),
  'question': 'Who’s joining tomorrow’s game?',
  'allow_add_options': false,
  'voter_count': 18,
  'my_votes': [2],
  'options': [
    for (final (index, label) in [
      'kaluthai povom',
      'ethuku poitu',
      'Ennavom',
    ].indexed)
      {'id': index + 1, 'label': label, 'votes': index == 1 ? 12 : 3},
  ],
};

Future<void> render(
  WidgetTester tester,
  PollFixture f,
  Map<String, Object?> poll, {
  double width = 390,
  double scale = 1,
  bool dark = false,
}) async {
  final container = await openServerCircle(
    tester,
    f.server,
    tokens: await storedSession(f.server, f.owner),
    size: Size(width, 1000),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: circleTheme(dark ? Brightness.dark : Brightness.light),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1000),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: RepaintBoundary(
                  key: const ValueKey('compact-poll-capture'),
                  child: LivePollCard(poll: poll, showAudience: false),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await settle(tester);
}

Future<void> capture(WidgetTester tester, String name) async {
  final root = Platform.environment['CIRCLE_POLL_CAPTURE_DIR'];
  if (root == null) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('compact-poll-capture')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(root).create(recursive: true);
    await File('$root/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final layout in [
    (390.0, 1.0, false),
    (320.0, 2.0, false),
    (320.0, 2.0, true),
    (900.0, 2.0, true),
  ]) {
    testWidgets(
      'compact saved results ${layout.$1} ${layout.$2} ${layout.$3}',
      (tester) async {
        final f = PollFixture();
        await render(
          tester,
          f,
          ballot(f),
          width: layout.$1,
          scale: layout.$2,
          dark: layout.$3,
        );
        expect(find.text('Your vote'), findsOneWidget);
        expect(find.text('12 votes · 67%'), findsOneWidget);
        expect(find.text('Save vote'), findsNothing);
        expect(
          find.text('Your choice is visible to this Circle.'),
          findsNothing,
        );
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byType(Divider), findsNothing);
        await capture(
          tester,
          'saved-${layout.$1.toInt()}-${layout.$2}-${layout.$3}',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'saved ballot only offers a mutation after changing or removing the choice',
    (tester) async {
      final f = PollFixture();
      await render(tester, f, ballot(f));
      await tester.tap(find.text('kaluthai povom'));
      await settle(tester);
      expect(find.text('Selected'), findsOneWidget);
      expect(find.text('Save vote'), findsOneWidget);
      await capture(tester, 'pending-390');
      await tester.tap(find.text('ethuku poitu'));
      await settle(tester);
      expect(find.text('Save vote'), findsNothing);
      expect(find.text('Your vote'), findsOneWidget);
      await tester.tap(find.text('ethuku poitu'));
      await settle(tester);
      expect(find.text('Remove vote'), findsOneWidget);
      expect(f.server.adapter.count('PUT', '/polls/81/votes'), 0);
    },
  );
  for (final locked in [
    {'closed': true},
    {'allow_change_vote': false},
  ]) {
    testWidgets('locked ballot $locked retains saved results', (tester) async {
      final f = PollFixture();
      await render(tester, f, {...ballot(f), ...locked});
      await tester.tap(find.text('kaluthai povom'));
      await settle(tester);
      expect(find.text('Your vote'), findsOneWidget);
      expect(find.text('Save vote'), findsNothing);
      expect(find.text('Selected'), findsNothing);
    });
  }
  testWidgets('multiple choice stays editable without an automatic write', (
    tester,
  ) async {
    final f = PollFixture();
    await render(tester, f, {
      ...ballot(f),
      'poll_type': 'multiple',
      'my_votes': [1, 2],
    });
    expect(find.text('Your vote'), findsNWidgets(2));
    await tester.tap(find.text('kaluthai povom'));
    await settle(tester);
    await tester.tap(find.text('Ennavom'));
    await settle(tester);
    expect(find.text('Selected'), findsNWidgets(2));
    expect(find.text('Save vote'), findsOneWidget);
    expect(f.server.adapter.count('PUT', '/polls/81/votes'), 0);
  });
  testWidgets('failed vote keeps the pending choice available for retry', (
    tester,
  ) async {
    final f = PollFixture();
    f.server.adapter.handler = (request) => request.path == '/polls/81/votes'
        ? FakeResponse.error(503, 'server_error')
        : f.handle(request);
    await render(tester, f, ballot(f));
    await tester.tap(find.text('kaluthai povom'));
    await settle(tester);
    await tester.ensureVisible(find.text('Save vote'));
    await tester.tap(find.text('Save vote'));
    await settle(tester);
    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('Save vote'), findsOneWidget);
    expect(f.server.adapter.count('PUT', '/polls/81/votes'), 1);
    expect(
      f.server.adapter.requests
          .lastWhere((r) => r.path == '/polls/81/votes')
          .json['option_ids'],
      [1],
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'hidden anonymous results never expose fills, totals or voter identities',
    (tester) async {
      final f = PollFixture();
      await render(tester, f, {
        ...ballot(f),
        'anonymous': true,
        'results_available': false,
        'voter_count': null,
        'results_visibility': 'after_closing',
      });
      expect(find.text('View voters'), findsNothing);
      expect(find.textContaining('67%'), findsNothing);
      expect(find.text('18 votes'), findsNothing);
      expect(find.text('Anonymous poll'), findsOneWidget);
      await capture(tester, 'hidden-390');
    },
  );
}
