import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('fictional circles to a new group-scoped Memory on device', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Explore fictional circles'));
    await tester.tap(find.text('Explore fictional circles'));
    await tester.pumpAndSettle();
    expect(find.text('Memories'), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Groups'));
    await tester.pumpAndSettle();
    expect(find.text('Your kind\nof company.'), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Memory'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Our first shared moment.');
    await tester.ensureVisible(find.text('Share Memory'));
    await tester.tap(find.text('Share Memory'));
    await tester.pumpAndSettle();
    expect(find.text('Our first shared moment.'), findsOneWidget);
  });
}
