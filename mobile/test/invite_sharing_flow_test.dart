import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:mobile/core/theme_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/app/circle_experience.dart';

import 'support/server_harness.dart';
import 'support/fake_api.dart';

void main() {
  testWidgets('server invite requires a selected phone before sharing', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('circle/invite_share'),
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('circle/invite_share'),
        null,
      ),
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final server = FakeCircleServer();
    final owner = server.addUser(
      '+15550000001',
      'fictional-password',
      'Fictional Owner',
    );
    final group = server.addGroup('Fictional Group', owner);
    final container = await openServerCircle(
      tester,
      server,
      config: ApiConfig.parse('https://circle.test/api/v1')!,
      tokens: await storedSession(
        server,
        owner,
        config: ApiConfig.parse('https://circle.test/api/v1')!,
      ),
    );
    container.read(circleRouterProvider).go('/groups/g/$group/invite');
    await settle(tester);
    expect(find.text('Choose contact'), findsOneWidget);
    expect(find.textContaining('circle://'), findsNothing);
    expect(find.text('Enter phone number'), findsOneWidget);
    expect(find.text('Copy invite link'), findsNothing);
    expect(find.text('Manage invite link'), findsNothing);
  });
  for (final outcome in ['share_link', 'invited']) {
    testWidgets('iOS selected contact $outcome flow', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const token = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const phone = '+15551234567';
      final nativeCalls = <MethodCall>[];
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('circle/invite_share'),
        (call) async {
          nativeCalls.add(call);
          return call.method == 'pickPhone' ? phone : true;
        },
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('circle/invite_share'),
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      final server = FakeCircleServer();
      var invitations = 0;
      server.adapter.handler = (request) {
        if (request.uri.path.endsWith('/contact-invitations')) {
          invitations++;
          expect(request.json, {'mobile': phone});
          return FakeResponse.ok({
            'outcome': outcome,
            if (outcome == 'share_link') 'token': token,
            if (outcome == 'invited') 'invitation_id': 18,
          });
        }
        return server.handle(request);
      };
      final owner = server.addUser(
        '+15550000001',
        'fictional-password',
        'Fictional Owner',
      );
      final group = server.addGroup('Fictional Friends', owner);
      final config = ApiConfig.parse('https://circle.test/api/v1')!;
      final container = await openServerCircle(
        tester,
        server,
        config: config,
        tokens: await storedSession(server, owner, config: config),
      );
      container.read(circleRouterProvider).go('/groups/g/$group/invite');
      await settle(tester);
      expect(find.text('Copy invite link'), findsNothing);
      await tester.tap(find.text('Choose contact'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Confirm mobile number'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Send invitation'));
      await settle(tester);
      expect(invitations, 1);
      expect(nativeCalls.single.method, 'pickPhone');
      if (outcome == 'share_link') {
        await tester.ensureVisible(find.text('Copy invite link'));
        await tester.tap(find.text('Copy invite link'));
        await settle(tester);
        expect(clipboard, 'https://circle.test/invite.html#$token');
        expect(clipboard, isNot(contains(phone)));
        await tester.ensureVisible(find.text('SMS'));
        await tester.tap(find.text('SMS'));
        await settle(tester);
        expect(nativeCalls.last.arguments['phone'], phone);
        expect(nativeCalls.last.arguments['target'], 'sms');
        expect(invitations, 1);
      } else {
        expect(
          find.text('Invitation sent. They choose whether to accept.'),
          findsOneWidget,
        );
        expect(find.text('Copy invite link'), findsNothing);
      }
      if (Platform.environment['CIRCLE_CAPTURE_UI'] == 'true') {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/circle-contact-$outcome.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      debugDefaultTargetPlatformOverride = null;
    });
  }
  for (final width in [320.0, 900.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('contact invite $width ${brightness.name} at 200% text', (
        tester,
      ) async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('circle/invite_share'),
          (_) async => null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('circle/invite_share'),
            null,
          ),
        );
        final server = FakeCircleServer();
        final owner = server.addUser(
          '+15550000001',
          'fictional-password',
          'Fictional Owner',
        );
        final group = server.addGroup('Fictional Friends', owner);
        final config = ApiConfig.parse('https://circle.test/api/v1')!;
        final container = await openServerCircle(
          tester,
          server,
          config: config,
          tokens: await storedSession(server, owner, config: config),
          size: Size(width, 1000),
        );
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        container
            .read(themeProvider.notifier)
            .change(
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
            );
        container.read(circleRouterProvider).go('/groups/g/$group/invite');
        await settle(tester);
        expect(find.text('Choose contact'), findsOneWidget);
        expect(find.text('Copy invite link'), findsNothing);
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
              '/tmp/circle-contact-$width-${brightness.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
