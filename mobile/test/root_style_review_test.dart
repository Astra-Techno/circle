import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/theme_controller.dart';
import 'support/root_style_fixture.dart';
import 'support/server_harness.dart';

void main() {
  for (final layout in [
    (393.0, 852.0, 1.0, Brightness.light),
    (393.0, 852.0, 1.0, Brightness.dark),
    (320.0, 1000.0, 2.0, Brightness.dark),
    (900.0, 1100.0, 1.0, Brightness.light),
    (900.0, 1100.0, 2.0, Brightness.dark),
  ]) {
    testWidgets('root style ${layout.$1} ${layout.$3} ${layout.$4.name}', (
      tester,
    ) async {
      final fixture = RootStyleFixture();
      final container = await openServerCircle(
        tester,
        fixture.server,
        tokens: await storedSession(fixture.server, fixture.owner),
        size: Size(layout.$1, layout.$2),
      );
      tester.platformDispatcher.textScaleFactorTestValue = layout.$3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      container
          .read(themeProvider.notifier)
          .change(
            layout.$4 == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          );
      for (final page in ['chats', 'groups', 'events', 'you']) {
        container.read(circleRouterProvider).go('/$page');
        await settle(tester);
        expect(tester.takeException(), isNull, reason: page);
        expect(find.byTooltip('Home'), findsOneWidget);
        if (page == 'chats') {
          expect(find.text('Fictional live circle'), findsOneWidget);
          expect(find.textContaining('Looking forward'), findsOneWidget);
          expect(find.byTooltip('New chat'), findsOneWidget);
          if (layout.$1 == 320 && layout.$3 == 2) {
            final name = find.text('Fictional live circle');
            final style = tester.widget<Text>(name).style!;
            final singleLine = style.fontSize! * style.height! * layout.$3;
            expect(tester.getSize(name).height, greaterThan(singleLine));
          }
        }
        if (page == 'events') {
          expect(find.text('Fictional picnic'), findsOneWidget);
        }
        if (page == 'you') {
          expect(find.text('Edit profile'), findsOneWidget);
        }
        if (Platform.environment['CIRCLE_CAPTURE_ROOT_STYLE'] == 'true') {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byType(RepaintBoundary).first,
            );
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = Directory(
              '../docs/design-previews/home-style-rollout',
            );
            await directory.create(recursive: true);
            await File(
              '${directory.path}/$page-${layout.$1.toInt()}-${layout.$3}-${layout.$4.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
