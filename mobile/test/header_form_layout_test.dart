import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/circle_components.dart';
import 'package:mobile/core/design.dart';
import 'package:mobile/app/circle_experience.dart';
import 'support/circle_harness.dart';
import 'support/root_style_fixture.dart';
import 'support/server_harness.dart';
import 'screen_audit_visual_review_test.dart' show capture;

void main() {
  testWidgets(
    'Home header has two actions, no tagline and supported shortcuts',
    (tester) async {
      final container = await openCircle(tester);
      expect(find.text('My Circle. Billion Memories.'), findsNothing);
      expect(find.byType(CircleHeaderAction), findsNWidgets(2));
      expect(find.text('Share a memory…'), findsOneWidget);
      expect(find.text('Video'), findsNothing);
      container.read(circleRouterProvider).go('/groups');
      await tester.pumpAndSettle();
      expect(find.text('Circles'), findsWidgets);
      expect(find.byTooltip('New Circle'), findsOneWidget);
      expect(find.text('My Circle. Billion Memories.'), findsNothing);
    },
  );

  for (final layout in [
    (393.0, 844.0, 1.0, Brightness.light),
    (393.0, 844.0, 1.0, Brightness.dark),
    (320.0, 1000.0, 2.0, Brightness.dark),
    (900.0, 1100.0, 2.0, Brightness.light),
  ]) {
    testWidgets(
      'selected Home concept ${layout.$1} ${layout.$3} ${layout.$4.name}',
      (tester) async {
        final c = await openCircle(
          tester,
          size: Size(layout.$1, layout.$2),
          scale: layout.$3,
          brightness: layout.$4,
        );
        final actions = tester.widgetList<CircleHeaderAction>(
          find.byType(CircleHeaderAction),
        );
        expect(actions.length, 2);
        expect(actions.every((a) => !a.tonal), isTrue);
        for (final label in ['Search', 'Activity']) {
          final rect = tester.getRect(find.byTooltip(label));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.width, greaterThanOrEqualTo(48));
        }
        expect(tester.widget<Text>(find.text('Circle')).style!.fontSize, 24);
        await capture(
          tester,
          'selected-home-header',
          '${layout.$1.toInt()}-${layout.$3}-${layout.$4.name}',
        );
        await go(tester, c, '/groups');
        expect(
          tester
              .widgetList<CircleHeaderAction>(find.byType(CircleHeaderAction))
              .every((a) => !a.tonal),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('selected Home header actions retain their real destinations', (
    tester,
  ) async {
    final fixture = RootStyleFixture();
    final c = await openServerCircle(
      tester,
      fixture.server,
      tokens: await storedSession(fixture.server, fixture.owner),
    );
    final routes = <(Finder, String)>[
      (find.byTooltip('Search'), '/search'),
      (find.byTooltip('Activity'), '/activity'),
      (find.text('Share a memory…'), '/compose'),
      (find.byTooltip('Photo'), '/compose'),
      (find.byTooltip('Event'), '/events/new'),
      (find.byTooltip('Poll'), '/polls/new'),
    ];
    for (final entry in routes) {
      await go(tester, c, '/home');
      await tester.tap(entry.$1);
      await tester.pumpAndSettle();
      expect(currentUri(c).path, entry.$2);
      expect(tester.takeException(), isNull);
    }
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('fields keep size, spacing and error room at scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: circleTheme(Brightness.light),
          home: Scaffold(
            body: CircleEditorLayout(
              children: [
                DropdownButtonFormField<int>(
                  initialValue: 1,
                  decoration: const InputDecoration(labelText: 'Choice'),
                  items: const [DropdownMenuItem(value: 1, child: Text('One'))],
                  onChanged: (_) {},
                ),
                const TextField(decoration: InputDecoration(labelText: 'Name')),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Details',
                    errorText:
                        'An explanation that needs room when text grows.',
                  ),
                ),
                FilledButton(onPressed: () {}, child: const Text('Save')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(InputDecorator);
      final first = tester.getRect(fields.at(0));
      final second = tester.getRect(fields.at(1));
      expect(first.height, greaterThanOrEqualTo(56));
      expect(second.height, greaterThanOrEqualTo(56));
      expect(second.top - first.bottom, greaterThanOrEqualTo(16));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
