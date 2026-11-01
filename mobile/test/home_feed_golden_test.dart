import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/circle_harness.dart';

/// Renders the production Home Feed at the reference viewport (iPhone 15 Pro)
/// and captures golden screenshots for visual comparison.
///
/// Run with:
///   flutter test test/home_feed_golden_test.dart --update-goldens
///
/// Then copy the golden to the comparison directory:
///   copy test\goldens\home_feed_393x852.png design_reference\output\home_feed_actual.png
void main() {
  testWidgets('Home Feed light at 393x852', (tester) async {
    final fixed = DateTime(2026, 10, 15, 14, 30);
    await openCircle(tester, now: fixed, size: const Size(393, 852));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_feed_393x852.png'),
    );
  });

  testWidgets('Home Feed dark at 393x852', (tester) async {
    final fixed = DateTime(2026, 10, 15, 14, 30);
    await openCircle(
      tester,
      now: fixed,
      size: const Size(393, 852),
      brightness: Brightness.dark,
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_feed_dark_393x852.png'),
    );
  });
}
