import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/circle_harness.dart' show currentUri, reveal;
import 'support/fake_api.dart';
import 'support/server_harness.dart';

void main() {
  testWidgets('You hides connection details and provides useful destinations', (
    tester,
  ) async {
    final server = FakeCircleServer();
    final user = server.addUser(
      '+9991234567890',
      'fictional password',
      'Fictional Tester',
    );
    final container = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, user),
    );
    await tester.tap(find.widgetWithText(NavigationDestination, 'You'));
    await settle(tester);
    await settle(tester);
    expect(find.text('Preview'), findsNothing);
    expect(find.textContaining('circle.test'), findsNothing);
    expect(find.byKey(const ValueKey('you-profile-card')), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    await reveal(tester, find.text('Browse Memories'));
    await tester.tap(find.text('Browse Memories'));
    await settle(tester);
    expect(currentUri(container).path, '/home');
    await tester.tap(find.widgetWithText(NavigationDestination, 'You'));
    await settle(tester);
    await reveal(tester, find.text('Account'));
    await tester.tap(find.text('Account'));
    await settle(tester);
    await reveal(tester, find.text('Connection details'));
    await tester.tap(find.text('Connection details'));
    await settle(tester);
    await reveal(tester, find.text('circle.test'));
    expect(find.text('circle.test'), findsOneWidget);
  });

  testWidgets('Edit profile validates and persists the saved Unicode name', (
    tester,
  ) async {
    final server = FakeCircleServer();
    final user = server.addUser(
      '+9991234567891',
      'fictional password',
      'Fictional Tester',
    );
    final tokens = await storedSession(server, user);
    final container = await openServerCircle(tester, server, tokens: tokens);
    await tester.tap(find.widgetWithText(NavigationDestination, 'You'));
    await settle(tester);
    await tester.tap(find.text('Edit profile'));
    await settle(tester);
    final field = find.byKey(const ValueKey('profile-display-name'));
    await tester.enterText(field, '  ');
    await tester.tap(find.text('Save changes'));
    await settle(tester);
    expect(find.text('Enter the name people know you by.'), findsOneWidget);
    expect(server.adapter.count('PATCH', '/me'), 0);
    await tester.enterText(field, '  Fictional தமிழ்  ');
    await tester.tap(find.text('Save changes'));
    await settle(tester);
    expect(currentUri(container).path, '/you');
    expect(find.text('Fictional தமிழ்'), findsOneWidget);
    expect(
      container.read(serverAccountProvider)?.displayName,
      'Fictional தமிழ்',
    );
    expect((await tokens.read())?.account?.displayName, 'Fictional தமிழ்');
    expect(server.users[user]!['display_name'], 'Fictional தமிழ்');
    expect(server.adapter.count('PATCH', '/me'), 1);
  });

  testWidgets('Failed profile save keeps the old name and allows retry', (
    tester,
  ) async {
    final server = FakeCircleServer();
    final user = server.addUser(
      '+9991234567892',
      'fictional password',
      'Fictional Tester',
    );
    final container = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, user),
    );
    final original = server.adapter.handler;
    var fail = true;
    server.adapter.handler = (r) =>
        r.method == 'PATCH' && r.path == '/me' && fail
        ? FakeResponse.error(500, 'server_error')
        : original(r);
    await tester.tap(find.widgetWithText(NavigationDestination, 'You'));
    await settle(tester);
    await tester.tap(find.text('Edit profile'));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('profile-display-name')),
      'Fictional Updated',
    );
    await tester.tap(find.text('Save changes'));
    await settle(tester);
    expect(currentUri(container).path, '/you/edit');
    expect(find.textContaining('Raw server text'), findsNothing);
    expect(
      container.read(serverAccountProvider)?.displayName,
      'Fictional Tester',
    );
    fail = false;
    await tester.tap(find.text('Save changes'));
    await settle(tester);
    expect(currentUri(container).path, '/you');
    expect(
      container.read(serverAccountProvider)?.displayName,
      'Fictional Updated',
    );
  });

  testWidgets('You remains usable on a narrow phone at 200 percent text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final server = FakeCircleServer();
    final user = server.addUser(
      '+9991234567893',
      'fictional password',
      'Fictional Long Profile Name',
    );
    await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, user),
      size: const Size(360, 800),
    );
    await tester.tap(find.widgetWithText(NavigationDestination, 'You'));
    await settle(tester);
    await reveal(tester, find.text('Browse Memories'));
    expect(tester.takeException(), isNull);
  });
}
