import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps every screen on the "Warm Keepsake" design system
/// (docs/design-system.md). Colours, fonts, radii and spacing come from
/// `lib/core/`; feature code may not invent its own.
// The only places allowed to define raw design values.
const tokenFiles = {'lib/core/design.dart'};
const kitFiles = {'lib/core/design.dart', 'lib/core/circle_components.dart'};

/// The single, intentional exception for network images: the kit widget
/// that shows private photos from the CIRCLE media API. It only accepts a
/// `SignedMediaUrl`, which can only be built from a `/media/files/…` path
/// on the configured API server (ADR 0007). Every other file stays on
/// bundled, fictional or in-memory images.
const signedImageFiles = {'lib/core/circle_signed_image.dart'};

final rules = <({String name, RegExp pattern, Set<String> allowedIn})>[
  (
    name: 'hex colour (use ColorScheme or CircleAccents)',
    pattern: RegExp(r'Color\(0x'),
    allowedIn: tokenFiles,
  ),
  (
    name: 'Colors.* (use ColorScheme or CircleAccents)',
    pattern: RegExp(r'\bColors\.(?!transparent\b)'),
    allowedIn: tokenFiles,
  ),
  (
    name: 'font size or family (use Theme.textTheme)',
    pattern: RegExp(r'\bfont(Size|Family)\s*:'),
    allowedIn: tokenFiles,
  ),
  (
    name: 'numeric corner radius (use CircleRadius)',
    pattern: RegExp(r'Radius\.circular\(\s*\d'),
    allowedIn: tokenFiles,
  ),
  (
    name: 'gradient (use shared CircleDepth tokens)',
    pattern: RegExp(r'\b(Linear|Radial|Sweep)Gradient\('),
    allowedIn: tokenFiles,
  ),
  (
    name: 'raw CircleAvatar (use CircleInitialAvatar)',
    pattern: RegExp(r'\bCircleAvatar\('),
    allowedIn: kitFiles,
  ),
  (
    name:
        'remote image (bundle fictional assets, or show API photos with '
        'CircleSignedImage)',
    pattern: RegExp(r'\b(Image\.network|NetworkImage)\('),
    allowedIn: signedImageFiles,
  ),
  (
    name: 'numeric padding (use Space, CircleInsets)',
    pattern: RegExp(r'EdgeInsets[\w.]*\([^)]*?(?<![\w.])[1-9]\d*(\.\d+)?\b'),
    allowedIn: tokenFiles,
  ),
];

/// Rule violations in [lines] of the file at [path] (forward slashes).
List<String> violationsIn(String path, List<String> lines) {
  final violations = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('//')) continue;
    for (final rule in rules) {
      if (rule.allowedIn.contains(path)) continue;
      if (rule.pattern.hasMatch(line)) {
        violations.add('$path:${i + 1}  ${rule.name}\n    ${line.trim()}');
      }
    }
  }
  return violations;
}

void main() {
  final sources =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('feature code uses design tokens, not raw values', () {
    expect(sources, isNotEmpty);
    final violations = <String>[
      for (final file in sources)
        ...violationsIn(
          file.path.replaceAll(r'\', '/'),
          file.readAsLinesSync(),
        ),
    ];
    expect(
      violations,
      isEmpty,
      reason:
          'Use the shared design system (docs/design-system.md):\n'
          '${violations.join('\n')}',
    );
  });

  group('network images', () {
    const network = [
      "child: Image.network('https://example.org/a.jpg'),",
      "image: NetworkImage(url),",
    ];

    test('are refused everywhere except CircleSignedImage', () {
      for (final path in [
        'lib/features/memories/presentation/memory_photos.dart',
        'lib/core/circle_components.dart',
        'lib/core/design.dart',
        'lib/core/api/signed_media_url.dart',
        'lib/app/circle_experience.dart',
      ]) {
        expect(
          violationsIn(path, network),
          hasLength(2),
          reason: '$path must not load network images',
        );
      }
      expect(
        violationsIn('lib/core/circle_signed_image.dart', network),
        isEmpty,
      );
    });

    test('the exception is exactly one file, and it exists', () {
      expect(signedImageFiles, hasLength(1));
      final users = [
        for (final file in sources)
          if (file.readAsStringSync().contains(
            RegExp(r'\b(Image\.network|NetworkImage)\('),
          ))
            file.path.replaceAll(r'\', '/'),
      ];
      expect(users, ['lib/core/circle_signed_image.dart']);
    });

    test('CircleSignedImage only takes a SignedMediaUrl', () {
      final widget = File(
        'lib/core/circle_signed_image.dart',
      ).readAsStringSync();
      expect(widget, contains('final SignedMediaUrl url;'));
      expect(widget, isNot(contains('String url')));
      expect(widget, isNot(contains('Uri url')));
    });
  });

  test('every screen gets the theme from circleTheme()', () {
    final app = File('lib/app/circle_experience.dart').readAsStringSync();
    expect(app, contains('theme: circleTheme(Brightness.light)'));
    expect(app, contains('darkTheme: circleTheme(Brightness.dark)'));
  });
}
