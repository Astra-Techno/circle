import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'support/circle_harness.dart';

void main() {
  for (final layout in [
    (393.0, 1.0, Brightness.light),
    (320.0, 2.0, Brightness.dark),
    (900.0, 2.0, Brightness.dark),
  ]) {
    testWidgets('root chrome ${layout.$1} ${layout.$2} ${layout.$3.name}', (
      tester,
    ) async {
      final container = await openCircle(
        tester,
        size: Size(layout.$1, 950),
        scale: layout.$2,
        brightness: layout.$3,
      );
      for (final route in ['/home', '/groups', '/you']) {
        container.read(circleRouterProvider).go(route);
        await tester.pumpAndSettle();
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
              '/tmp/circle-chrome-${route.substring(1)}-${layout.$1}-${layout.$2}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('reference dock offers Events and opens composer', (
    tester,
  ) async {
    await openCircle(tester);
    expect(find.byTooltip('Events'), findsWidgets);
    expect(find.byTooltip('Photos'), findsNothing);
    await tester.tap(find.byTooltip('Create Memory').last);
    await tester.pumpAndSettle();
    expect(find.text('New Memory'), findsOneWidget);
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Chats'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('accessible navigation stays visible while scrolling', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await openCircle(tester);
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Create Memory'), findsWidgets);
  });
}
