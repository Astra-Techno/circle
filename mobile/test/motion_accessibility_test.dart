import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/design/circle_motion.dart';

void main() {
  testWidgets(
    'reduced motion renders content immediately despite entrance delay',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: CircleFadeIn(
              delay: Duration(seconds: 10),
              child: Text('Ready'),
            ),
          ),
        ),
      );
      expect(find.text('Ready').hitTestable(), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CircleFadeIn),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
