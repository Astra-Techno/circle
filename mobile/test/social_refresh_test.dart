import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/design.dart';
import 'support/circle_harness.dart' show currentUri, openTab;
import 'live_polls_test.dart' show PollFixture;
import 'support/fake_api.dart';
import 'support/root_style_fixture.dart';
import 'support/server_harness.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('dock retains readable targets at 320px and scale $scale', (
      tester,
    ) async {
      final f = RootStyleFixture();
      final c = await openServerCircle(
        tester,
        f.server,
        tokens: await storedSession(f.server, f.owner),
        size: const Size(320, 1000),
      );
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await settle(tester);
      for (final label in ['Home', 'Circles', 'Chats', 'Events', 'Profile']) {
        final target = find.byTooltip(label);
        expect(find.text(label), findsNothing);
        expect(tester.getRect(target).bottom, lessThanOrEqualTo(1000));
        expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        expect(
          tester.getCenter(target).dy,
          tester.getCenter(find.byTooltip('Home')).dy,
        );
      }
      if (scale == 1) {
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(
          tester.getSize(find.byWidget(scaffold.bottomNavigationBar!)).height,
          lessThanOrEqualTo(72),
          reason: '56px capsule plus one 8px gap on each side',
        );
      }
      c.read(circleRouterProvider).go('/events/new');
      await settle(tester);
      expect(find.byType(BackButton), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('filtered chat search loads the next page only on request', (
    tester,
  ) async {
    final f = RootStyleFixture();
    final offsets = <String?>[];
    f.server.adapter.handler = (r) async {
      if (r.path != '/chats') return f.handle(r);
      offsets.add(r.query['offset']);
      final second = r.query['offset'] == '30';
      return FakeResponse.ok({
        'items': [
          for (var i = 0; i < (second ? 1 : 30); i++)
            {
              'id': second ? 999 : 501 + i,
              'name': second ? 'Fictional Needle' : 'Fictional circle $i',
              'group_id': f.group,
              'kind': 'group',
              'unread': 0,
              'archived': false,
              'pinned': false,
              'muted': false,
              'last_message': null,
            },
        ],
        'has_more': !second,
      });
    };
    final c = await openServerCircle(
      tester,
      f.server,
      tokens: await storedSession(f.server, f.owner),
    );
    c.read(circleRouterProvider).go('/chats');
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Needle');
    await settle(tester);
    expect(offsets, ['0']);
    expect(find.text('No matching chats'), findsOneWidget);
    expect(
      find.text('Search and filters apply to chats loaded so far.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Load more chats'));
    await settle(tester);
    expect(offsets, ['0', '30']);
    expect(find.text('Fictional Needle'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await settle(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('archive and unread filters preserve distinct inbox states', (
    tester,
  ) async {
    final f = RootStyleFixture();
    f.server.adapter.handler = (r) async {
      if (r.path != '/chats') return f.handle(r);
      return FakeResponse.ok({
        'items': [
          for (final entry in [
            ('Active', false, 2),
            ('Archived', true, 3),
            ('Read', false, 0),
          ])
            {
              'id': 501,
              'name': 'Fictional ${entry.$1}',
              'group_id': f.group,
              'kind': 'group',
              'unread': entry.$3,
              'archived': entry.$2,
              'last_message': null,
            },
        ],
        'has_more': false,
      });
    };
    final c = await openServerCircle(
      tester,
      f.server,
      tokens: await storedSession(f.server, f.owner),
    );
    c.read(circleRouterProvider).go('/chats');
    await settle(tester);
    expect(find.text('Fictional Archived'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Unread'));
    await settle(tester);
    expect(find.text('Fictional Active'), findsOneWidget);
    expect(find.text('Fictional Read'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Archived'));
    await settle(tester);
    expect(find.text('Fictional Archived'), findsOneWidget);
    expect(find.text('Fictional Active'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'group actions open scoped destinations and Back restores the group',
    (tester) async {
      final f = RootStyleFixture();
      final c = await openServerCircle(
        tester,
        f.server,
        tokens: await storedSession(f.server, f.owner),
      );
      final router = c.read(circleRouterProvider);
      router.go('/groups/g/${f.group}');
      await settle(tester);
      for (final label in ['Chat', 'Events']) {
        await openTab(tester, label);
        await settle(tester);
        final uri = currentUri(c);
        if (label == 'Chat') {
          expect(uri.path, '/chats/g/${f.group}');
          final send = tester.widget<Icon>(
            find.descendant(
              of: find.byTooltip('Send'),
              matching: find.byType(Icon),
            ),
          );
          expect(
            send.color,
            circleTheme(Brightness.light).colorScheme.onPrimary,
          );
        } else {
          expect(uri.path, '/groups/g/${f.group}/events');
          await tester.tap(find.byTooltip('New event'));
          await settle(tester);
          expect(currentUri(c).path, '/events/new');
          expect(currentUri(c).queryParameters['group'], '${f.group}');
          router.pop();
          await settle(tester);
        }
        expect(router.canPop(), isTrue);
        router.pop();
        await settle(tester);
        expect(currentUri(c).path, '/groups/g/${f.group}');
        expect(find.text('Open group chat'), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'past event filter can find a later page without an automatic scan',
    (tester) async {
      final f = RootStyleFixture();
      final offsets = <String?>[];
      f.server.adapter.handler = (r) async {
        if (r.path != '/events') return f.handle(r);
        offsets.add(r.query['offset']);
        final later = r.query['offset'] == '30';
        return FakeResponse.ok({
          'items': [
            for (var i = 0; i < (later ? 1 : 30); i++)
              {
                ...f.event,
                'id': 91 + i,
                'title': later ? 'Fictional past event' : 'Fictional future $i',
                'start_at': later
                    ? '2020-01-01T12:00:00Z'
                    : '2030-01-01T12:00:00Z',
              },
          ],
          'has_more': !later,
        });
      };
      final c = await openServerCircle(
        tester,
        f.server,
        tokens: await storedSession(f.server, f.owner),
      );
      c.read(circleRouterProvider).go('/events');
      await settle(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Past'));
      await settle(tester);
      expect(offsets, ['0']);
      await tester.tap(find.text('Load more events'));
      await settle(tester);
      expect(find.text('Fictional past event'), findsOneWidget);
      expect(offsets, ['0', '30']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('circles are shown once and privacy uses its own title', (
    tester,
  ) async {
    final f = RootStyleFixture();
    final c = await openServerCircle(
      tester,
      f.server,
      tokens: await storedSession(f.server, f.owner),
    );
    c.read(circleRouterProvider).go('/groups');
    await settle(tester);
    expect(find.text('Fictional live circle'), findsOneWidget);
    expect(find.text('PINNED CIRCLES'), findsNothing);
    c.read(circleRouterProvider).go('/you/privacy');
    await settle(tester);
    final header = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Privacy and blocking'),
    );
    expect(header, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final multiple in [false, true]) {
    testWidgets(
      'poll choice semantics and close cancellation, multiple=$multiple',
      (tester) async {
        final f = PollFixture();
        f.server.adapter.handler = (r) async {
          if (r.path == '/polls/81' && r.method == 'GET') {
            return FakeResponse.ok({
              ...f.data(),
              'poll_type': multiple ? 'multiple' : 'single',
            });
          }
          return f.handle(r);
        };
        final c = await openServerCircle(
          tester,
          f.server,
          tokens: await storedSession(f.server, f.owner),
        );
        c.read(circleRouterProvider).go('/polls/p/81');
        await settle(tester);
        expect(
          find.byType(RadioListTile<int>),
          multiple ? findsNothing : findsNWidgets(2),
        );
        expect(
          find.byType(CheckboxListTile),
          multiple ? findsNWidgets(2) : findsNothing,
        );
        await tester.tap(find.text('Park'));
        await settle(tester);
        if (multiple) {
          await tester.tap(find.text('Cafe'));
          await settle(tester);
        }
        await tester.tap(find.text('Submit vote'));
        await settle(tester);
        expect(f.votes, multiple ? [1, 2] : [1]);
        await tester.tap(find.byTooltip('Poll options'));
        await settle(tester);
        await tester.tap(find.text('Close poll'));
        await settle(tester);
        await tester.tap(find.text('Cancel'));
        await settle(tester);
        expect(f.closed, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
