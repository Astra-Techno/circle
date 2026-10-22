import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('invitation to feed and a new memory on device', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enter with an invitation'));
    await tester.tap(find.text('Enter with an invitation'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'CIRCLE-DEMO');
    await tester.ensureVisible(find.text('Open my circle'));
    await tester.tap(find.text('Open my circle'));
    await tester.pumpAndSettle();
    expect(find.text('Good to be together.'), findsOneWidget);
    await tester.tap(find.text('Share a memory'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Our first campus walk.',
    );
    await tester.ensureVisible(find.text('Share with my circle'));
    await tester.tap(find.text('Share with my circle'));
    await tester.pumpAndSettle();
    expect(find.text('Our first campus walk.'), findsOneWidget);
  });
}
