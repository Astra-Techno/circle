import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/local_settings.dart';
import 'support/fake_api.dart';
import 'support/circle_harness.dart' show reveal, currentUri;
import 'support/server_harness.dart';

void main() {
  testWidgets(
    'server composer offers recovery, resumes text and flushes on exit',
    (tester) async {
      final server = FakeCircleServer();
      final user = server.addUser(
        '+9995550000191',
        'fictional password',
        'Fictional Tester',
      );
      final group = server.addGroup('Fictional family', user);
      final storage = MemoryLocalSettingsStore();
      final drafts = MemoryDraftStore(storage);
      final scope = DraftScope(
        server: testServer.baseUrl.toString(),
        account: '$user',
      );
      await drafts.save(
        drafts.open(scope),
        MemoryTextDraft(
          text: 'A recovered fictional moment',
          groupId: '$group',
          year: '2024',
          place: 'Fictional garden',
        ),
      );
      final container = await openServerCircle(
        tester,
        server,
        tokens: await storedSession(server, user),
        settings: storage,
      );
      container.read(circleRouterProvider).go('/compose?group=$group');
      await settle(tester);
      expect(find.text('Resume draft'), findsOneWidget);
      expect(
        find.textContaining('Photos must be selected again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Resume draft'));
      await settle(tester);
      expect(find.text('A recovered fictional moment'), findsOneWidget);
      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Your Memory',
      );
      await tester.enterText(field, 'An edited fictional moment');
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester);
      container.read(circleRouterProvider).go('/home');
      await settle(tester);
      container.read(circleRouterProvider).go('/compose?group=$group');
      await settle(tester);
      await tester.tap(find.text('Resume draft'));
      await settle(tester);
      expect(find.text('An edited fictional moment'), findsOneWidget);
      await reveal(tester, find.text('Share Memory'));
      await tester.tap(find.text('Share Memory'));
      await settle(tester);
      expect(currentUri(container).path, '/home');
      final afterShare = MemoryDraftStore(storage);
      expect(
        await afterShare.read(afterShare.open(scope), groupId: '$group'),
        isNull,
      );
    },
  );
  testWidgets('discarded draft is not offered on returning to composer', (
    tester,
  ) async {
    final server = FakeCircleServer();
    final user = server.addUser(
      '+9995550000192',
      'fictional password',
      'Fictional Tester',
    );
    final group = server.addGroup('Fictional group', user);
    final storage = MemoryLocalSettingsStore();
    final drafts = MemoryDraftStore(storage);
    final scope = DraftScope(
      server: testServer.baseUrl.toString(),
      account: '$user',
    );
    await drafts.save(
      drafts.open(scope),
      MemoryTextDraft(text: 'Discard this fictional draft', groupId: '$group'),
    );
    final container = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, user),
      settings: storage,
    );
    container.read(circleRouterProvider).go('/compose?group=$group');
    await settle(tester);
    await tester.tap(find.text('Discard draft'));
    await settle(tester);
    expect(find.text('Discard this fictional draft'), findsNothing);
    container.read(circleRouterProvider).go('/home');
    await settle(tester);
    container.read(circleRouterProvider).go('/compose?group=$group');
    await settle(tester);
    expect(find.text('Resume draft'), findsNothing);
  });
}
