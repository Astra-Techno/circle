import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:mobile/features/profile/presentation/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'support/circle_harness.dart';
import 'support/server_harness.dart';
import 'live_chat_events_test.dart' show LiveFixture;

void main() {
  testWidgets('group chat route uses full-screen conversation chrome', (
    tester,
  ) async {
    final fixture = LiveFixture();
    final container = await openServerCircle(
      tester,
      fixture.server,
      tokens: await storedSession(fixture.server, fixture.owner),
    );
    container.read(circleRouterProvider).go('/chats/g/${fixture.group}');
    await settle(tester);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Profile'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'subgroup creation remains reachable with keyboard and large text',
    (tester) async {
      final container = await openCircle(
        tester,
        size: const Size(320, 700),
        scale: 2,
      );
      container.read(circleRouterProvider).go('/groups/g/friends');
      await tester.pumpAndSettle();
      final create = find
          .widgetWithText(OutlinedButton, 'Create Circle')
          .first;
      await reveal(tester, create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Circle name'), findsOneWidget);
      final submit = find.widgetWithText(FilledButton, 'Create Circle');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(submit.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets('footer stays compact with iPhone inset ${brightness.name}', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(() {
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });
      await openCircle(tester, brightness: brightness);
      final surface = find
          .ancestor(of: find.text('Home'), matching: find.byType(DecoratedBox))
          .first;
      final bounds = tester.getRect(surface);
      if (Platform.environment['CIRCLE_CAPTURE_COMPACT_FOOTER'] == 'true') {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first,
          );
          final frame = await boundary.toImage();
          final bytes = await frame.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('../docs/design-previews/compact-footer');
          await directory.create(recursive: true);
          final phase = Platform.environment['CIRCLE_FOOTER_PHASE'] ?? 'after';
          await File(
            '${directory.path}/$phase-${brightness.name}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          frame.dispose();
        });
      }
      expect(bounds.bottom, 852);
      expect(bounds.height, lessThanOrEqualTo(64));
      final homeIcon = tester.getRect(find.byIcon(LucideIcons.house).last);
      final profileAvatar = find
          .descendant(
            of: find.byType(PersonAvatar),
            matching: find.byType(CircleAvatar),
          )
          .last;
      expect(tester.getRect(profileAvatar).center.dy, homeIcon.center.dy);
      expect(tester.widget<Text>(find.text('Home')).style!.fontSize, 11);
      final label = tester.getRect(find.text('Home'));
      expect(homeIcon.center.dx, label.center.dx);
      expect(
        (homeIcon.top + label.bottom + 4) / 2,
        closeTo(bounds.center.dy, 1),
      );
      final labelBottom = tester.getRect(find.text('Home')).bottom;
      expect(852 - labelBottom, inInclusiveRange(12, 20));
      final decoration =
          tester.widget<DecoratedBox>(surface).decoration as BoxDecoration;
      final theme = Theme.of(tester.element(find.text('Home')));
      expect(decoration.color, theme.colorScheme.surface);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
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
  testWidgets('dock opens Chats and Home composer remains available', (
    tester,
  ) async {
    final fixture = LiveFixture();
    final container = await openServerCircle(
      tester,
      fixture.server,
      tokens: await storedSession(fixture.server, fixture.owner),
    );
    expect(find.text('Events'), findsOneWidget);
    await tester.tap(find.text('Chats'));
    await settle(tester);
    final router = container.read(circleRouterProvider);
    expect(router.routeInformationProvider.value.uri.path, '/chats');
    expect(find.text('Fictional live circle'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await settle(tester);
    await tester.tap(find.text('Share a memory…'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Create Memory'), findsOneWidget);
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
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
    expect(find.text('Home'), findsOneWidget);
  });
}
