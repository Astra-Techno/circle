import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/api/api_providers.dart';
import 'package:mobile/core/theme_controller.dart';
import 'package:mobile/features/profile/application/server_blocks.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/fake_api.dart';
import 'support/server_harness.dart';

void main() {
  testWidgets(
    'direct-contact block persists while group profiles and Memories remain visible',
    (tester) async {
      final server = FakeCircleServer();
      final owner = server.addUser(
        '+9995550000801',
        'fictional password',
        'Owner',
      );
      final member = server.addUser(
        '+9995550000802',
        'fictional password',
        'Fictional Person',
      );
      final group = server.addGroup('Fictional group', owner);
      server.members[group]![member] = 'member';
      server.addMemory(group, member, 'Private Memory');
      final c = await openServerCircle(
        tester,
        server,
        tokens: await storedSession(server, owner),
      );
      c.read(circleRouterProvider).go('/people/$member');
      await settle(tester);
      final button = find.text('Block Fictional Person');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await settle(tester);
      await tester.tap(find.text('Block').last);
      await settle(tester);
      expect(server.blocks[owner]!.containsKey(member), isTrue);
      expect(c.read(circleWorkspaceProvider).value!.memories, hasLength(1));
      expect(
        c
            .read(circleWorkspaceProvider)
            .value!
            .group('$group')!
            .roleOf('$owner'),
        CircleRole.owner,
      );
      expect(find.text('This profile isn’t available'), findsNothing);
      c.read(circleRouterProvider).go('/you/privacy');
      await settle(tester);
      expect(find.text('Name saved when blocked'), findsOneWidget);
      await tester.tap(find.text('Unblock'));
      await settle(tester);
      expect(server.blocks[owner], isEmpty);
      expect(c.read(circleWorkspaceProvider).value!.memories, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'a stale same-account scope cannot block under a replacement session',
    (tester) async {
      final server = FakeCircleServer();
      final owner = server.addUser(
        '+9995550000803',
        'fictional password',
        'Owner',
      );
      final c = await openServerCircle(
        tester,
        server,
        tokens: await storedSession(server, owner),
      );
      final actions = c.read(blockActionsProvider),
          scope = c.read(blockActionsProvider).capture();
      final api = c.read(apiClientProvider)!;
      final tokens = (await api.currentTokens())!;
      await api.saveTokens(
        TokenPair(
          accessToken: 'fictional-replacement',
          refreshToken: tokens.refreshToken,
          server: tokens.server,
        ),
      );
      await expectLater(
        actions.change(scope, '9', blocked: true),
        throwsA(isA<CircleFailure>()),
      );
      expect(server.adapter.count('PUT', '/me/blocks/9'), 0);
    },
  );
  testWidgets(
    'blocking direct contact preserves group reading during group-refresh failure',
    (tester) async {
      final server = FakeCircleServer();
      final owner = server.addUser(
        '+9995550000805',
        'fictional password',
        'Owner',
      );
      final member = server.addUser(
        '+9995550000806',
        'fictional password',
        'Member',
      );
      final group = server.addGroup('Fictional group', owner);
      server.members[group]![member] = 'member';
      server.addMemory(group, member, 'Private Memory');
      final c = await openServerCircle(
        tester,
        server,
        tokens: await storedSession(server, owner),
      );
      var changed = false;
      server.adapter.handler = (r) async {
        if (changed && r.path == '/groups') {
          return FakeResponse.error(503, 'server_error');
        }
        final response = await server.handle(r);
        if (r.method == 'PUT' && r.path.startsWith('/me/blocks/')) {
          changed = true;
        }
        return response;
      };
      final actions = c.read(blockActionsProvider);
      final operation = actions.change(
        actions.capture(),
        '$member',
        blocked: true,
      );
      final assertion = expectLater(operation, completes);
      await settle(tester);
      await assertion;
      expect(server.blocks[owner]!.containsKey(member), isTrue);
      expect(c.read(circleWorkspaceProvider).hasError, isFalse);
      expect(c.read(circleWorkspaceProvider).value?.memories, hasLength(1));
      expect(c.read(circleWorkspaceProvider).value?.groups, hasLength(1));
      expect(
        c.read(circleWorkspaceProvider).value!.memories.single.text,
        'Private Memory',
      );
    },
  );
  testWidgets('blocking an inviter clears the expired detail card', (
    tester,
  ) async {
    final server = FakeCircleServer();
    final owner = server.addUser(
      '+9995550000807',
      'fictional password',
      'Sender',
    );
    final member = server.addUser(
      '+9995550000808',
      'fictional password',
      'Recipient',
    );
    final group = server.addGroup('Fictional group', owner);
    server.members[group]![member] = 'member';
    server.adapter.handler = (request) async {
      if (request.path == '/group-invitations/99') {
        if (server.blocks[member]?.containsKey(owner) == true) {
          return FakeResponse.error(404, 'not_found');
        }
        return FakeResponse.ok({
          'invitation': {
            'id': 99,
            'recipient_id': member,
            'inviter_id': owner,
            'group_id': group,
            'group_name': 'Invited group',
            'inviter_name': 'Sender',
            'status': 'pending',
            'expires_at': '2099-01-01T00:00:00Z',
            'approval_required': false,
          },
        });
      }
      return server.handle(request);
    };
    final c = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, member),
    );
    c.read(circleRouterProvider).go('/you/invitations/99');
    await settle(tester);
    expect(find.text('Accept'), findsOneWidget);
    await tester.tap(find.text('Block inviter'));
    await settle(tester);
    await tester.tap(find.text('Block').last);
    await settle(tester);
    expect(server.blocks[member]?.containsKey(owner), isTrue);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Sender invited you'), findsNothing);
    expect(find.text('Block inviter'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 900.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('blocking $width ${brightness.name} 200% text', (
        tester,
      ) async {
        final server = FakeCircleServer();
        final owner = server.addUser(
          '+9995550000804',
          'fictional password',
          'Owner',
        );
        server.blocks[owner] = {88: 'Fictional Person'};
        final c = await openServerCircle(
          tester,
          server,
          tokens: await storedSession(server, owner),
          size: Size(width, 1000),
        );
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        c
            .read(themeProvider.notifier)
            .change(
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
            );
        c.read(circleRouterProvider).go('/you/privacy');
        await settle(tester);
        expect(find.text('Unblock'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (Platform.environment['CIRCLE_CAPTURE_UI'] == 'true') {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first,
          );
          await tester.runAsync(() async {
            final capture = await boundary.toImage();
            final bytes = await capture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/circle-block-$width-${brightness.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            capture.dispose();
          });
        }
      });
    }
  }
}
