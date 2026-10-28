import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/theme_controller.dart';
import 'package:mobile/core/api/api_providers.dart';
import 'package:mobile/features/chat/application/live_chat.dart';
import 'package:mobile/features/events/application/live_events.dart';
import 'package:mobile/features/notifications/domain/push_envelope.dart';
import 'support/fake_api.dart';
import 'support/server_harness.dart';

class LiveFixture {
  LiveFixture() {
    owner = server.addUser(
      '+9995550000901',
      'fictional password',
      'Fictional Owner',
    );
    member = server.addUser(
      '+9995550000902',
      'fictional password',
      'Fictional Member',
    );
    group = server.addGroup('Fictional live circle', owner);
    server.members[group]![member] = 'member';
    event = {
      'id': 91,
      'group_id': group,
      'created_by': owner,
      'title': 'Fictional picnic',
      'description': 'Bring a blanket',
      'event_type': 'meetup',
      'venue': 'Fictional park',
      'online_link': '',
      'start_at': '2030-11-01T06:30:00Z',
      'end_at': null,
      'rsvp_deadline': null,
      'timezone': 'Asia/Kolkata',
      'max_capacity': 5,
      'version': 1,
      'status': 'active',
      'can_manage': true,
      'going_count': 0,
      'my_rsvp': null,
    };
    server.adapter.handler = handle;
  }
  final server = FakeCircleServer();
  late final int owner, member, group;
  late Map<String, Object?> event;
  final messages = <Map<String, Object?>>[];
  final sendKeys = <String>[];
  bool failOnce = false, muted = false, direct = false, pendingRequest = false;
  final reports = <Map<String, Object?>>[];
  Future<FakeResponse> handle(FakeRequest r) async {
    if (!server.access.containsKey(r.bearer)) return server.handle(r);
    if (r.path == '/chats') {
      return FakeResponse.ok({
        'items': [
          {
            'id': 501,
            'group_id': group,
            'kind': 'group',
            'name': 'Fictional live circle',
            'request_state': 'accepted',
            'incoming': false,
            'unread': messages.length,
            'muted': muted,
            'pinned': false,
            'archived': false,
          },
        ],
        'has_more': false,
      });
    }
    if (r.path == '/chats/contacts') {
      return FakeResponse.ok({
        'items': [
          {'id': member, 'display_name': 'Fictional Member'},
        ],
        'has_more': false,
      });
    }
    if (r.path == '/groups/$group/chat' || r.path == '/chats/direct/$member') {
      return FakeResponse.ok({'id': 501});
    }
    if (r.path == '/chats/501') {
      return FakeResponse.ok({
        'id': 501,
        'group_id': direct ? null : group,
        'name': direct ? 'Fictional Owner' : 'Fictional live circle',
        'other_id': direct ? owner : null,
        'kind': direct ? 'direct' : 'group',
        'can_send': !pendingRequest,
        'request_state': pendingRequest ? 'pending' : 'accepted',
        'incoming': direct,
        'muted': muted,
        'pinned': false,
        'archived': false,
        'items': messages,
        'has_more': false,
      });
    }
    if (r.path == '/chats/501/request') {
      pendingRequest = false;
      return FakeResponse.ok(null);
    }
    if (r.path == '/chats/501/reports') {
      reports.add(r.json);
      return FakeResponse.ok(null);
    }
    if (r.path == '/chats/501/state') {
      muted = r.json['muted'] as bool? ?? muted;
      return FakeResponse.ok(null);
    }
    if (r.path == '/chats/501/messages') {
      final key = r.json['client_id'] as String;
      sendKeys.add(key);
      if (!messages.any((m) => m['client_id'] == key)) {
        messages.add({
          'id': messages.length + 1,
          'client_id': key,
          'author_id': owner,
          'display_name': 'Fictional Owner',
          'body': r.json['body'],
          'reply_to_id': r.json['reply_to_id'],
          'created_at': '2026-10-28T12:00:00Z',
          'edited': false,
          'removed': false,
          'reactions': [],
        });
      }
      if (failOnce) {
        failOnce = false;
        return FakeResponse.error(503, 'server_error');
      }
      return FakeResponse.ok({'id': messages.last['id']});
    }
    if (r.path == '/events') {
      return FakeResponse.ok({
        'items': [event],
        'has_more': false,
      });
    }
    if (r.path == '/events/91') {
      if (r.method == 'PATCH') {
        event.addAll(r.json);
        event['version'] = (event['version'] as int) + 1;
      }
      return FakeResponse.ok(event);
    }
    if (r.path == '/events/91/rsvp') {
      event['my_rsvp'] = r.json;
      event['going_count'] = r.json['status'] == 'going'
          ? 1 + (r.json['guest_count'] as int? ?? 0)
          : 0;
      return FakeResponse.ok(event);
    }
    if (r.path == '/events/91/attendees') {
      return FakeResponse.ok({'items': [], 'has_more': false});
    }
    if (r.path == '/groups/$group/events') {
      return FakeResponse.ok({'id': 91, 'group_id': group});
    }
    return server.handle(r);
  }
}

