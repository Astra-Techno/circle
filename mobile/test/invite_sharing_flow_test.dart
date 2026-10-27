import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mobile/core/theme_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/app/circle_experience.dart';
import 'support/circle_harness.dart' show openCircle;
import 'support/server_harness.dart';
import 'support/fake_api.dart';

void main() {
  testWidgets(
    'server invite is compact and copy creates its link without a contact',
    (tester) async {
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
      await tester.tap(find.text('Copy invite link'));
      await settle(tester);
      expect(find.text('Invite link copied.'), findsOneWidget);
      expect(find.text('Manage invite link'), findsOneWidget);
      expect(find.text('WhatsApp'), findsNothing);
    },
  );
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
        expect(find.text('Copy invite link'), findsOneWidget);
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
  testWidgets('fictional preview never opens real contact/share controls', (
    tester,
  ) async {
    final container = await openCircle(tester);
    container.read(circleRouterProvider).go('/groups/g/club/invite');
    await tester.pumpAndSettle();
    expect(find.text('Copy preview link'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('SMS'), findsNothing);
  });
}
