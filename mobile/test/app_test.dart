import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/session.dart';
import 'package:mobile/features/feed/domain/post.dart';
import 'package:mobile/features/feed/data/mock_feed_repository.dart';
import 'package:mobile/features/feed/presentation/feed_controller.dart';

Future<void> launch(
  WidgetTester tester, {
  bool entered = false,
  Size size = const Size(393, 852),
  double scale = 1,
  Brightness brightness = Brightness.light,
  FeedRepository? repository,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final container = ProviderContainer(
    overrides: [
      if (repository != null)
        feedRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  if (entered) container.read(sessionProvider.notifier).enter('CIRCLE-DEMO');
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const CircleApp()),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('async feed exposes loading before data', (tester) async {
    final pending = PendingFeed();
    await launch(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CircleApp)),
    );
    await tester.pumpWidget(const SizedBox());
    final scope = ProviderContainer(
      overrides: [feedRepositoryProvider.overrideWithValue(pending)],
    );
    addTearDown(scope.dispose);
    scope.read(sessionProvider.notifier).enter('CIRCLE-DEMO');
    await tester.pumpWidget(
      UncontrolledProviderScope(container: scope, child: const CircleApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.result.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('The first story starts with you'), findsOneWidget);
    expect(container.read(sessionProvider), false);
  });
  testWidgets('long content and 100 posts remain navigable', (tester) async {
    await launch(tester, entered: true, repository: LargeFeed());
    expect(find.text('Good to be together.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CircleApp)),
    );
    container.read(routerProvider).go('/post/99');
    await tester.pumpAndSettle();
    expect(find.textContaining('A very long fictional'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('ending demo clears local writes and blocks private routes', (
    tester,
  ) async {
    await launch(tester, entered: true);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CircleApp)),
    );
    container.read(feedProvider.notifier).create('Temporary memory');
    container.read(routerProvider).go('/profile');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('End demo and clear session'));
    await tester.tap(find.text('End demo and clear session'));
    await tester.pumpAndSettle();
    expect(find.text('Your invitation'), findsOneWidget);
    container.read(sessionProvider.notifier).enter('CIRCLE-DEMO');
    await tester.pumpAndSettle();
    expect(
      container
          .read(feedProvider)
          .requireValue
          .any((post) => post.body == 'Temporary memory'),
      false,
    );
  });
  for (final path in [
    '/',
    '/invite',
    '/post/courtyard',
    '/groups',
    '/memories',
    '/friends',
    '/events',
    '/profile',
  ]) {
    testWidgets('screen golden $path', (tester) async {
      await launch(tester, entered: path != '/' && path != '/invite');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CircleApp)),
      );
      container.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      final name = path == '/'
          ? 'welcome'
          : path.substring(1).replaceAll('/', '_');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.png'),
      );
    });
  }
  testWidgets('invitation journey validates input and guards deep links', (
    tester,
  ) async {
    await launch(tester);
    final context = tester.element(find.byType(CircleApp));
    final container = ProviderScope.containerOf(context);
    container.read(routerProvider).go('/post/courtyard');
    await tester.pumpAndSettle();
    expect(find.text('Your invitation'), findsOneWidget);
    await tester.ensureVisible(find.text('Open my circle'));
    await tester.tap(find.text('Open my circle'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Use CIRCLE-DEMO'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'CIRCLE-DEMO');
    await tester.tap(find.text('Open my circle'));
    await tester.pumpAndSettle();
    expect(find.text('Good to be together.'), findsOneWidget);
  });
  testWidgets('reaction save comment and creation survive route changes', (
    tester,
  ) async {
    await launch(tester, entered: true);
    await tester.tap(find.byTooltip('Save memory').first);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CircleApp)),
    );
    container.read(routerProvider).go('/post/courtyard');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Love').first);
    await tester.tap(find.text('Love').first);
    await tester.pumpAndSettle();
    expect(find.text('Loved'), findsOneWidget);
    await tester.ensureVisible(find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), 'Remember the rain!');
    await tester.ensureVisible(find.text('Send comment'));
    await tester.tap(find.text('Send comment'));
    await tester.pumpAndSettle();
    expect(
      container.read(feedProvider).requireValue.first.comments.last,
      'You: Remember the rain!',
    );
    container.read(routerProvider).go('/profile');
    await tester.pumpAndSettle();
    expect(find.textContaining('Does anyone else'), findsOneWidget);
    container.read(routerProvider).go('/create');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Another lovely memory');
    await tester.tap(find.text('Share with my circle'));
    await tester.pumpAndSettle();
    expect(find.text('Another lovely memory'), findsOneWidget);
  });
  testWidgets('supporting navigation, member search and RSVP work', (
    tester,
  ) async {
    await launch(tester, entered: true);
    await tester.tap(find.byIcon(Icons.groups_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('The backstage crew'), findsOneWidget);
    await tester.tap(find.text('The backstage crew'));
    await tester.pumpAndSettle();
    expect(find.textContaining('painted sets'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.photo_album_outlined).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('The campus years'));
    await tester.pumpAndSettle();
    expect(find.textContaining('uploads and tagging'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.people_outline).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'no such person');
    await tester.pumpAndSettle();
    expect(find.text('No familiar faces found'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Mira');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mira Sen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Collects books'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.event_outlined).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Twenty years, together'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Count me in'));
    await tester.pumpAndSettle();
    expect(find.text('Going · Undo RSVP'), findsOneWidget);
  });
  for (final size in [
    const Size(360, 800),
    const Size(393, 852),
    const Size(900, 1100),
  ]) {
    testWidgets('no layout exceptions at $size, dark, large text', (
      tester,
    ) async {
      await launch(
        tester,
        entered: true,
        size: size,
        scale: 2,
        brightness: Brightness.dark,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CircleApp)),
      );
      for (final path in [
        '/feed',
        '/groups',
        '/memories',
        '/friends',
        '/events',
        '/profile',
        '/create',
        '/post/courtyard',
        '/event/twenty',
      ]) {
        container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: path);
      }
    });
  }
  testWidgets('feed empty and failure have clear recovery states', (
    tester,
  ) async {
    await launch(tester, entered: true, repository: EmptyFeed());
    expect(find.text('The first story starts with you'), findsOneWidget);
  });
  testWidgets('feed failure can retry', (tester) async {
    await launch(tester, entered: true, repository: FailingFeed());
    expect(find.text('Your circle couldn’t load'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Good to be together.'), findsOneWidget);
  });
  testWidgets('welcome accessibility targets and labels', (tester) async {
    await launch(tester);
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
  for (final dark in [false, true]) {
    testWidgets('feed golden ${dark ? 'dark' : 'light'}', (tester) async {
      await launch(
        tester,
        entered: true,
        brightness: dark ? Brightness.dark : Brightness.light,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/feed_${dark ? 'dark' : 'light'}.png'),
      );
    });
  }
}

class EmptyFeed extends MockFeedRepository {
  @override
  Future<List<Post>> load(String communityId) async => [];
}

class PendingFeed extends MockFeedRepository {
  final result = Completer<List<Post>>();
  @override
  Future<List<Post>> load(String communityId) => result.future;
}

class LargeFeed extends MockFeedRepository {
  @override
  Future<List<Post>> load(String communityId) async => List.generate(
    100,
    (index) => Post(
      id: '$index',
      communityId: demoCommunity,
      author: 'A fictional member with a very long name',
      body: 'A very long fictional memory. ' * 50,
      date: 'Local fixture',
    ),
  );
}

class FailingFeed extends MockFeedRepository {
  bool fail = true;
  @override
  Future<List<Post>> load(String communityId) async {
    if (fail) {
      fail = false;
      throw StateError('Injected failure');
    }
    return super.load(communityId);
  }
}