void main() {
  test(
    'event instants use IANA zones and reject nonexistent DST wall time',
    () {
      expect(
        liveEventInstant(DateTime(2030, 1, 1, 12), 'Asia/Kolkata'),
        '2030-01-01T06:30:00Z',
      );
      expect(
        liveEventInstant(DateTime(2030, 7, 1, 12), 'America/New_York'),
        '2030-07-01T16:00:00Z',
      );
      expect(
        () =>
            liveEventInstant(DateTime(2030, 3, 10, 2, 30), 'America/New_York'),
        throwsA(isA<CircleFailure>()),
      );
    },
  );
  testWidgets(
    'live chat retry preserves send id after an unknown committed result',
    (tester) async {
      final f = LiveFixture();
      final c = await openServerCircle(
        tester,
        f.server,
        tokens: await storedSession(f.server, f.owner),
      );
      c.read(circleRouterProvider).go('/chats');
      await settle(tester);
      await tester.tap(find.text('Fictional live circle'));
      await settle(tester);
      f.failOnce = true;
      await tester.enterText(find.byType(TextField), 'Fictional hello');
      final send = find.byTooltip('Send');
      await tester.scrollUntilVisible(
        send,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(send);
      await settle(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Fictional hello',
      );
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      ).clearSnackBars();
      await tester.scrollUntilVisible(
        send,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(send);
      await settle(tester);
      expect(f.sendKeys, hasLength(2));
      expect(f.sendKeys.first, f.sendKeys.last);
      expect(f.messages, hasLength(1));
      expect(find.text('Fictional hello'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('live event RSVP and versioned editor use server services', (
    tester,
  ) async {
    final f = LiveFixture();
    final c = await openServerCircle(
      tester,
      f.server,
      tokens: await storedSession(f.server, f.owner),
    );
    c.read(circleRouterProvider).go('/events/e/91');
    await settle(tester);
    expect(find.text('Fictional picnic'), findsOneWidget);
    await tester.ensureVisible(find.text('Going'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Going'));
    await settle(tester);
    expect(find.text('Your RSVP: going'), findsOneWidget);
    c.read(circleRouterProvider).go('/events/e/91/edit');
    await settle(tester);
    await tester.enterText(
      find.byType(TextField).first,
      'Fictional revised plan',
    );
    final save = find.text('Save event');
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await settle(tester);
    expect(f.event['title'], 'Fictional revised plan');
    expect(f.event['version'], 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('stale service actions never write under a replacement session', (
    tester,
  ) async {
    final f = LiveFixture();
    final c = await openServerCircle(
      tester,
      f.server,
      tokens: await storedSession(f.server, f.owner),
    );
    final chats = c.read(liveChatApiProvider),
        events = c.read(liveEventsApiProvider),
        api = c.read(apiClientProvider)!;
    final tokens = (await api.currentTokens())!;
    await api.saveTokens(
      TokenPair(
        accessToken: 'fictional-replaced',
        refreshToken: tokens.refreshToken,
        server: tokens.server,
      ),
    );
    await expectLater(
      chats.send('501', {
        'body': 'No stale send',
        'client_id': 'fictional-stale-send',
      }),
      throwsA(isA<ApiError>()),
    );
    await expectLater(
      events.update('91', {'version': 1, 'title': 'No stale edit'}),
      throwsA(isA<ApiError>()),
    );
    expect(f.server.adapter.count('POST', '/chats/501/messages'), 0);
    expect(f.server.adapter.count('PATCH', '/events/91'), 0);
  });
  test(
    'strict chat and event push references recheck target and current state',
    () {
      const scope = PushScope(
        server: 'https://fictional.example/api/v1',
        account: '2',
        sessionHash: 'scope',
      );
      final now = DateTime.utc(2026, 10, 28);
      for (final type in [
        'chat.message',
        'event.created',
        'event.updated',
        'event.cancelled',
        'event.rsvp',
        'event.reminder',
      ]) {
        final raw = <String, dynamic>{
          'event_id': 'a' * 64,
          'type': type,
          'api_base_url': scope.server,
          'recipient_id': scope.account,
          'session_scope': scope.sessionHash,
          'group_id': '7',
          'expires_at': '${now.millisecondsSinceEpoch ~/ 1000 + 3600}',
          if (type == 'chat.message') ...{
            'conversation_id': '5',
            'message_id': '8',
          } else ...{
            'event_ref': '9',
            'event_version': '2',
          },
        };
        final p = PushEnvelope.parse(raw, scope, now)!;
        expect(p.toData(), raw);
        expect(
          p.authorizes(
            type == 'chat.message'
                ? {'id': 8, 'conversation_id': 5, 'notification_allowed': true}
                : {
                    'id': 9,
                    'group_id': 7,
                    'version': 2,
                    'status': type == 'event.cancelled'
                        ? 'cancelled'
                        : 'active',
                    'start_at': '2030-01-01T00:00:00Z',
                  },
            now,
          ),
          isTrue,
        );
        expect(
          p.authorizes({
            'id': 9,
            'group_id': 7,
            'version': 1,
            'status': 'active',
          }, now),
          isFalse,
        );
        expect(
          PushEnvelope.parse({...raw, 'recipient_id': '3'}, scope, now),
          isNull,
        );
      }
    },
  );

  testWidgets('hidden Chats branch does not poll or retry in the background', (
    tester,
  ) async {
    final f = LiveFixture();
    final c = await openServerCircle(
      tester,
      f.server,
      tokens: await storedSession(f.server, f.owner),
    );
    c.read(circleRouterProvider).go('/chats/c/501');
    await settle(tester);
    c.read(circleRouterProvider).go('/home');
    await settle(tester);
    final reads = f.server.adapter.count('GET', '/chats/501');
    await tester.pump(const Duration(seconds: 16));
    await settle(tester);
    expect(f.server.adapter.count('GET', '/chats/501'), reads);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'a recipient can privately report a selected introduction before accepting',
    (tester) async {
      final f = LiveFixture()
        ..direct = true
        ..pendingRequest = true;
      f.messages.add({
        'id': 1,
        'author_id': f.owner,
        'display_name': 'Fictional Owner',
        'body': 'Fictional introduction',
        'removed': false,
        'edited': false,
        'reply_to_id': null,
        'reactions': [],
      });
      final c = await openServerCircle(
        tester,
        f.server,
        tokens: await storedSession(f.server, f.member),
      );
      c.read(circleRouterProvider).go('/chats/c/501');
      await settle(tester);
      expect(find.text('Accept request'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Message options').first);
      await tester.tap(find.byTooltip('Message options').first);
      await settle(tester);
      final report = find.text('Report message');
      await tester.scrollUntilVisible(
        report,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(report);
      await settle(tester);
      expect(
        find.textContaining('rest of your conversation is not shared'),
        findsOneWidget,
      );
      await tester.tap(find.text('Spam'));
      await settle(tester);
      final send = find.text('Send report');
      await tester.scrollUntilVisible(
        send,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(send);
      await settle(tester);
      expect(f.reports.single['message_id'], 1);
      expect(f.reports.single['reason'], 'spam');
      expect(f.reports.single.containsKey('body'), isFalse);
      expect(f.pendingRequest, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final width in [320.0, 900.0]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('populated chat redesign $width ${brightness.name} $scale', (
          tester,
        ) async {
          final f = LiveFixture();
          f.messages.addAll([
            {
              'id': 1,
              'author_id': f.member,
              'display_name': 'Fictional Member',
              'body': 'Shall we meet at the park this weekend?',
              'created_at': '2026-10-29T09:30:00Z',
              'removed': false,
              'edited': false,
              'reactions': [],
            },
            {
              'id': 2,
              'author_id': f.owner,
              'display_name': 'Fictional Owner',
              'body': 'Sounds lovely. I will bring a picnic!',
              'created_at': '2026-10-29T09:31:00Z',
              'removed': false,
              'edited': false,
              'reactions': [],
            },
          ]);
          final c = await openServerCircle(
            tester,
            f.server,
            tokens: await storedSession(f.server, f.owner),
            size: Size(width, 1000),
          );
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          c
              .read(themeProvider.notifier)
              .change(
                brightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
              );
          c.read(circleRouterProvider).go('/chats/c/501');
          await settle(tester);
          expect(find.text('Mute this chat'), findsNothing);
          expect(find.text('Unsend'), findsNothing);
          expect(tester.takeException(), isNull);
          if (Platform.environment['CIRCLE_CAPTURE_UI'] == 'true') {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byType(RepaintBoundary).first,
            );
            await tester.runAsync(() async {
              final pic = await boundary.toImage();
              final bytes = await pic.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '/tmp/circle-chat-redesign-$width-${brightness.name}-$scale.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              pic.dispose();
            });
          }
          final options = find.byTooltip('Message options').first;
          await tester.ensureVisible(options);
          await tester.tap(options);
          await settle(tester);
          await tester.tap(find.text('Reply'));
          await settle(tester);
          expect(find.text('Message options'), findsNothing);
          expect(find.text('Replying to message 1'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
  for (final width in [320.0, 900.0]) {
    for (final brightness in Brightness.values) {
      for (final surface in ['chat', 'event', 'event-form']) {
        testWidgets('$surface $width ${brightness.name} 200% text', (
          tester,
        ) async {
          final f = LiveFixture();
          final c = await openServerCircle(
            tester,
            f.server,
            tokens: await storedSession(f.server, f.owner),
            size: Size(width, 1000),
          );
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          c
              .read(themeProvider.notifier)
              .change(
                brightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
              );
          c
              .read(circleRouterProvider)
              .go(
                surface == 'chat'
                    ? '/chats/c/501'
                    : surface == 'event'
                    ? '/events/e/91'
                    : '/events/e/91/edit',
              );
          await settle(tester);
          expect(tester.takeException(), isNull);
          if (Platform.environment['CIRCLE_CAPTURE_UI'] == 'true') {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byType(RepaintBoundary).first,
            );
            await tester.runAsync(() async {
              final pic = await boundary.toImage();
              final bytes = await pic.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '/tmp/circle-new-$surface-$width-${brightness.name}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              pic.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
