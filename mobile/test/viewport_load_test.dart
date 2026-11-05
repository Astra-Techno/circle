import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/viewport_load.dart';

void main() {
  testWidgets(
    'nested shrink-wrap grids defer off-screen loading until scrolled into view',
    (tester) async {
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 1400),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    children: [
                      CircleViewportLoad(
                        placeholder: const Text('Deferred'),
                        builder: (_) {
                          loads++;
                          return const Text('Loaded');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(loads, 0);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1500),
      );
      await tester.pumpAndSettle();
      expect(find.text('Loaded'), findsOneWidget);
      expect(loads, greaterThan(0));
    },
  );
}
