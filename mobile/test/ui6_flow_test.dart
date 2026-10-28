import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/circle_components.dart';
import 'package:mobile/features/albums/application/album_providers.dart';
import 'package:mobile/features/chat/presentation/chat_message.dart';
import 'package:mobile/features/notifications/application/notification_providers.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/circle_harness.dart';

final fixed = DateTime.utc(2026, 10, 23, 12);

Finder bubble(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is Text && widget.key == bubbleTextKey && widget.data == text,
);

Future<void> longPressMessage(WidgetTester tester, String text) async {
  final finder = bubble(text);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.up,
      ),
    );
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.longPress(finder.first);
  await tester.pumpAndSettle();
}

Future<int> badgeOf(ProviderContainer container) async =>
    (await container.read(activityFeedProvider.future)).badge;

Finder badgeText(int count) => find.descendant(
  of: find.byKey(const ValueKey('activity-badge')),
  matching: find.text('$count'),
);

const spam = 'Selling cheap concert tickets — message me for the link!';

void main() {
  group('albums', () {
    testWidgets('create, add, remove with Undo, view and delete', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/groups/g/club');
      await openTab(tester, 'Albums');
      expect(find.text('Ride days'), findsOneWidget);
      expect(find.textContaining('Albums arrive later'), findsNothing);
      await tapText(tester, 'New album');
      await tester.enterText(
        find.widgetWithText(TextField, 'Album name'),
        'Lake days',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Year or era (optional)'),
        '2026',
      );
      await tapText(tester, 'Choose photos (optional)');
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Hill trip'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Add 1 photo');
      await tapText(tester, 'Create album');
      expect(currentUri(container).path, startsWith('/groups/g/club/albums/'));
      expect(find.text('Lake days'), findsOneWidget);
      expect(find.textContaining('1 photo · 2026'), findsOneWidget);

      await tapText(tester, 'Add photos');
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Beach walk'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Add 1 photo');
      expect(find.textContaining('2 photos · 2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Options for photo 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from album'));
      await tester.pumpAndSettle();
      expect(find.text('Photo removed.'), findsOneWidget);
      expect(find.textContaining('1 photo · 2026'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 photos · 2026'), findsOneWidget);

      // The shared viewer: swipe or buttons, "n of N", caption.
      await tester.tap(find.byType(CircleSceneTile).first);
      await tester.pumpAndSettle();
      expect(currentUri(container).path, endsWith('/photos'));
      expect(find.text('1 of 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Next photo'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.text('Remove from album'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      final id = currentUri(container).pathSegments.last;
      await tester.tap(find.byTooltip('Album options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete album'));
      await tester.pumpAndSettle();
      expect(find.text('Delete “Lake days”?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete album'));
      await tester.pumpAndSettle();
      expect(find.text('Album deleted.'), findsOneWidget);
      final albums = await container
          .read(albumRepositoryProvider)
          .albums('you', 'club');
      expect(albums.map((album) => album.id), isNot(contains(id)));
    });

    testWidgets('members can’t edit someone else’s album', (tester) async {
      final container = await openCircle(tester, now: fixed);
      // The viewer is an admin of Northbank 2009, so leave it to Studio
      // North, where they are a plain member with no albums yet.
      await go(tester, container, '/groups/g/work');
      await openTab(tester, 'Albums');
      expect(find.text('A home for your shared photos'), findsOneWidget);
      await go(tester, container, '/groups/g/college/albums/hostel-years');
      expect(find.text('Hostel years'), findsOneWidget);
      expect(find.byTooltip('Album options'), findsOneWidget, reason: 'admin');
      await go(tester, container, '/groups/g/private-plans/albums/party-ideas');
      expect(find.text('This album is unavailable'), findsOneWidget);
    });

    testWidgets('a past event offers “Photos from …”', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/events/e/picnic');
      await reveal(tester, find.text('Photos from Autumn picnic'));
      await tester.tap(
        find.bySemanticsLabel('Add photos to Photos from Autumn picnic'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Beach walk'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Add 1 photo');
      expect(
        currentUri(container).path,
        '/groups/g/club/albums/event-album-picnic',
      );
      expect(find.text('Event album'), findsOneWidget);
      // Upcoming events have no album yet.
      await go(tester, container, '/events/e/lunch');
      expect(find.text('Photos from A Sunday well spent'), findsNothing);
    });
  });

  group('activity', () {
    testWidgets('bell badge, tap-through, mark all read', (tester) async {
      final container = await openCircle(tester, now: fixed);
      final count = await badgeOf(container);
      expect(count, greaterThan(0));
      await tester.pumpAndSettle();
      expect(badgeText(count), findsOneWidget);
      await tester.tap(find.byTooltip('Activity'));
      await tester.pumpAndSettle();
      expect(currentUri(container).path, '/activity');
      expect(find.text('Today'), findsOneWidget);
      await reveal(tester, find.text('Earlier'));
      expect(find.text('Earlier'), findsOneWidget);
      await tapText(tester, 'Kavya wants to send you a message');
      expect(currentUri(container).path, '/chats/c/d-kavya-you');
      expect(await badgeOf(container), count - 1);
      await go(tester, container, '/chats');
      expect(badgeText(count - 1), findsOneWidget);
      await tester.tap(find.byTooltip('Activity'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Mark all read');
      expect(await badgeOf(container), 0);
      await go(tester, container, '/home');
      expect(
        tester
            .widget<Badge>(find.byKey(const ValueKey('activity-badge')))
            .isLabelVisible,
        isFalse,
      );
    });

    testWidgets('an item you can no longer open says so calmly', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      // Leave Northbank 2009: the role-change item now points nowhere.
      await container
          .read(circleWorkspaceProvider.notifier)
          .leaveGroup('college');
      await go(tester, container, '/activity');
      await tapText(tester, 'Mira made you an admin of Northbank 2009');
      expect(find.text('That’s no longer available to you.'), findsOneWidget);
      expect(currentUri(container).path, '/activity');
    });

    testWidgets('notification settings change what the badge counts', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      final before = await badgeOf(container);
      await go(tester, container, '/you/notifications');
      // Preview labels are no longer drawn (owner, 28 Oct 2026).
      expect(find.byType(PreviewLabel, skipOffstage: false), findsOneWidget);
      expect(find.text('Push (personal)'), findsOneWidget);
      await reveal(tester, find.text('New Memories in your groups'));
      await tester.tap(find.text('New Memories in your groups'));
      await tester.pumpAndSettle();
      final promoted = await badgeOf(container);
      expect(promoted, greaterThan(before));
      // Northbank 2009 is big: mentions only by default.
      await reveal(tester, find.text('Northbank 2009'));
      expect(
        find.textContaining('Mentions and replies only (default)'),
        findsOneWidget,
      );
      await tester.tap(find.text('Northbank 2009'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(RadioListTile<GroupNotifyLevel>, 'Everything'),
      );
      await tester.pumpAndSettle();
      expect(
        await badgeOf(container),
        promoted + 1,
        reason: 'Mira’s reunion Memory',
      );
      // Quiet hours are on by default, 10 PM–7 AM.
      await reveal(tester, find.text('Quiet hours'));
      expect(find.textContaining('10:00 PM–7:00 AM'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('results grouped and scoped to your circles', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('search-field'));
      await tester.enterText(field, 's');
      await tester.pumpAndSettle();
      expect(find.text('Type at least 2 characters.'), findsOneWidget);
      await tester.enterText(field, 'sunday');
      await tester.pumpAndSettle();
      expect(find.text('Groups (2)'), findsOneWidget);
      expect(find.textContaining('Messages ('), findsOneWidget);
      await tester.enterText(field, 'surprise');
      await tester.pumpAndSettle();
      expect(find.text('No results'), findsOneWidget);
      await tester.enterText(field, 'window-seat');
      await tester.pumpAndSettle();
      await tapText(tester, 'The window-seat crew');
      expect(currentUri(container).path, '/groups/g/friends');
    });
  });

  group('reporting and moderation', () {
    testWidgets('report a Memory; admins see it in the queue', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await tester.tap(
        find.byTooltip('More options for Memory from Mira in The Sunday table'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.text('Report this Memory'), findsOneWidget);
      final send = find.widgetWithText(FilledButton, 'Send report');
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      await tester.tap(find.text('Private information'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Add a note (optional)'),
        'Shows a home address.',
      );
      await tapText(tester, 'Send report');
      expect(
        find.text('Thanks — admins of this group will review it.'),
        findsOneWidget,
      );
      expect(workspaceOf(container).reportedByMe, contains('memory:table'));
      // The viewer owns The Sunday table: one item to review.
      await go(tester, container, '/groups/g/family');
      await tapText(tester, '1 report');
      expect(find.textContaining('Private information'), findsOneWidget);
      expect(find.text('Note: Shows a home address.'), findsOneWidget);
    });

    testWidgets('report a chat message to the group’s admins', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/g-college');
      await longPressMessage(tester, spam);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spam'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Send report');
      final queue = await container
          .read(circleRepositoryProvider)
          .queue('you', 'college');
      expect(
        queue.items
            .firstWhere((i) => i.target.key == 'message:college-spam')
            .count,
        3,
      );
    });

    testWidgets('an admin hides a message, then unhides it', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/groups/g/college');
      await tapText(tester, '2 reports');
      expect(find.text('To review (2)'), findsOneWidget);
      expect(find.text('Spam ×2 · 4h ago'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Hide this message'));
      await tester.pumpAndSettle();
      expect(find.text('Hidden from members.'), findsOneWidget);
      final members = await container
          .read(circleRepositoryProvider)
          .load('sam');
      expect(members.hiddenByAdmins, contains('message:college-spam'));
      await go(tester, container, '/chats/c/g-college');
      await tester.scrollUntilVisible(
        find.text('Hidden by admins · only admins see it'),
        200,
        scrollable: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable && widget.axisDirection == AxisDirection.up,
        ),
      );
      expect(
        find.text('Hidden by admins · only admins see it'),
        findsOneWidget,
      );
      await go(tester, container, '/groups/g/college/reports');
      await tester.tap(find.bySemanticsLabel('Unhide this message'));
      await tester.pumpAndSettle();
      expect(find.text('Shown to everyone again.'), findsOneWidget);
      await reveal(tester, find.text('You unhid a message · Just now'));
      expect(find.text('You hid a message · Just now'), findsOneWidget);
      expect(workspaceOf(container).hiddenByAdmins, isEmpty);
    });

    testWidgets('a parent admin removes a reported subgroup unseen', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/groups/g/college/reports');
      expect(find.text('Late-night memes'), findsOneWidget);
      expect(
        find.text('3 members · You can remove it without opening it.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Jokes about'),
        findsNothing,
        reason: 'unread',
      );
      await reveal(
        tester,
        find.bySemanticsLabel('Remove subgroup Late-night memes'),
      );
      await tester.tap(
        find.bySemanticsLabel('Remove subgroup Late-night memes'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Remove Late-night memes?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Remove subgroup'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Late-night memes was removed.'), findsOneWidget);
      expect(
        workspaceOf(container).discoverable.map((p) => p.id),
        isNot(contains('memes')),
      );
      await go(tester, container, '/groups/g/college');
      await openTab(tester, 'Subgroups');
      expect(find.text('Late-night memes'), findsNothing);
    });

    testWidgets('members report a listed subgroup from Subgroups', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/groups/g/college');
      await openTab(tester, 'Subgroups');
      await reveal(
        tester,
        find.bySemanticsLabel('Report subgroup Electronics'),
      );
      await tester.tap(find.bySemanticsLabel('Report subgroup Electronics'));
      await tester.pumpAndSettle();
      expect(find.text('Report Electronics'), findsOneWidget);
      await tester.tap(find.text('Something else'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Send report');
      expect(workspaceOf(container).reportedByMe, contains('subgroup:ece'));
    });
  });

  group('profiles', () {
    testWidgets('Message is disabled when they can’t be messaged', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/people/tomas');
      expect(find.text('Groups in common (1)'), findsOneWidget);
      final message = find.byKey(const ValueKey('profile-message'));
      expect(tester.widget<ButtonStyleButton>(message).onPressed, isNull);
      expect(
        find.text('Tomas isn’t accepting messages right now.'),
        findsOneWidget,
      );
      await go(tester, container, '/people/mira');
      expect(tester.widget<ButtonStyleButton>(message).onPressed, isNotNull);
      await tester.tap(message);
      await tester.pumpAndSettle();
      expect(currentUri(container).path, '/chats/c/d-mira-you');
      // No profile for people you share no group with.
      await go(tester, container, '/people/lena-unknown');
      expect(find.text('This profile isn’t available'), findsOneWidget);
    });

    testWidgets('members open profiles and can block from there', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/groups/g/family');
      await openTab(tester, 'Members');
      await tapText(tester, 'Priya');
      expect(currentUri(container).path, '/people/priya');
      await tapText(tester, 'Block Priya');
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();
      expect(find.text('Priya blocked.'), findsOneWidget);
      expect(find.text('Unblock Priya'), findsOneWidget);
    });

    testWidgets('You lists Activity, Notifications, Privacy and Account', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/you');
      for (final entry in ['Activity', 'Notifications', 'Privacy', 'Account']) {
        await reveal(tester, find.text(entry));
        expect(find.text(entry), findsOneWidget, reason: entry);
      }
      await tapText(tester, 'Account');
      expect(find.text('Comes before launch'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Delete account'), findsNothing);
      expect(find.text('End preview and clear local changes'), findsOneWidget);
    });
  });

  testWidgets('ending the preview clears albums, reports and activity', (
    tester,
  ) async {
    final container = await openCircle(tester, now: fixed);
    final badge = await badgeOf(container);
    await container
        .read(albumControllerProvider.notifier)
        .create('club', 'Gone soon');
    await container
        .read(circleWorkspaceProvider.notifier)
        .hide('college', 'message:college-spam');
    await container.read(notificationControllerProvider.notifier).markAllRead();
    expect(await badgeOf(container), 0);
    await go(tester, container, '/you/account');
    await tapText(tester, 'End preview and clear local changes');
    await container
        .read(circlePreviewSessionProvider.notifier)
        .enter(showcase: true);
    await tester.pumpAndSettle();
    final albums = await container
        .read(albumRepositoryProvider)
        .albums('you', 'club');
    expect(albums.map((album) => album.title), ['Ride days']);
    expect(workspaceOf(container).hiddenByAdmins, isEmpty);
    expect(await badgeOf(container), badge);
  });

  group('tablet two-pane', () {
    for (final size in [const Size(900, 1100), const Size(1280, 800)]) {
      testWidgets(
        'chats, groups and events show detail beside the list at $size',
        (tester) async {
          final container = await openCircle(tester, now: fixed, size: size);
          await go(tester, container, '/chats');
          expect(find.text('Choose a chat'), findsOneWidget);
          await tester.tap(find.text('Mira'));
          await tester.pumpAndSettle();
          expect(currentUri(container).path, '/chats', reason: 'no push');
          expect(bubble('Sounds lovely. 7:30?'), findsOneWidget);
          expect(
            find.text('Northbank 2009'),
            findsWidgets,
            reason: 'list stays',
          );

          await go(tester, container, '/groups');
          await tester.dragUntilVisible(
            find.text('Studio North'),
            find.byType(ListView).first,
            const Offset(0, -200),
          );
          // Centre the complete row above the rounded dock before tapping.
          await reveal(tester, find.text('Studio North'));
          await tester.tap(find.text('Studio North'));
          await tester.pumpAndSettle();
          expect(currentUri(container).path, '/groups');
          expect(find.byType(TabBar), findsOneWidget);
          // The list stays beside the detail: the name shows in both.
          expect(find.text('Studio North'), findsAtLeast(2));

          await go(tester, container, '/events');
          await tester.dragUntilVisible(
            find.text('A Sunday well spent'),
            find.byType(ListView).first,
            const Offset(0, -200),
          );
          await reveal(tester, find.text('A Sunday well spent'));
          await tester.tap(find.text('A Sunday well spent'));
          await tester.pumpAndSettle();
          expect(currentUri(container).path, '/events');
          expect(find.text('Are you coming?'), findsOneWidget);
          expect(
            find.text('A Sunday well spent'),
            findsNWidgets(2),
            reason: 'the list card stays beside the detail',
          );

          // Deep links still work and show both panes.
          await go(tester, container, '/chats/c/d-dev-you');
          expect(bubble('Ha, ignored 🙈'), findsOneWidget);
          expect(find.text('Choose a chat'), findsNothing);
          expect(find.text('Mira'), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('phones keep single pages', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats');
      await tester.tap(find.text('Mira'));
      await tester.pumpAndSettle();
      expect(currentUri(container).path, '/chats/c/d-mira-you');
      expect(find.text('Choose a chat'), findsNothing);
    });
  });

  for (final route in [
    '/activity',
    '/you/notifications',
    '/groups/g/college/reports',
    '/people/mira',
    '/groups/g/club/albums/ride-days',
  ]) {
    testWidgets('$route has accessible labels and touch targets', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, route);
      final handle = tester.ensureSemantics();
      try {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });
  }

  for (final size in [
    const Size(360, 800),
    const Size(393, 852),
    const Size(900, 1100),
  ]) {
    testWidgets('UI-6 screens support dark, 200% text at $size', (
      tester,
    ) async {
      final container = await openCircle(
        tester,
        now: fixed,
        size: size,
        scale: 2,
        brightness: Brightness.dark,
      );
      for (final route in [
        '/activity',
        '/search',
        '/you/notifications',
        '/you/account',
        '/you',
        '/people/mira',
        '/people/tomas',
        '/groups/g/college/reports',
        '/groups/g/family/reports',
        '/groups/g/work/reports',
        '/groups/g/club/albums/ride-days',
        '/groups/g/club/albums/ride-days/photos?index=1',
        '/groups/g/college/albums/missing',
        '/events/e/picnic',
        '/chats/c/g-college',
      ]) {
        await go(tester, container, route);
        expect(tester.takeException(), isNull, reason: route);
      }
      await go(tester, container, '/search');
      await tester.enterText(
        find.byKey(const ValueKey('search-field')),
        'mira',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'search results');
      await go(tester, container, '/groups/g/club');
      await openTab(tester, 'Albums');
      expect(tester.takeException(), isNull, reason: 'albums tab');
      await tapText(tester, 'New album');
      expect(tester.takeException(), isNull, reason: 'new album sheet');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await go(tester, container, '/home/memory/table');
      await tester.tap(
        find.byTooltip('More options for Memory from Mira in The Sunday table'),
      );
      await tester.pumpAndSettle();
      // The menu item (comments below also offer "Report").
      await tester.tap(find.text('Report').last);
      await tester.pumpAndSettle();
      expect(find.text('Report this Memory'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'report sheet');
    });
  }
}
