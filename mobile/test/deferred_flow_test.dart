import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/circle_experience.dart';
import 'package:mobile/core/circle_components.dart';
import 'package:mobile/features/albums/application/album_providers.dart';
import 'package:mobile/features/albums/data/mock_album_repository.dart';
import 'package:mobile/features/chat/application/chat_providers.dart';
import 'package:mobile/features/chat/data/mock_chat_repository.dart';
import 'package:mobile/features/chat/presentation/chat_message.dart';
import 'package:mobile/features/memories/presentation/mention_text.dart';
import 'package:mobile/features/notifications/application/notification_providers.dart';
import 'package:mobile/features/notifications/data/mock_notification_repository.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'package:mobile/features/workspace/data/mock_circle_repository.dart';
import 'support/circle_harness.dart';

final fixed = DateTime.utc(2026, 10, 23, 12);
const ist = Duration(hours: 5, minutes: 30);

Finder get composer => find.byKey(const ValueKey('chat-composer'));

Finder bubble(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is Text && widget.key == bubbleTextKey && widget.data == text,
);

/// Something a slow fake waits for, so a test sees the loading state.
Completer<void>? gate;
Future<void> _wait() async {
  final pending = gate;
  if (pending != null) await pending.future;
}

class SlowCircles extends MockCircleRepository {
  SlowCircles({super.now});
  @override
  Future<CircleWorkspace> load(String viewer) async {
    await _wait();
    return super.load(viewer);
  }
}

class SlowChat extends MockChatRepository {
  SlowChat({required super.groups, super.showcase, super.now});
  @override
  Future<ChatInbox> inbox(String viewer) async {
    await _wait();
    return super.inbox(viewer);
  }
}

class SlowNotifications extends MockNotificationRepository {
  SlowNotifications({
    required super.groups,
    required super.chat,
    super.showcase,
    super.now,
  });
  @override
  Future<ActivityFeed> activity(String viewer) async {
    await _wait();
    return super.activity(viewer);
  }
}

class SlowAlbums extends MockAlbumRepository {
  SlowAlbums({required super.groups, super.showcase, super.now});
  @override
  Future<List<Album>> albums(String viewer, String groupId) async {
    await _wait();
    return super.albums(viewer, groupId);
  }
}

