import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/circle_harness.dart';

/// Renders the Home Feed at each blueprint viewport (§16.7) and captures
/// golden screenshots. No emulator required.
///
/// Run with:
///   flutter test test/responsive_golden_test.dart --update-goldens
void main() {
  final fixed = DateTime(2026, 10, 15, 14, 30);

  const viewports = <(String, Size)>[
    ('360x800', Size(360, 800)),
    ('393x852', Size(393, 852)),
    ('430x932', Size(430, 932)),
    ('600x960', Size(600, 960)),
    ('800x1280', Size(800, 1280)),
    ('1024x768', Size(1024, 768)),
    ('1280x800', Size(1280, 800)),
  ];

  for (final (label, size) in viewports) {
    testWidgets('Home Feed at $label', (tester) async {
      await openCircle(tester, now: fixed, size: size);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/responsive_home_$label.png'),
      );
    });
  }
}
