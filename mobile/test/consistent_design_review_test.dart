import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/design.dart';
import 'package:mobile/core/design/circle_typography.dart';
import 'package:mobile/core/theme_controller.dart';
import 'support/root_style_fixture.dart';
import 'support/server_harness.dart';

void main() {
  test('theme and explicit text roles use one bundled font and hierarchy', () {
    for (final brightness in Brightness.values) {
      final theme = circleTheme(brightness);
      final ink = theme.colorScheme.onSurface;
      final body = theme.textTheme.bodyMedium!;
      final role = CircleTextStyles.body(ink);
      expect(body.fontSize, role.fontSize);
      expect(body.fontWeight, role.fontWeight);
      expect(body.height, role.height);
      expect(
        theme.textTheme.titleLarge!.fontSize,
        CircleTextStyles.pageTitle(ink).fontSize,
      );
      expect(CircleTextStyles.homeBody(ink), CircleTextStyles.body(ink));
      expect(CircleTextStyles.homeAuthor(ink), CircleTextStyles.cardTitle(ink));
      expect(theme.textTheme.bodyMedium!.fontFamily, 'Roboto');
    }
  });

  for (final layout in [
    (393.0, 852.0, 1.0, Brightness.light),
    (393.0, 852.0, 1.0, Brightness.dark),
    (320.0, 1000.0, 2.0, Brightness.dark),
    (900.0, 1100.0, 2.0, Brightness.light),
  ]) {
    testWidgets(
      'shared design routes ${layout.$1} ${layout.$3} ${layout.$4.name}',
      (tester) async {
        final fixture = RootStyleFixture();
        final memory = fixture.server.addMemory(
          fixture.group,
          fixture.owner,
          fixture.messages.first['body'] as String,
        );
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
        final group = fixture.group;
        for (final route in [
          '/home',
          '/home/memory/$memory',
          '/compose?group=$group',
          '/chats',
          '/chats/new',
          '/chats/privacy',
          '/chats/c/501',
          '/groups',
          '/groups/new',
          '/groups/g/$group',
          '/groups/g/$group/settings',
          '/groups/g/$group/invite',
          '/groups/g/$group/invite/link',
          '/events',
          '/events/new?group=$group',
          '/events/e/91',
          '/events/e/91/edit',
          '/events/e/91/attendees',
          '/you',
          '/you/edit',
          '/you/privacy',
          '/you/invitations',
          '/you/account',
          '/you/account/password',
          '/you/account/sessions',
          '/search',
          '/people/${fixture.member}',
        ]) {
          container.read(circleRouterProvider).go(route);
          // Some fake endpoints intentionally show loading/error states.
          // Bound capture time rather than waiting for a spinner to stop.
          for (var frame = 0; frame < 12; frame++) {
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(
            container
                .read(circleRouterProvider)
                .routeInformationProvider
                .value
                .uri
                .path,
            Uri.parse(route).path,
            reason: route,
          );
          expect(tester.takeException(), isNull, reason: route);
          final scaffold = find.byType(Scaffold).first;
          ScaffoldMessenger.of(tester.element(scaffold)).clearSnackBars();
          await tester.pump(const Duration(milliseconds: 500));
          if (Platform.environment['CIRCLE_CAPTURE_DESIGN'] == 'true') {
            await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byType(RepaintBoundary).first,
              );
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final directory = Directory(
                '../docs/design-previews/social-system',
              );
              await directory.create(recursive: true);
              final name = route.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-');
              await File(
                '${directory.path}/$name-${layout.$1.toInt()}-${layout.$3}-${layout.$4.name}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
