import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'support/circle_harness.dart' show openCircle;
import 'support/server_harness.dart';
import 'support/fake_api.dart';

void main() {
  testWidgets(
    'authorized server invite exposes external sharing after link creation',
    (tester) async {
      final server = FakeCircleServer();
      final owner = server.addUser(
        '+15550000001',
        'fictional-password',
        'Fictional Owner',
      );
      final group = server.addGroup('Fictional Group', owner);
      final container = await openServerCircle(
        tester,
        server,
        tokens: await storedSession(server, owner),
      );
      container.read(circleRouterProvider).go('/groups/g/$group/invite');
      await settle(tester);
      await tester.tap(find.text('Create invite link'));
      await settle(tester);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('More apps'), findsOneWidget);
    },
  );
  testWidgets('fictional preview never opens real contact/share controls', (
    tester,
  ) async {
    final container = await openCircle(tester);
    container.read(circleRouterProvider).go('/groups/g/club/invite');
    await tester.pumpAndSettle();
    expect(find.text('Copy preview link'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('SMS'), findsNothing);
  });
}