/// Like `openCircle`, with provider overrides (no network anywhere).
Future<ProviderContainer> openWith(
  WidgetTester tester,
  List<Override> overrides,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final container = ProviderContainer(
    overrides: [
      circleClockProvider.overrideWithValue(() => fixed),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await container
      .read(circlePreviewSessionProvider.notifier)
      .enter(showcase: true);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const CircleExperience(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Shows the skeleton (never a spinner) until [gate] opens.
Future<void> expectSkeletonUntilOpen(WidgetTester tester, String label) async {
  expect(find.byKey(const ValueKey('circle-skeleton')), findsOneWidget);
  expect(find.bySemanticsLabel(label), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsNothing);
  gate!.complete();
  gate = null;
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('circle-skeleton')), findsNothing);
}

Future<void> settleTap(WidgetTester tester) async {
  // Waits out the double-tap window of message bubbles.
  await tester.pumpAndSettle(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Semantics daySemantics(WidgetTester tester, int month, int day) => tester
    .widget<Semantics>(find.byKey(ValueKey('calendar-day-2026-$month-$day')));

void main() {
  tearDown(() => gate = null);

  group('skeleton loading (README §4.4)', () {
    testWidgets('the workspace loads with card skeletons', (tester) async {
      gate = Completer();
      await openWith(tester, [
        circleRepositoryProvider.overrideWith(
          (ref) => SlowCircles(now: ref.watch(circleClockProvider)),
        ),
      ]);
      await expectSkeletonUntilOpen(tester, 'Loading your circles');
      expect(
        find.textContaining('Sunday lunch is still my favourite'),
        findsOneWidget,
      );
    });

    List<Override> slowFeatures() => [
      chatRepositoryProvider.overrideWith(
        (ref) => SlowChat(
          groups: ref.watch(previewOnlyRepositoryProvider),
          showcase: true,
          now: ref.watch(circleClockProvider),
        ),
      ),
      notificationRepositoryProvider.overrideWith(
        (ref) => SlowNotifications(
          groups: ref.watch(previewOnlyRepositoryProvider),
          chat: ref.watch(chatRepositoryProvider),
          showcase: true,
          now: ref.watch(circleClockProvider),
        ),
      ),
      albumRepositoryProvider.overrideWith(
        (ref) => SlowAlbums(
          groups: ref.watch(previewOnlyRepositoryProvider),
          showcase: true,
          now: ref.watch(circleClockProvider),
        ),
      ),
    ];

    testWidgets('the chat inbox loads with row skeletons', (tester) async {
      gate = Completer();
      final container = await openWith(tester, slowFeatures());
      await go(tester, container, '/chats');
      await expectSkeletonUntilOpen(tester, 'Loading your chats');
      expect(find.text('The Sunday table'), findsOneWidget);
    });

    testWidgets('activity loads with row skeletons', (tester) async {
      gate = Completer();
      final container = await openWith(tester, slowFeatures());
      await go(tester, container, '/activity');
      await expectSkeletonUntilOpen(tester, 'Loading activity');
      expect(find.text('Today'), findsWidgets);
    });

    testWidgets('albums load with a grid skeleton', (tester) async {
      final container = await openWith(tester, slowFeatures());
      await go(tester, container, '/groups/g/club');
      gate = Completer();
      await openTab(tester, 'Albums');
      await expectSkeletonUntilOpen(tester, 'Loading albums');
      expect(find.text('Ride days'), findsOneWidget);
    });

    testWidgets('the kit skeleton is static, labelled once', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CircleSkeleton(
              shape: CircleSkeletonShape.grid,
              count: 6,
              label: 'Loading album',
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Loading album'), findsOneWidget);
      // Nothing animates: no frame is waiting after the first one.
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.byType(CircleSkeletonBlock), findsNWidgets(6));
    });
  });

  group('events month calendar (E1)', () {
    testWidgets('List | Month, today, dots, day selection and filters', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      // A second event on Sunday 25 October, in another group.
      await container
          .read(circleWorkspaceProvider.notifier)
          .createEvent(
            EventDraft(
              groupId: 'club',
              title: 'Evening ride',
              startsAt: DateTime.utc(2026, 10, 25, 12),
              timeZoneLabel: 'IST',
              utcOffset: ist,
              venue: 'Lake road · Fictional venue',
            ),
          );
      await go(tester, container, '/events');
      expect(find.byTooltip('List'), findsOneWidget);
      await tester.tap(find.byTooltip('Month'));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      expect(
        daySemantics(tester, 10, 25).properties.label,
        'Sunday 25 October, 2 events',
      );
      expect(
        daySemantics(tester, 10, 23).properties.label,
        'Friday 23 October, today, no events',
      );
      // Today is selected at first.
      expect(daySemantics(tester, 10, 23).properties.selected, isTrue);
      expect(find.text('Nothing planned today.'), findsOneWidget);
      // Every day is at least a 48px target.
      final size = tester.getSize(
        find.byKey(const ValueKey('calendar-day-2026-10-25')),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      await tester.tap(find.byKey(const ValueKey('calendar-day-2026-10-25')));
      await tester.pumpAndSettle();
      expect(find.text('Sunday 25 October'), findsOneWidget);
      await reveal(tester, find.text('Evening ride'));
      expect(find.text('A Sunday well spent'), findsOneWidget);
      expect(find.text('Evening ride'), findsOneWidget);

      // The group chips filter the calendar too.
      await tapChip(tester, 'Sunday miles');
      expect(
        daySemantics(tester, 10, 25).properties.label,
        'Sunday 25 October, 1 event',
      );
      expect(find.text('A Sunday well spent'), findsNothing);
      await tapChip(tester, 'Sunday miles');

      // Earlier months are under Past; later ones are a tap away.
      final previous = find.byTooltip('Previous month');
      await reveal(tester, previous);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_left),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      expect(
        daySemantics(tester, 11, 1).properties.label,
        'Sunday 1 November, 1 event',
      );
      expect(find.text('Choose a day to see its events.'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);

      // Past has no calendar toggle.
      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Month'), findsNothing);
      expect(find.byTooltip('Next month'), findsNothing);
    });
  });

  group('@mentions', () {
    testWidgets('group chat suggests only that group; the mention notifies', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/g-family');
      // Lena is in Studio North, not in the family: never suggested.
      await tester.enterText(composer, 'Hi @Le');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mention-suggestions')), findsNothing);
      await tester.enterText(composer, 'Hi @Mi');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mention-mira')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.semanticsLabel == 'Mention Mira',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('mention-mira')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(composer).controller!.text, 'Hi @Mira ');
      expect(find.byKey(const ValueKey('mention-suggestions')), findsNothing);
      await tester.enterText(composer, 'Hi @Mira, the pot?');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();

      final sent =
          (await container
                  .read(chatRepositoryProvider)
                  .conversation('you', 'g-family'))
              .messages
              .last;
      expect(sent.mentions, {'mira': 'Mira'});
      // Emphasised in the bubble.
      final text = find.byWidgetPredicate(
        (widget) =>
            widget is MentionText && widget.text == 'Hi @Mira, the pot?',
      );
      expect(text, findsOneWidget);
      final rich = tester.widget<RichText>(
        find.descendant(of: text, matching: find.byType(RichText)),
      );
      final spans = <TextSpan>[];
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.text != null) spans.add(span);
        return true;
      });
      final mention = spans.firstWhere((span) => span.text == '@Mira');
      expect(mention.style?.fontWeight, FontWeight.w600);

      // Mira gets a personal Activity item.
      final feed = await container
          .read(notificationRepositoryProvider)
          .activity('mira');
      final item = feed.entries.firstWhere(
        (entry) => entry.item.id == 'mention:${sent.id}',
      );
      expect(item.badged, isTrue);

      // People you blocked are never suggested.
      await container.read(chatControllerProvider.notifier).block('priya');
      await tester.pumpAndSettle();
      await tester.enterText(composer, '@Pr');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mention-priya')), findsNothing);
    });

    testWidgets('your mentions show in Activity', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/activity');
      await reveal(
        tester,
        find.textContaining('Sam mentioned you in Northbank'),
      );
      expect(
        find.textContaining('Sam mentioned you in Northbank 2009'),
        findsOneWidget,
      );
      await reveal(
        tester,
        find.textContaining('Tomas mentioned you in a comment'),
      );
      await tester.tap(find.textContaining('Tomas mentioned you in a comment'));
      await tester.pumpAndSettle();
      expect(currentUri(container).path, '/home/memory/ride');
    });

    testWidgets('comments suggest the Memory’s exact group', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/home/memory/table');
      final field = find.widgetWithText(TextField, 'Add a comment');
      await reveal(tester, field);
      await tester.enterText(field, 'Thanks @Le');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mention-lena')), findsNothing);
      await tester.enterText(field, 'Thanks @D');
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('mention-dev')));
      await tester.tap(find.byKey(const ValueKey('mention-dev')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Send comment');
      final comment = workspaceOf(
        container,
      ).memories.firstWhere((memory) => memory.id == 'table').comments.last;
      expect(comment.text, 'Thanks @Dev');
      expect(comment.mentions, {'dev': 'Dev'});
      expect(find.textContaining('@Dev', findRichText: true), findsWidgets);
    });
  });

  group('forwarding', () {
    testWidgets('pick chats; ineligible ones are skipped calmly', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/g-family');
      const shared = 'This one made me smile.';
      await tester.ensureVisible(bubble(shared));
      await tester.pumpAndSettle();
      await tester.tap(bubble(shared));
      await settleTap(tester);
      expect(find.widgetWithText(TextButton, 'Forward'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Forward'));
      await tester.pumpAndSettle();
      expect(find.text('Forward to'), findsOneWidget);
      // Chats you can post in, including this one.
      expect(find.byKey(const ValueKey('forward-g-family')), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search chats'),
        'studio',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('forward-d-mira-you')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('forward-g-work')));
      await tester.enterText(
        find.widgetWithText(TextField, 'Search chats'),
        '',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('forward-d-mira-you')));
      await tester.pumpAndSettle();
      expect(find.text('2 of 5 chosen'), findsOneWidget);
      await tester.tap(find.text('Forward to 2 chats'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Forwarded to Mira. Not sent to Studio North: not everyone there '
          'can see this Memory.',
        ),
        findsOneWidget,
      );
      final copy =
          (await container
                  .read(chatRepositoryProvider)
                  .conversation('you', 'd-mira-you'))
              .messages
              .last;
      expect(copy.forwarded, isTrue);
      await go(tester, container, '/chats/c/d-mira-you');
      expect(find.text('Forwarded'), findsOneWidget);
    });

    testWidgets('Forward is in the long-press menu; at most 5 chats', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/d-mira-you');
      const walk = 'Also, are you free for a walk tomorrow morning?';
      await tester.longPress(bubble(walk));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forward'));
      await tester.pumpAndSettle();
      final boxes = find.byType(CheckboxListTile);
      for (var i = 0; i < 5; i++) {
        await tester.tap(boxes.at(i));
        await tester.pumpAndSettle();
      }
      expect(find.text('You can forward to 5 chats at once.'), findsOneWidget);
      final sixth = tester.widget<CheckboxListTile>(boxes.at(5));
      expect(sixth.onChanged, isNull);
      expect(container.read(chatInboxProvider).value, isNotNull);
    });
  });

  group('photos in chat', () {
    testWidgets('send photos, open the viewer, double-tap ❤️', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/g-family');
      await tester.tap(
        find.byTooltip('Add photos, a Memory, an event or a poll'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Photos'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Hill trip'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Beach walk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send 2 photos'));
      await tester.pumpAndSettle();
      final sent =
          (await container
                  .read(chatRepositoryProvider)
                  .conversation('you', 'g-family'))
              .messages
              .last;
      expect(sent.photos, hasLength(2));
      final grid = find.byKey(ValueKey('photo-message-${sent.id}'));
      expect(grid, findsOneWidget);
      expect(find.text('Sent 2 photos · now'), findsNothing);

      // Double-tap for ❤️.
      await tester.ensureVisible(grid);
      await tester.pumpAndSettle();
      await tester.tap(grid);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(grid);
      await tester.pumpAndSettle();
      final message =
          (await container
                  .read(chatRepositoryProvider)
                  .conversation('you', 'g-family'))
              .messages
              .last;
      expect(message.reactions.mine, '❤️');

      // Long-press: reply works; photos aren't forwardable.
      await tester.longPress(grid);
      await tester.pumpAndSettle();
      expect(find.text('Forward'), findsNothing);
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      expect(find.text('Replying to You'), findsOneWidget);
      expect(find.text('Sent 2 photos'), findsOneWidget);

      // A single tap on a photo opens the viewer.
      await tester.tap(
        find.descendant(of: grid, matching: find.byType(CircleSceneTile)).first,
      );
      await settleTap(tester);
      expect(currentUri(container).path, '/chats/c/g-family/photos/${sent.id}');
      expect(find.text('1 of 2'), findsOneWidget);
      // The Hill trip scene now shows its bundled fictional photo.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CircleSceneTile && w.asset == 'assets/welcome/friends.jpg',
        ),
        findsOneWidget,
      );
    });
  });

  group('album cover and captions', () {
    testWidgets('set as cover and edit a caption from ⋮ and the viewer', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/groups/g/club/albums/ride-days');
      expect(find.text('Cover'), findsOneWidget);
      await tester.tap(find.byTooltip('Options for photo 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set as cover'));
      await tester.pumpAndSettle();
      expect(find.text('Album cover changed.'), findsOneWidget);
      var album = await container
          .read(albumRepositoryProvider)
          .album('you', 'ride-days');
      expect(album.cover!.id, 'ride-days-photo-2');

      await tester.tap(find.byTooltip('Options for photo 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit caption'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Caption (optional)'),
        'Morning light on the hill',
      );
      await tester.tap(find.text('Save caption'));
      await tester.pumpAndSettle();
      expect(find.text('Caption saved.'), findsOneWidget);
      album = await container
          .read(albumRepositoryProvider)
          .album('you', 'ride-days');
      expect(album.photos.first.photo.caption, 'Morning light on the hill');

      // The viewer offers the same, and shows the caption.
      await tester.tap(find.byType(CircleSceneTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Morning light on the hill'), findsOneWidget);
      expect(find.text('Set as cover'), findsOneWidget);
      expect(find.text('Edit caption'), findsOneWidget);
      await tester.tap(find.byTooltip('Next photo'));
      await tester.pumpAndSettle();
      expect(find.text('Album cover'), findsOneWidget);

      // The Albums grid uses the chosen cover.
      await go(tester, container, '/groups/g/club');
      await openTab(tester, 'Albums');
      expect(find.text('Breakfast by the water'), findsNothing);
      expect(find.text('Beach walk'), findsOneWidget);
    });

    testWidgets('Memory compose: optional captions per photo', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/compose?group=family');
      await tapText(tester, 'Add photos');
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Sunday lunch'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Use 1 photo');
      await tapText(tester, 'Captions (optional)');
      final field = find.widgetWithText(TextField, 'Caption for Sunday lunch');
      await reveal(tester, field);
      await tester.enterText(field, 'Everyone at the table');
      await tester.pumpAndSettle();
      await tapText(tester, 'Share Memory');
      final memory = workspaceOf(container).memories.first;
      expect(memory.photos.single.caption, 'Everyone at the table');
    });
  });

  for (final size in [
    const Size(360, 800),
    const Size(393, 852),
    const Size(900, 1100),
  ]) {
    testWidgets('new screens: dark, 200% text, no overflow at $size', (
      tester,
    ) async {
      final container = await openCircle(
        tester,
        now: fixed,
        size: size,
        scale: 2,
        brightness: Brightness.dark,
      );
      await container
          .read(chatControllerProvider.notifier)
          .send(
            'g-family',
            clientMessageId: 'layout-photos',
            photos: const [
              MemoryScene.hillTrip,
              MemoryScene.beachWalk,
              MemoryScene.sundayLunch,
              MemoryScene.birthdayCake,
            ],
          );
      await go(tester, container, '/events');
      await tester.tap(find.byTooltip('Month'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final day = find.byKey(const ValueKey('calendar-day-2026-10-25'));
      await reveal(tester, day);
      await tester.tap(day);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final route in [
        '/chats/c/g-family',
        '/groups/g/club/albums/ride-days',
        '/groups/g/club/albums/ride-days/photos?index=0',
        '/home/memory/ride',
      ]) {
        await go(tester, container, route);
        expect(tester.takeException(), isNull, reason: route);
      }
      // The forward picker and the photo viewer.
      await go(tester, container, '/chats/c/d-mira-you');
      final walk = bubble('Also, are you free for a walk tomorrow morning?');
      if (walk.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          walk,
          200,
          scrollable: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.up,
          ),
        );
      }
      await tester.ensureVisible(walk);
      await tester.pumpAndSettle();
      await tester.longPress(walk);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forward'));
      await tester.pumpAndSettle();
      expect(find.text('Forward to'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      final id =
          (await container
                  .read(chatRepositoryProvider)
                  .conversation('you', 'g-family'))
              .messages
              .last
              .id;
      await go(tester, container, '/chats/c/g-family/photos/$id?index=3');
      expect(find.text('4 of 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Compose with captions open.
      await go(tester, container, '/compose?group=family');
      await tapText(tester, 'Add photos');
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Sunday lunch'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Use 1 photo');
      await tapText(tester, 'Captions (optional)');
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> tapChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(ChoiceChip, label);
  await reveal(tester, chip);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}
