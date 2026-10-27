import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/theme_controller.dart';
import 'package:mobile/features/moderation/application/server_moderation.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/fake_api.dart';
import 'support/server_harness.dart';

void main() {
  testWidgets(
    'server report persists, admin hides restores dismisses and undoes',
    (tester) async {
      final server = FakeCircleServer();
      final owner = server.addUser(
        '+9995550000790',
        'fictional password',
        'Owner',
      );
      final writer = server.addUser(
        '+9995550000791',
        'fictional password',
        'Writer',
      );
      final group = server.addGroup('Fictional safety group', owner);
      server.members[group]![writer] = 'member';
      final memory = server.addMemory(
        group,
        writer,
        'Fictional reportable Memory',
      );
      final c = await openServerCircle(
        tester,
        server,
        tokens: await storedSession(server, owner),
      );
      final controller = c.read(circleWorkspaceProvider.notifier);
      final menu = find.byTooltip(RegExp('More options for'));
      await tester.tap(menu.first);
      await settle(tester);
      await tester.tap(find.text('Report'));
      await settle(tester);
      expect(find.text('Preview: reports stay on this device.'), findsNothing);
      await tester.tap(find.text('Spam'));
      await settle(tester);
      await Scrollable.ensureVisible(
        tester.element(find.text('Send report')),
        alignment: 0.5,
      );
      await tester.tap(find.text('Send report'));
      await settle(tester);
      expect(server.moderationCases, hasLength(1));
      c.read(circleRouterProvider).go('/groups/g/$group/reports');
      await settle(tester);
      expect(find.textContaining('fictional reports'), findsNothing);
      expect(find.text('Fictional reportable Memory'), findsOneWidget);
      await tester.tap(find.text('Hide content'));
      await settle(tester);
      expect(server.hiddenMemories, contains(memory));
      await tester.tap(find.text('Restore content'));
      await settle(tester);
      expect(server.hiddenMemories, isEmpty);
      await tester.tap(find.text('Dismiss reports'));
      await settle(tester);
      expect(find.text('Nothing to review'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(find.text('Fictional reportable Memory'), findsOneWidget);
      expect(server.moderationAudit, hasLength(4));
      expect(tester.takeException(), isNull);
      final page = c
          .read(safetyPageProvider((group: '$group', offset: 0)))
          .value!;
      server.members[group]![owner] = 'member';
      server.groups[group]!['owner_user_id'] = 9999;
      final refresh = controller.refresh();
      await settle(tester);
      await refresh;
      await expectLater(
        c.read(safetyActionsProvider).act(page, page.items.single, 'hide'),
        throwsA(isA<CircleFailure>()),
      );
      expect(find.text('Reports are for admins'), findsOneWidget);
    },
  );
  for (final width in [320.0, 900.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('private reports $width ${brightness.name} at 200% text', (
        tester,
      ) async {
        final server = FakeCircleServer();
        final owner = server.addUser(
          '+9995550000792',
          'fictional password',
          'Owner',
        );
        final group = server.addGroup('Fictional safety group', owner);
        server.moderationCases.add({
          'id': 100,
          'group_id': group,
          'kind': 'memory',
          'target_id': 10,
          'version': 2,
          'updated_at': FakeCircleServer.now,
          'summary': 'A fictional reported Memory for review.',
          'hidden': false,
          'available': true,
          'reasons': [
            {'reason': 'spam', 'count': 2},
          ],
        });
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
        c.read(circleRouterProvider).go('/groups/g/$group/reports');
        await settle(tester);
        expect(find.text('Hide content'), findsOneWidget);
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
              '/tmp/circle-safety-$width-${brightness.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            capture.dispose();
          });
        }
      });
    }
  }
}
