import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/circle_brand.dart';

void main() {
  testWidgets(
    'welcome uses the supplied complete identity with an accessible label',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CircleBrand())),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image).first);
      expect((image.image as AssetImage).assetName, CircleIdentity.artwork);
      expect(image.semanticLabel, 'CIRCLE. MY CIRCLE. BILLION MEMORIES.');
      expect(find.text('PRIVATE GROUPS. SHARED MEMORIES.'), findsNothing);
      expect(File(CircleIdentity.artwork).existsSync(), isTrue);
    },
  );
}
