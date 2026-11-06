import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/design.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/circle_harness.dart' show currentUri, reveal, openTab;
import 'package:mobile/features/memories/presentation/memory_card.dart';
import 'support/root_style_fixture.dart';
import 'support/server_harness.dart';

Future<void> capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['CIRCLE_SURFACE_CAPTURES'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('Circle and Profile share Home cards at scale $scale', (
      tester,
    ) async {
      final fixture = RootStyleFixture();
      fixture.server.addMemory(
        fixture.group,
        fixture.owner,
        'A little moment worth keeping.',
      );
      final container = await openServerCircle(
        tester,
        fixture.server,
        tokens: await storedSession(fixture.server, fixture.owner),
        size: const Size(393, 1000),
      );
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final page in ['groups/g/${fixture.group}', 'you']) {
        container.read(circleRouterProvider).go('/$page');
        await settle(tester);
        await capture(
          tester,
          '${page.startsWith('groups') ? 'circle' : 'profile'}-$scale',
        );
        expect(tester.takeException(), isNull, reason: page);
        expect(find.byType(CircleMemoryCard), findsWidgets);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'Circle actions replace tabs and preserve scoped destinations and Back',
    (tester) async {
      final fixture = RootStyleFixture();
      final container = await openServerCircle(
        tester,
        fixture.server,
        tokens: await storedSession(fixture.server, fixture.owner),
      );
      final router = container.read(circleRouterProvider);
      router.go('/groups/g/${fixture.group}');
      await settle(tester);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Share a Memory here'), findsNothing);
      expect(find.text('Polls'), findsOneWidget);
      for (final action in ['Events', 'Memory', 'InCircles']) {
        await openTab(tester, action);
        await settle(tester);
        final uri = currentUri(container);
        expect(uri.toString(), switch (action) {
          'Events' => '/groups/g/${fixture.group}/events',
          'Memory' => '/compose?group=${fixture.group}',
          _ => '/groups/g/${fixture.group}/incircles',
        });
        expect(router.canPop(), isTrue);
        router.pop();
        await settle(tester);
        expect(currentUri(container).path, '/groups/g/${fixture.group}');
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Saved uses Home cards; another author is excluded from Your Memories',
    (tester) async {
      final fixture = RootStyleFixture();
      final id = fixture.server.addMemory(
        fixture.group,
        fixture.member,
        'A saved moment from a friend.',
      );
      final container = await openServerCircle(
        tester,
        fixture.server,
        tokens: await storedSession(fixture.server, fixture.owner),
      );
      await tester.runAsync(
        () => container.read(circleWorkspaceProvider.notifier).save('$id'),
      );
      container.read(circleRouterProvider).go('/you');
      await settle(tester);
      expect(find.text('A saved moment from a friend.'), findsNothing);
      await tester.tap(find.text('Saved'));
      await settle(tester);
      expect(find.text('A saved moment from a friend.'), findsOneWidget);
      expect(find.byType(CircleMemoryCard), findsOneWidget);
      final comment = find.byTooltip(
        'Comment on Memory from Fictional Member in Fictional live circle',
      );
      await reveal(tester, comment);
      await tester.tap(comment);
      await settle(tester);
      expect(currentUri(container).path, '/home/memory/$id');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Members and InCircles routes reject nonmembers without content',
    (tester) async {
      final fixture = RootStyleFixture();
      final hidden = fixture.server.addGroup(
        'Fictional private circle',
        fixture.member,
      );
      final container = await openServerCircle(
        tester,
        fixture.server,
        tokens: await storedSession(fixture.server, fixture.owner),
      );
      for (final section in ['members', 'incircles']) {
        container.read(circleRouterProvider).go('/groups/g/$hidden/$section');
        await settle(tester);
        expect(find.text('This circle is private'), findsOneWidget);
        expect(find.text('Fictional private circle'), findsNothing);
        expect(find.byType(CircleMemoryCard), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Light page canvases stay white across root, detail and form routes',
    (tester) async {
      final fixture = RootStyleFixture();
      final container = await openServerCircle(
        tester,
        fixture.server,
        tokens: await storedSession(fixture.server, fixture.owner),
      );
      for (final route in [
        '/home',
        '/groups',
        '/chats',
        '/events',
        '/you',
        '/groups/g/${fixture.group}',
        '/groups/g/${fixture.group}/members',
        '/groups/g/${fixture.group}/incircles',
        '/compose',
        '/you/edit',
        '/search',
      ]) {
        container.read(circleRouterProvider).go(route);
        await settle(tester);
        final context = tester.element(find.byType(Scaffold).last);
        expect(
          Theme.of(context).scaffoldBackgroundColor,
          Colors.white,
          reason: route,
        );
        for (final element in find.byType(Scaffold).evaluate()) {
          final scaffold = element.widget as Scaffold;
          expect(
            scaffold.backgroundColor ??
                Theme.of(element).scaffoldBackgroundColor,
            Colors.white,
            reason: route,
          );
        }
        expect(tester.takeException(), isNull, reason: route);
      }
      expect(CircleAccents.light.chatWallpaper, Colors.white);
      expect(
        circleTheme(Brightness.dark).scaffoldBackgroundColor,
        isNot(Colors.white),
      );
    },
  );
}
