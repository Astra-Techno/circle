import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/circle_components.dart';
import 'package:mobile/core/design.dart';
import 'package:mobile/app/circle_experience.dart';
import 'support/circle_harness.dart';

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
      expect(find.byTooltip('New group'), findsOneWidget);
      expect(find.text('My Circle. Billion Memories.'), findsNothing);
    },
  );

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
