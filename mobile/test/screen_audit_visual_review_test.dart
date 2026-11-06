import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/design.dart';
import 'package:mobile/features/chat/application/live_chat.dart';
import 'package:mobile/core/theme_controller.dart';
import 'package:mobile/features/notifications/application/push_settings.dart';
import 'package:mobile/features/notifications/application/push_session_coordinator.dart';
import 'package:mobile/features/notifications/presentation/server_push_settings.dart';
import 'support/circle_harness.dart' as mock;
import 'support/fake_api.dart';
import 'support/root_style_fixture.dart';
import 'support/server_harness.dart';
import 'account_security_ui_test.dart' show row;
import 'live_polls_test.dart' show PollFixture;
import 'push_settings_ui_test.dart' show DefaultOnChoices, TrackingCoordinator;

Future<void> capture(WidgetTester tester, String name, String layout) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(tester.takeException(), isNull, reason: name);
  if (Platform.environment['CIRCLE_CAPTURE_DESIGN'] != 'true') return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(
      '${Platform.environment['CIRCLE_DESIGN_CAPTURE_DIR'] ?? '/tmp/circle-audit-fixes'}/extra',
    );
    await dir.create(recursive: true);
    await File(
      '${dir.path}/$name-$layout.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final layout in [
    (393.0, 852.0, 1.0, Brightness.light),
    (393.0, 852.0, 1.0, Brightness.dark),
    (320.0, 1000.0, 2.0, Brightness.dark),
    (900.0, 1100.0, 2.0, Brightness.light),
  ]) {
    final suffix = '${layout.$1.toInt()}-${layout.$3}-${layout.$4.name}';
    testWidgets('extended screen review $suffix', (tester) async {
      final size = Size(layout.$1, layout.$2);
      final c = await mock.openCircle(
        tester,
        size: size,
        scale: layout.$3,
        brightness: layout.$4,
      );
      for (final route in [
        '/home',
        '/home/memory/table',
        '/home/memory/table/photos',
        '/photos',
        '/people/mira',
        '/groups',
        '/groups/g/friends',
        '/groups/g/meetup',
        '/invite/chapter-verse-preview',
        '/invite/missing-link',
      ]) {
        c.read(circleRouterProvider).go(route);
        await capture(
          tester,
          'photo-${route.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-')}',
          suffix,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      final auth = await mock.openCircle(
        tester,
        entered: false,
        size: size,
        scale: layout.$3,
        brightness: layout.$4,
      );
      for (final route in ['/', '/login', '/register']) {
        auth.read(circleRouterProvider).go(route);
        await capture(tester, 'auth-${route.replaceAll('/', '-')}', suffix);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      final f = RootStyleFixture();
      f.server.adapter.handler = (r) async {
        if (r.path == '/me/chat-privacy') {
          return FakeResponse.ok({'who_can_message': 'all'});
        }
        if (r.path == '/me/sessions') {
          return FakeResponse.page(
            [row(true), row(false)],
            {'total': 2, 'limit': 30, 'offset': 0},
          );
        }
        if (r.path == '/me/group-invitations' ||
            r.path == '/group-invitations/12') {
          final item = {
            'id': 12,
            'recipient_id': f.owner,
            'group_id': f.group,
            'group_name': 'Fictional weekend Circle',
            'inviter_id': f.member,
            'inviter_name': 'Fictional Member',
            'status': 'pending',
            'approval_required': true,
            'expires_at': '2030-11-01T00:00:00Z',
          };
          return r.path == '/me/group-invitations'
              ? FakeResponse.page(
                  [item],
                  {'total': 1, 'limit': 20, 'offset': 0},
                )
              : FakeResponse.ok({'invitation': item});
        }
        return f.handle(r);
      };
      final server = await openServerCircle(
        tester,
        f.server,
        tokens: await storedSession(f.server, f.owner),
        size: size,
      );
      tester.platformDispatcher.textScaleFactorTestValue = layout.$3;
      server
          .read(themeProvider.notifier)
          .change(
            layout.$4 == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          );
      for (final route in [
        '/groups/g/${f.group}/members',
        '/groups/g/${f.group}/incircles',
        '/groups/g/${f.group}/reports',
        '/groups/new?parent=${f.group}',
        '/you/invitations',
        '/you/invitations/12',
        '/you/account/sessions',
        '/chats/privacy',
        '/chats/g/${f.group}',
        '/activity',
        '/groups/g/${f.group}/albums',
      ]) {
        server.read(circleRouterProvider).go(route);
        await capture(
          tester,
          'secondary-${route.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-')}',
          suffix,
        );
      }
      for (final pending in [false, true]) {
        f.direct = true;
        f.pendingRequest = pending;
        server.invalidate(liveConversationProvider);
        server.read(circleRouterProvider).go('/home');
        await settle(tester);
        server.read(circleRouterProvider).go('/chats/c/501');
        await capture(
          tester,
          pending ? 'direct-request' : 'direct-thread',
          suffix,
        );
        if (pending) expect(find.text('Accept request'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      final p = PollFixture();
      final polls = await openServerCircle(
        tester,
        p.server,
        tokens: await storedSession(p.server, p.owner),
        size: size,
      );
      tester.platformDispatcher.textScaleFactorTestValue = layout.$3;
      polls
          .read(themeProvider.notifier)
          .change(
            layout.$4 == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          );
      for (final route in [
        '/polls?group=${p.group}',
        '/polls/new?group=${p.group}',
        '/polls/p/81',
        '/polls/p/81/voters',
      ]) {
        polls.read(circleRouterProvider).go(route);
        await capture(
          tester,
          'poll-${route.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-')}',
          suffix,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      final coordinator = TrackingCoordinator();
      final choices = ProviderContainer(
        overrides: [
          pushSettingsProvider.overrideWith(DefaultOnChoices.new),
          pushSessionCoordinatorProvider.overrideWithValue(coordinator),
        ],
      );
      addTearDown(choices.dispose);
      addTearDown(coordinator.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: choices,
          child: MaterialApp(
            theme: circleTheme(layout.$4),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(layout.$3),
              ),
              child: const Scaffold(body: ServerPushSettingsScreen()),
            ),
          ),
        ),
      );
      await capture(tester, 'notifications-component', suffix);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
