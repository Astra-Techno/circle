import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('fictional circles: accept an invitation, then share a Memory', (
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
    expect(find.text('Invitations for you'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Accept invitation to Board games'));
    await tester.pumpAndSettle();
    expect(find.text('You joined Board games.'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Sunday miles'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sunday miles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Memory'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Your Memory'),
      'Our first shared moment.',
    );
    await tester.ensureVisible(find.text('Share Memory'));
    await tester.tap(find.text('Share Memory'));
    await tester.pumpAndSettle();
    expect(find.text('Our first shared moment.'), findsOneWidget);
  });
}
