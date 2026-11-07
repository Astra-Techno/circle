import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/circle_components.dart';
import 'package:mobile/core/design.dart';
import 'package:mobile/features/events/presentation/live_events.dart';
import 'support/root_style_fixture.dart';
import 'support/server_harness.dart';

void main() {
  test(
    'enabled input boundaries contrast with all their semantic surfaces',
    () {
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05);
      }

      for (final brightness in Brightness.values) {
        final theme = circleTheme(brightness);
        final accents = theme.extension<CircleAccents>()!;
        final boundaries = [
          theme.radioTheme.fillColor!.resolve({})!,
          theme.checkboxTheme.side!.color,
          theme.inputDecorationTheme.enabledBorder!.borderSide.color,
        ];
        for (final boundary in boundaries) {
          for (final surface in [
            theme.colorScheme.surface,
            accents.recessed,
            accents.calmContainer,
          ]) {
            expect(
              contrast(boundary, surface),
              greaterThanOrEqualTo(3),
              reason: '$brightness: $boundary on $surface',
            );
          }
        }
        expect(accents.controlOutline, isNot(accents.hairline));
      }
    },
  );

  testWidgets('child page paints over Circle actions after push and back', (
    tester,
  ) async {
    final fixture = RootStyleFixture();
    final c = await openServerCircle(
      tester,
      fixture.server,
      tokens: await storedSession(fixture.server, fixture.owner),
    );
    final router = c.read(circleRouterProvider);
    router.go('/groups/g/${fixture.group}');
    await settle(tester);
    router.push('/groups/g/${fixture.group}/events');
    await settle(tester);
    await tester.pump(const Duration(seconds: 5));
    final card = tester.getRect(find.byType(LiveEventCard).first);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await tester.runAsync(() => boundary.toImage());
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final x = (card.left + Space.md).round(),
        y = (card.bottom + Space.section).round();
    final offset = (y * image!.width + x) * 4;
    expect(
      bytes!.getUint8(offset),
      255,
      reason: 'Previous Circle tile must not paint below the event card',
    );
    expect(bytes.getUint8(offset + 1), 255);
    expect(bytes.getUint8(offset + 2), 255);
    image.dispose();
    router.pop();
    await settle(tester);
    expect(find.text('Chat'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'persistent long labels wrap and preserve editable semantics at 200%',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: circleTheme(Brightness.light),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: ListView(
                padding: CircleInsets.form,
                children: const [
                  CircleFieldLabel(
                    label: 'Confirm your new password',
                    child: TextField(obscureText: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.text('Confirm your new password')).height,
        greaterThan(40),
      );
      expect(find.bySemanticsLabel('Confirm your new password'), findsWidgets);
      await tester.enterText(find.byType(TextField), 'fictional-long-password');
      expect(find.text('Confirm your new password'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  test('invitation detail gets an invitation title', () {
    expect(
      circleDetailTitle('/you/invitations/12', 'Profile'),
      'Circle Invitations',
    );
  });
}
