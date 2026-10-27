import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/api/api_providers.dart';
import 'package:mobile/core/circle_signed_image.dart';
import 'package:mobile/features/memories/application/media_providers.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'package:mobile/features/auth/domain/access_validation.dart';
import 'support/circle_harness.dart' show currentUri, openTab, reveal;
import 'support/fake_api.dart';
import 'support/server_harness.dart';

const password = 'correct horse battery staple';

/// The dial code that the form auto-selects based on test platform locale.
String get _prefix => AccessValidation.defaultDialCode.code;

Future<void> enter(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.tap(finder.first);
  await settle(tester);
}

Uint8List jpeg() =>
    Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(64, 7)]);

void main() {
  testWidgets('register → empty workspace → create group → share a Memory', (
    tester,
  ) async {
    final server = FakeCircleServer();
    final tokens = MemoryTokenStore();
    final container = await openServerCircle(tester, server, tokens: tokens);

    // One honest label: the server, not "Preview".
    await reveal(tester, find.textContaining('Connected to circle.test'));
    expect(find.textContaining('Connected to circle.test'), findsOneWidget);
    expect(find.textContaining('Nothing is sent or stored'), findsNothing);
    expect(find.text('Explore fictional circles'), findsOneWidget);
    await tap(tester, find.text('Get Started'));
    expect(find.text('Preview registration'), findsNothing);
    await enter(
      tester,
      find.widgetWithText(TextFormField, 'Name (optional)'),
      'Asha',
    );
    await enter(
      tester,
      find.byKey(const ValueKey('access-mobile')),
      '5550000001',
    );
    await enter(
      tester,
      find.byKey(const ValueKey('access-password')),
      ' $password ',
    );
    await tap(tester, find.widgetWithText(FilledButton, 'Create account'));

    // Registered (202, no tokens), then logged in with the same details.
    final paths = server.adapter.requests.map((r) => r.path).toList();
    expect(paths.take(2), ['/auth/register', '/auth/login']);
    expect(server.adapter.requests.first.json['password'], ' $password ');
    expect(
      server.adapter.requests.first.json['mobile'],
      '${_prefix}5550000001',
    );
    expect((await tokens.read())?.accessToken, startsWith('access-'));
    expect(currentUri(container).path, '/home');
    expect(find.text('CIRCLE', findRichText: true), findsOneWidget);
    expect(find.text('CIRCLE • PREVIEW', findRichText: true), findsNothing);
    expect(find.text('A little space for your people'), findsOneWidget);

    await tap(tester, find.widgetWithText(FilledButton, 'Create a group'));
    await enter(
      tester,
      find.widgetWithText(TextField, 'Group name'),
      'Sharma Family',
    );
    await tap(tester, find.text('Create private group'));
    final group = server.groups.values.single;
    expect(group['name'], 'Sharma Family');
    expect(currentUri(container).path, '/groups/g/${group['id']}');

    await tap(tester, find.text('Share a Memory here'));
    await enter(
      tester,
      find.widgetWithText(TextField, 'Your Memory'),
      'Sunday lunch at home',
    );
    // Polls aren't on the server yet: no dead button.
    expect(find.text('Add a poll'), findsNothing);
    await tap(tester, find.text('Share Memory'));
    expect(server.memories.single['body'], 'Sunday lunch at home');
    expect(currentUri(container).path, '/home');
    expect(find.text('Sunday lunch at home'), findsOneWidget);
    expect(find.text('Sharma Family'), findsWidgets);
  });

  testWidgets('a failed log-in is generic; the right password gets in', (
    tester,
  ) async {
    final server = FakeCircleServer()
      ..addUser('${_prefix}5550000002', password, 'Dev');
    await openServerCircle(tester, server);
    await tap(tester, find.text('Log in'));
    await enter(
      tester,
      find.byKey(const ValueKey('access-mobile')),
      '5550000002',
    );
    await enter(
      tester,
      find.byKey(const ValueKey('access-password')),
      'not the password',
    );
    await tap(tester, find.widgetWithText(FilledButton, 'Log in'));
    expect(
      find.text(
        'That mobile number and password didn’t work. Check them and try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Raw server text'), findsNothing);
    await enter(
      tester,
      find.byKey(const ValueKey('access-password')),
      password,
    );
    await tap(tester, find.widgetWithText(FilledButton, 'Log in'));
    expect(find.text('CIRCLE', findRichText: true), findsOneWidget);
  });

  testWidgets('features the server lacks say so, calmly, once', (tester) async {
    final server = FakeCircleServer();
    final user = server.addUser('${_prefix}5550000003', password, 'Mira');
    final family = server.addGroup('Family', user);
    final container = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, user),
    );
    expect(currentUri(container).path, '/home');

    for (final (tab, label) in [
      ('Events', 'Events aren’t on the server yet.'),
      ('Chats', 'Chat isn’t on the server yet.'),
    ]) {
      expect(find.widgetWithText(NavigationDestination, tab), findsNothing);
      container
          .read(circleRouterProvider)
          .go(tab == 'Events' ? '/events' : '/chats');
      await settle(tester);
      expect(find.text('Not on the server yet'), findsOneWidget);
      expect(find.textContaining(label), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      // No calendar toggle or chat actions behind the gate.
      expect(find.text('Month'), findsNothing);
      expect(find.text('Forward'), findsNothing);
    }

    container.read(circleRouterProvider).go('/groups/g/$family');
    await settle(tester);
    for (final (tab, label) in [
      ('Events', 'Events aren’t'),
      ('Chat', 'Chat isn’t'),
      ('Albums', 'Albums aren’t'),
    ]) {
      await openTab(tester, tab);
      await settle(tester);
      expect(find.textContaining(label), findsOneWidget, reason: tab);
      expect(find.text('Set as cover'), findsNothing);
      expect(find.text('Month'), findsNothing);
    }
    // Deep links into preview-only screens are honest too.
    for (final location in [
      '/chats/c/g-1/photos/message-1',
      '/activity',
      '/you/notifications',
    ]) {
      container.read(circleRouterProvider).go(location);
      await settle(tester);
      expect(
        find.text('Not on the server yet'),
        findsOneWidget,
        reason: location,
      );
    }
    // No fictional data was mixed in.
    expect(find.text('Mira (fictional)'), findsNothing);
    expect(
      server.adapter.requests.where((r) => r.path.contains('event')),
      isEmpty,
    );
  });

  testWidgets('a stored session reopens; an expired one refreshes once', (
    tester,
  ) async {
    final server = FakeCircleServer();
    final user = server.addUser('${_prefix}5550000004', password, 'Lena');
    server.addGroup('Book club', user, type: 'club');
    final tokens = await storedSession(server, user);
    server.expireAccessTokens();
    final container = await openServerCircle(tester, server, tokens: tokens);
    expect(currentUri(container).path, '/home');
    expect(server.adapter.count('POST', '/auth/refresh'), 1);
    expect(workspaceOf(container).groups.single.name, 'Book club');
  });

  testWidgets('a refused refresh goes to log-in with a calm notice', (
    tester,
  ) async {
    final server = FakeCircleServer();
    final user = server.addUser('${_prefix}5550000005', password, 'Sam');
    final tokens = await storedSession(server, user);
    server
      ..expireAccessTokens()
      ..refresh.clear();
    final container = await openServerCircle(tester, server, tokens: tokens);
    expect(currentUri(container).path, '/login');
    expect(
      find.text('Your session ended. Please log in again.'),
      findsOneWidget,
    );
    expect(await tokens.read(), isNull);
  });

  testWidgets('photos: 503 is calm, the words still share', (tester) async {
    final server = FakeCircleServer();
    final user = server.addUser('${_prefix}5550000006', password, 'Noor');
    final group = server.addGroup('Family', user);
    final picker = FakePhotoPicker([PickedPhoto(name: 'a.jpg', bytes: jpeg())]);
    final container = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, user),
      picker: picker,
    );
    container.read(circleRouterProvider).go('/compose?group=$group');
    await settle(tester);
    await tap(tester, find.text('Add photos'));
    expect(picker.calls, 1);
    expect(
      find.textContaining('Photos can’t be processed on this server yet.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('share your words without photos'),
      findsOneWidget,
    );
    await enter(
      tester,
      find.widgetWithText(TextField, 'Your Memory'),
      'Words only',
    );
    await tap(tester, find.text('Share Memory'));
    expect(server.memories, isEmpty, reason: 'failed photos block sharing');
    await tap(tester, find.byTooltip('Remove photo 1'));
    await tap(tester, find.text('Share Memory'));
    expect(server.memories.single['body'], 'Words only');
  });

  testWidgets('photos upload, attach by id and show through signed links', (
    tester,
  ) async {
    final server = FakeCircleServer(mediaAvailable: true);
    final user = server.addUser('${_prefix}5550000007', password, 'Priya');
    final group = server.addGroup('Family', user);
    final container = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, user),
      picker: FakePhotoPicker([PickedPhoto(name: 'a.jpg', bytes: jpeg())]),
    );
    container.read(circleRouterProvider).go('/compose?group=$group');
    await settle(tester);
    await tap(tester, find.text('Add photos'));
    expect(find.bySemanticsLabel(RegExp('Photo 1, uploaded')), findsOneWidget);
    // The API has no caption field yet: no caption inputs on a server.
    expect(find.text('Captions (optional)'), findsNothing);
    await tap(tester, find.text('Share Memory'));
    final media = server.memories.single['media'] as List;
    expect(media, hasLength(1));
    final mediaId = (media.single as Map)['id'] as String;
    final sent = server.adapter.requests
        .lastWhere((r) => r.path == '/groups/$group/memories')
        .json;
    expect(sent['media_ids'], [mediaId]);
    expect(sent.containsKey('body'), isFalse, reason: 'words are optional');
    expect(find.byType(CircleSignedImage), findsOneWidget);
    expect(server.adapter.count('GET', '/media/$mediaId'), 1);
    expect(
      server.adapter.requests
          .lastWhere((r) => r.path == '/media/$mediaId')
          .query['size'],
      'thumb',
    );
  });

  testWidgets('comments: @suggestions are the group’s members; plain text '
      'goes to the server', (tester) async {
    final server = FakeCircleServer();
    final user = server.addUser('${_prefix}5550000009', password, 'Asha');
    final dev = server.addUser('${_prefix}5550000010', password, 'Devika');
    server.addUser('${_prefix}5550000011', password, 'Dhruv');
    final group = server.addGroup('Family', user);
    server.members[group]![dev] = 'member';
    final memory = server.addMemory(group, user, 'Sunday lunch');
    final container = await openServerCircle(
      tester,
      server,
      tokens: await storedSession(server, user),
    );
    // Opening the group space loads its members.
    container.read(circleRouterProvider).go('/groups/g/$group');
    await settle(tester);
    container.read(circleRouterProvider).go('/home/memory/$memory');
    await settle(tester);
    final field = find.widgetWithText(TextField, 'Add a comment');
    await reveal(tester, field);
    await tester.enterText(field, 'Thanks @D');
    await settle(tester);
    // Dhruv isn't in this group: never suggested.
    expect(find.byKey(ValueKey('mention-$dev')), findsOneWidget);
    expect(find.text('Dhruv'), findsNothing);
    await tester.tap(find.byKey(ValueKey('mention-$dev')));
    await settle(tester);
    await tap(tester, find.text('Send comment'));
    final sent = server.adapter.requests
        .lastWhere((r) => r.path == '/memories/$memory/comments')
        .json;
    expect(sent, {'body': 'Thanks @Devika'});
    // Nothing about mentions is preview-only here: no Activity on a server.
    expect(find.byKey(const ValueKey('activity-badge')), findsNothing);
  });

  testWidgets('log out ends the session and clears the tokens', (tester) async {
    final server = FakeCircleServer();
    final user = server.addUser('${_prefix}5550000008', password, 'Tomas');
    final tokens = await storedSession(server, user);
    final container = await openServerCircle(tester, server, tokens: tokens);
    container.read(circleRouterProvider).go('/you/account');
    await settle(tester);
    await tap(tester, find.text('Log out'));
    expect(server.adapter.count('POST', '/auth/logout'), 1);
    expect(await tokens.read(), isNull);
    expect(currentUri(container).path, '/');
    expect(container.read(circleViewerProvider), 'you');
  });

  testWidgets('external custom invite survives sign-in redirect', (
    tester,
  ) async {
    final container = await openServerCircle(tester, FakeCircleServer());
    container
        .read(circleRouterProvider)
        .go('circle://invite/AbC_def-1234567890');
    await settle(tester);
    expect(currentUri(container).path, '/login');
    expect(
      currentUri(container).queryParameters['next'],
      '/invite/AbC_def-1234567890',
    );
  });

  testWidgets('the fictional tour stays separate from the server', (
    tester,
  ) async {
    final server = FakeCircleServer();
    final container = await openServerCircle(tester, server);
    await tap(tester, find.text('Explore fictional circles'));
    expect(currentUri(container).path, '/home');
    expect(find.text('CIRCLE • PREVIEW', findRichText: true), findsOneWidget);
    expect(workspaceOf(container).groups, isNotEmpty);
    expect(server.adapter.requests, isEmpty);
    expect(container.read(apiClientProvider), isNotNull);
  });
}

CircleWorkspace workspaceOf(ProviderContainer container) =>
    container.read(circleWorkspaceProvider).requireValue;
