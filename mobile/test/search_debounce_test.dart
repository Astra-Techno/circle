import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'support/server_harness.dart';
import 'live_chat_events_test.dart' show LiveFixture;

void main() {
  testWidgets('typing sends only the settled remote Memory query', (
    tester,
  ) async {
    final fixture = LiveFixture();
    final c = await openServerCircle(
      tester,
      fixture.server,
      tokens: await storedSession(fixture.server, fixture.owner),
    );
    c.read(circleRouterProvider).go('/search');
    await settle(tester);
    final field = find.byKey(const ValueKey('search-field'));
    for (final text in ['pa', 'par', 'party']) {
      await tester.enterText(field, text);
      await tester.pump(const Duration(milliseconds: 80));
    }
    final requests = fixture.server.adapter.requests;
    expect(
      requests.where((r) => r.path == '/memories' && r.query.containsKey('q')),
      isEmpty,
    );
    await tester.pump(const Duration(milliseconds: 320));
    await settle(tester);
    expect(
      requests
          .where((r) => r.path == '/memories' && r.query.containsKey('q'))
          .map((r) => r.query['q']),
      ['party'],
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
