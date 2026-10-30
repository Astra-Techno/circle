import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/circle_components.dart';
import 'support/fake_api.dart';
import 'support/server_harness.dart';

void main() {
  testWidgets('profile route exit keeps edits until discard is confirmed', (
    tester,
  ) async {
    final server = FakeCircleServer();
    final user = server.addUser(
      '+15559990103',
      'fictional-password',
      'Edit Person',
    );
    final c = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, user),
    );
    final router = c.read(circleRouterProvider);
    router.go('/you/edit');
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('profile-display-name')),
      'Changed name',
    );
    router.go('/home');
    await settle(tester);
    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await settle(tester);
    expect(find.text('Changed name'), findsOneWidget);
    router.go('/home');
    await settle(tester);
    await tester.tap(find.text('Discard changes'));
    await settle(tester);
    expect(find.byKey(const ValueKey('profile-display-name')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
    await tester.pump(const Duration(seconds: 10));
  });
  testWidgets('search outage shows retry and preserves the query', (
    tester,
  ) async {
    final server = FakeCircleServer();
    final owner = server.addUser(
      '+15559990102',
      'fictional-password',
      'Audit Person',
    );
    server.adapter.handler = (request) => request.path == '/groups'
        ? FakeResponse.error(503, 'server_error')
        : server.handle(request);
    final container = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, owner),
    );
    container.read(circleRouterProvider).go('/search');
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('search-field')), 'park');
    await tester.pump(const Duration(seconds: 15));
    await settle(tester);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CircleSkeleton && widget.label == 'Searching',
      ),
      findsNothing,
    );
    expect(find.text('Groups and people couldn’t load'), findsOneWidget);
    expect(find.text('park'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(seconds: 10));
  });
  testWidgets('invite outage offers retry instead of indefinite loading', (
    tester,
  ) async {
    final server = FakeCircleServer();
    final owner = server.addUser(
      '+15559990101',
      'fictional-password',
      'Audit Person',
    );
    server.adapter.handler = (request) => request.path.startsWith('/invites/')
        ? FakeResponse.error(503, 'server_error')
        : server.handle(request);
    final container = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, owner),
    );
    container
        .read(circleRouterProvider)
        .go('/invite/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(CircleSkeleton), findsNothing);
    expect(find.text('This invite couldn’t load'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    var retries = 0;
    server.adapter.handler = (request) {
      if (request.path.startsWith('/invites/')) retries++;
      return FakeResponse.error(503, 'server_error');
    };
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(retries, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(seconds: 10));
  });
}
