import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/application/chat_providers.dart';
import 'package:mobile/features/chat/presentation/chat_message.dart';
import 'package:mobile/features/chat/presentation/chat_visuals.dart';
import 'package:mobile/features/memories/presentation/memory_poll_card.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/circle_harness.dart';

final fixed = DateTime.utc(2026, 10, 23, 12);
const walk = 'Also, are you free for a walk tomorrow morning?';

Future<ConversationView> conversationOf(
  ProviderContainer container,
  String id, {
  String viewer = 'you',
}) => container.read(chatRepositoryProvider).conversation(viewer, id);

Future<ChatInbox> inboxOf(ProviderContainer container) =>
    container.read(chatRepositoryProvider).inbox('you');

Finder get composer => find.byKey(const ValueKey('chat-composer'));

/// The bubble with [text] (not a quote of it).
Finder bubble(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is Text && widget.key == bubbleTextKey && widget.data == text,
);

Future<void> sendText(WidgetTester tester, String text) async {
  await tester.enterText(composer, text);
  await tester.pump();
  await tester.tap(find.byTooltip('Send'));
  await tester.pumpAndSettle();
}

/// Clears snackbars that would sit over the bottom of a short page.
Future<void> clearSnackBars(WidgetTester tester) async {
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
      .removeCurrentSnackBar();
  await tester.pumpAndSettle();
}

/// Scrolls the conversation (a reversed list) until [finder] is built.
Future<void> revealMessage(WidgetTester tester, Finder finder) async {
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
}

Future<void> longPressText(WidgetTester tester, String text) async {
  await revealMessage(tester, bubble(text));
  await tester.longPress(bubble(text));
  await tester.pumpAndSettle();
}

void main() {
  group('inbox', () {
    testWidgets('tabs, search, pin, mute and archive with Undo', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Chats'));
      await tester.pumpAndSettle();
      expect(find.text(chatPreviewNote), findsOneWidget);
      expect(find.text('New chat'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Requests (1)'), findsOneWidget);
      expect(find.text('Seen by Mira, Dev'), findsOneWidget);

      // Search filters by name.
      await tester.enterText(
        find.widgetWithText(TextField, 'Search chats'),
        'sunday',
      );
      await tester.pumpAndSettle();
      expect(find.text('The Sunday table'), findsOneWidget);
      expect(find.text('Sunday miles'), findsOneWidget);
      expect(find.text('Mira'), findsNothing);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Mira'), findsOneWidget);

      // Pin from the visible ⋮ menu.
      await tester.tap(find.byTooltip('More options for The Sunday table'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pin'));
      await tester.pumpAndSettle();
      expect(find.text('Pinned to the top.'), findsOneWidget);
      var inbox = await inboxOf(container);
      expect(inbox.chats.take(2).map((c) => c.id), ['g-family', 'd-mira-you']);

      // Mute from the long-press menu.
      await tester.longPress(find.text('Dev'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mute'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('For 8 hours'));
      await tester.pumpAndSettle();
      expect(find.text('Dev muted.'), findsOneWidget);
      inbox = await inboxOf(container);
      expect(inbox.chats.firstWhere((c) => c.id == 'd-dev-you').muted, isTrue);

      // Swipe to archive, then Undo.
      await tester.drag(find.text('Dev'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Dev archived.'), findsOneWidget);
      expect(find.text('Dev'), findsNothing);
      expect((await inboxOf(container)).archived, hasLength(2));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Dev'), findsOneWidget);
      inbox = await inboxOf(container);
      expect(inbox.archived.map((c) => c.id), ['d-lena-you']);

      // Archive from the menu too; the Archived entry lists it.
      await tester.tap(find.byTooltip('More options for Dev'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      await clearSnackBars(tester);
      await tapText(tester, 'Archived (2)');
      expect(currentUri(container).path, '/chats/archived');
      expect(find.text('Lena'), findsOneWidget);
      expect(find.text('Dev'), findsOneWidget);

      // Requests tab.
      await go(tester, container, '/chats');
      await openTab(tester, 'Requests (1)');
      expect(find.text('Kavya'), findsOneWidget);
    });
  });

  testWidgets('new chat shows who can’t be messaged and why', (tester) async {
    final container = await openCircle(tester, now: fixed);
    await go(tester, container, '/chats');
    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();
    expect(currentUri(container).path, '/chats/new');
    await tester.enterText(
      find.widgetWithText(TextField, 'Search people'),
      'noor',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Only accepts messages from people they’ve chatted with'),
      findsOneWidget,
    );
    ListTile tile(String name) => tester.widget<ListTile>(
      find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
    );
    expect(tile('Noor').enabled, isFalse);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search people'),
      'tomas',
    );
    await tester.pumpAndSettle();
    expect(find.text('Isn’t accepting messages'), findsOneWidget);
    expect(tile('Tomas').enabled, isFalse);
    await tester.tap(find.text('Tomas'));
    await tester.pumpAndSettle();
    expect(currentUri(container).path, '/chats/new');

    await tester.enterText(
      find.widgetWithText(TextField, 'Search people'),
      'priya',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Priya'));
    await tester.pumpAndSettle();
    expect(currentUri(container).path, '/chats/c/d-priya-you');
    expect(find.text('No messages yet. Say hello to Priya.'), findsOneWidget);
    await sendText(tester, 'Hi Priya!');
    final inbox = await inboxOf(container);
    expect(inbox.chats.map((c) => c.id), contains('d-priya-you'));
  });

  group('conversation', () {
    testWidgets('send: the button waits for text; Sent replaces Seen', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/d-mira-you');
      expect(find.text(chatPreviewNote), findsOneWidget);
      expect(find.text('Seen'), findsOneWidget);
      IconButton send() => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send),
      );
      expect(send().onPressed, isNull);
      await tester.enterText(composer, '   ');
      await tester.pump();
      expect(send().onPressed, isNull);
      await sendText(tester, 'See you at 7:30!');
      expect(find.text('See you at 7:30!'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Seen'), findsNothing);
      expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
      expect((await conversationOf(container, 'd-mira-you')).status, 'Sent');
    });

    testWidgets('double-tap ❤️ toggles; the menu picks any of 8', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/d-mira-you');
      Future<String?> mine() async => (await conversationOf(
        container,
        'd-mira-you',
      )).messages.firstWhere((m) => m.text == walk).reactions.mine;

      await tester.tap(bubble(walk));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(bubble(walk));
      await tester.pumpAndSettle();
      expect(await mine(), '❤️');
      // Mira's ❤️ on your seeded message, and now yours on hers.
      expect(
        find.bySemanticsLabel(RegExp('1 reaction: 1 Love')),
        findsNWidgets(2),
      );

      await longPressText(tester, walk);
      expect(find.text('Message options'), findsOneWidget);
      await tester.tap(find.text('😂'));
      await tester.pumpAndSettle();
      expect(await mine(), '😂');

      // Double-tap again: ❤️ replaces 😂; once more removes it.
      for (final expected in ['❤️', null]) {
        await tester.tap(bubble(walk));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(bubble(walk));
        await tester.pumpAndSettle();
        expect(await mine(), expected);
      }
    });

    testWidgets('a single tap shows Love, Reply and More buttons', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/d-mira-you');
      await tester.tap(bubble(walk));
      // Waits out the double-tap window.
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.widgetWithText(TextButton, 'Love'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Love'));
      await tester.pumpAndSettle();
      final message = (await conversationOf(
        container,
        'd-mira-you',
      )).messages.firstWhere((m) => m.text == walk);
      expect(message.reactions.mine, '❤️');
      await tester.tap(find.widgetWithText(TextButton, 'Reply'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Cancel reply'), findsOneWidget);
    });

    testWidgets('swipe right to reply, or Reply in the menu', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/d-mira-you');
      await tester.drag(bubble(walk), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Cancel reply'), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel reply'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Cancel reply'), findsNothing);

      await longPressText(tester, walk);
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Cancel reply'), findsOneWidget);
      await sendText(tester, 'Yes, 7:30 works.');
      final view = await conversationOf(container, 'd-mira-you');
      final reply = view.messages.last;
      expect(reply.text, 'Yes, 7:30 works.');
      expect(reply.replyTo?.text, walk);
      expect(find.byTooltip('Cancel reply'), findsNothing);
      // The quote shows inside the conversation (twice: the seeded reply
      // and the new one).
      expect(find.text('Replying to Mira'), findsNWidgets(2));
    });

    testWidgets('edit within 15 minutes, not after', (tester) async {
      var now = fixed;
      final container = await openCircle(tester, clock: () => now);
      await go(tester, container, '/chats/c/d-mira-you');
      await sendText(tester, 'Helo');
      now = now.add(const Duration(minutes: 14));
      await longPressText(tester, 'Helo');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Message'),
        'Hello',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Edited'), findsOneWidget);

      now = now.add(const Duration(minutes: 2));
      await longPressText(tester, 'Hello');
      expect(find.text('Message options'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Unsend'), findsOneWidget);
      // Seeded messages are long past the window.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await longPressText(tester, 'Sounds lovely. 7:30?');
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('unsend shows a placeholder; Undo restores it', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/d-mira-you');
      await sendText(tester, 'Wrong chat!');
      await longPressText(tester, 'Wrong chat!');
      await tester.tap(find.text('Unsend'));
      await tester.pumpAndSettle();
      expect(find.text('Message unsent.'), findsOneWidget);
      expect(find.text('You unsent a message'), findsOneWidget);
      expect(find.text('Wrong chat!'), findsNothing);
      final mira = await conversationOf(
        container,
        'd-mira-you',
        viewer: 'mira',
      );
      expect(mira.messages.last.summary, 'Message unsent');
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Wrong chat!'), findsOneWidget);
    });

    testWidgets('report and copy are local and calm', (tester) async {
      final copied = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') copied.add(call.arguments);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/d-mira-you');
      await longPressText(tester, walk);
      expect(find.text('Unsend'), findsNothing, reason: 'not your message');
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      // The shared report flow: a reason (required), then Send report.
      await tester.tap(find.text('Spam'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Send report');
      expect(find.text('Thanks — we’ll review it.'), findsOneWidget);
      await go(tester, container, '/chats/c/g-family');
      await longPressText(tester, 'Room for one more, always.');
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Harassment or bullying'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Send report');
      expect(
        find.text('Thanks — admins of this group will review it.'),
        findsOneWidget,
      );
      await longPressText(tester, 'Room for one more, always.');
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(find.text('Copied.'), findsOneWidget);
      expect(copied.single, {'text': 'Room for one more, always.'});
    });
  });

  group('message requests', () {
    testWidgets('accept: no composer until accepted', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats');
      await openTab(tester, 'Requests (1)');
      await tester.tap(find.text('Kavya'));
      await tester.pumpAndSettle();
      expect(currentUri(container).path, '/chats/c/d-kavya-you');
      expect(find.textContaining('wants to send you a message'), findsOne);
      expect(find.textContaining('Northbank 2009'), findsWidgets);
      expect(composer, findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
      await tester.pumpAndSettle();
      expect(composer, findsOneWidget);
      await sendText(tester, 'Of course! Sending it now.');
      expect(bubble('Of course! Sending it now.'), findsOneWidget);
      expect(
        (await conversationOf(
          container,
          'd-kavya-you',
          viewer: 'kavya',
        )).status,
        'Seen',
      );
    });

    testWidgets('delete with Undo', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/d-kavya-you');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(currentUri(container).path, '/chats');
      expect(find.text('Request deleted.'), findsOneWidget);
      expect((await inboxOf(container)).requests, isEmpty);
      expect(find.widgetWithText(Tab, 'Requests'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect((await inboxOf(container)).requests, hasLength(1));
    });

    testWidgets('block asks first, then the request vanishes', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/d-kavya-you');
      await tester.tap(find.widgetWithText(TextButton, 'Block'));
      await tester.pumpAndSettle();
      expect(find.text('Block Kavya?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();
      expect(currentUri(container).path, '/chats');
      expect((await inboxOf(container)).requests, isEmpty);
      final privacy = await container
          .read(chatRepositoryProvider)
          .privacy('you');
      expect(privacy.blocked.single.id, 'kavya');
    });
  });

  group('shared content', () {
    testWidgets('a Memory you can’t see stays private', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/d-dev-you');
      expect(find.text('This Memory isn’t shared with you'), findsOneWidget);
      expect(find.text('A private planning note.'), findsNothing);
    });

    testWidgets('share a Memory and an event; cards open them', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/d-mira-you');
      await tester.tap(
        find.byTooltip('Add photos, a Memory, an event or a poll'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share a Memory'));
      await tester.pumpAndSettle();
      await tapText(
        tester,
        'A slow ride, a long breakfast, and absolutely no one checking the time.',
      );
      expect(find.text('Sharing a Memory'), findsOneWidget);
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Sharing a Memory'), findsNothing);
      var last = (await conversationOf(container, 'd-mira-you')).messages.last;
      expect(last.shared?.content, const SharedContent.memory('ride'));
      // Mira is in Sunday miles too, so she sees it.
      final hers = await conversationOf(
        container,
        'd-mira-you',
        viewer: 'mira',
      );
      expect(hers.messages.last.shared!.visible, isTrue);

      await tester.tap(
        find.byTooltip('Add photos, a Memory, an event or a poll'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share an event'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Take the long way home');
      await sendText(tester, 'Coming?');
      last = (await conversationOf(container, 'd-mira-you')).messages.last;
      expect(last.shared?.content, const SharedContent.event('cycling'));
      expect(last.text, 'Coming?');
      await revealMessage(tester, find.text('Take the long way home'));
      await tester.tap(find.text('Take the long way home'));
      await tester.pumpAndSettle();
      expect(currentUri(container).path, '/events/e/cycling');
    });

    testWidgets('polls in chat use the poll card', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/d-mira-you');
      await tester.tap(
        find.byTooltip('Add photos, a Memory, an event or a poll'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poll'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Poll question'),
        'Tea or coffee?',
      );
      await tester.tap(find.text('Send poll'));
      await tester.pumpAndSettle();
      expect(find.text('Each option needs 1–80 characters.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Option 1'), 'Tea');
      await tester.enterText(
        find.widgetWithText(TextField, 'Option 2'),
        'Coffee',
      );
      await tester.tap(find.text('Send poll'));
      await tester.pumpAndSettle();
      expect(find.byType(PollCard), findsOneWidget);
      expect(find.text('Tea or coffee?'), findsOneWidget);
      await tester.tap(find.text('Tea'));
      await tester.pumpAndSettle();
      expect(find.text('Vote saved.'), findsOneWidget);
      final poll = (await conversationOf(
        container,
        'd-mira-you',
      )).messages.last.poll!;
      expect(poll.myChoices, hasLength(1));
    });

    testWidgets('the seeded group poll and shared event render', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/g-work');
      expect(find.text('Team lunch on Friday?'), findsOneWidget);
      await go(tester, container, '/chats/c/g-college');
      expect(find.text('57 members'), findsOneWidget);
      await revealMessage(tester, find.text('Fifteen-year reunion dinner'));
      expect(find.text('Fifteen-year reunion dinner'), findsOneWidget);
    });
  });

  group('entry points', () {
    testWidgets('the group space Chat tab opens that group’s chat', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/groups/g/family');
      await openTab(tester, 'Chat');
      await tapText(tester, 'Open group chat');
      expect(currentUri(container).path, '/chats/c/g-family');
      expect(find.text('4 members'), findsOneWidget);
      expect(find.text('Seen by Mira, Dev'), findsOneWidget);
      await tester.tap(find.byTooltip('Chat details'));
      await tester.pumpAndSettle();
      expect(currentUri(container).path, '/chats/c/g-family/details');
      expect(find.text('Members (4)'), findsOneWidget);
      expect(find.text('Shared Memories and events (1)'), findsOneWidget);
      await tapText(tester, 'Open group space');
      expect(currentUri(container).path, '/groups/g/family');
    });

    testWidgets('Reply privately opens the 1:1 with the Memory attached', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await reveal(
        tester,
        find.byTooltip('More options for Memory from Mira in The Sunday table'),
      );
      await tester.tap(
        find.byTooltip('More options for Memory from Mira in The Sunday table'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reply privately'));
      await tester.pumpAndSettle();
      expect(currentUri(container).path, '/chats/c/d-mira-you');
      expect(find.text('Sharing a Memory'), findsOneWidget);
      await sendText(tester, 'Love this one.');
      final last = (await conversationOf(
        container,
        'd-mira-you',
      )).messages.last;
      expect(last.shared?.content, const SharedContent.memory('table'));
      expect(last.text, 'Love this one.');
    });

    testWidgets('Reply privately explains calmly when it isn’t possible', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/reply/route-poll');
      expect(find.text('You can’t reply privately here'), findsOneWidget);
      expect(
        find.textContaining('Tomas isn’t accepting messages right now.'),
        findsOneWidget,
      );
      await go(tester, container, '/chats/reply/private-memory');
      expect(find.text('This Memory isn’t shared with you.'), findsOneWidget);
      expect(currentUri(container).path, '/chats/reply/private-memory');
    });
  });

  testWidgets('privacy settings change who can reach you', (tester) async {
    final container = await openCircle(tester, now: fixed);
    final repository = container.read(chatRepositoryProvider);
    await go(tester, container, '/you');
    await tapText(tester, 'Privacy');
    expect(currentUri(container).path, '/you/privacy');

    await tapText(tester, 'Nobody');
    expect(find.text('Saved: Nobody.'), findsOneWidget);
    await expectLater(
      repository.send('mira', 'd-mira-you', clientMessageId: 'x', text: 'Hi'),
      throwsA(isA<CircleFailure>()),
    );
    await tapText(tester, 'Everyone in my groups');

    // Mark the big Northbank 2009 group close: first messages skip Requests.
    final northbank = find.widgetWithText(SwitchListTile, 'Northbank 2009');
    await reveal(tester, northbank);
    expect(tester.widget<SwitchListTile>(northbank).value, isFalse);
    await tester.tap(northbank);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(northbank).value, isTrue);
    final id = await repository.openDirect('asha', 'you');
    await repository.send('asha', id, clientMessageId: 'y', text: 'Hello!');
    expect(
      (await repository.inbox('you')).chats.map((c) => c.id),
      contains('d-asha-you'),
    );

    // Blocked people can be unblocked, with Undo.
    await container.read(chatControllerProvider.notifier).block('kavya');
    await tester.pumpAndSettle();
    await clearSnackBars(tester);
    await tapText(tester, 'Unblock');
    expect(find.text('Kavya unblocked.'), findsOneWidget);
    expect((await repository.privacy('you')).blocked, isEmpty);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await repository.privacy('you')).blocked.single.id, 'kavya');
  });

  testWidgets('leaving a group leaves its chat read-only', (tester) async {
    final container = await openCircle(tester, now: fixed);
    await go(tester, container, '/chats/c/g-work');
    expect(composer, findsOneWidget);
    await container.read(circleWorkspaceProvider.notifier).leaveGroup('work');
    await tester.pumpAndSettle();
    expect(composer, findsNothing);
    expect(find.textContaining('You left this group'), findsWidgets);
    expect(find.text('Team lunch on Friday?'), findsOneWidget);
  });

  testWidgets('ending the preview clears chats', (tester) async {
    final container = await openCircle(tester, now: fixed);
    await go(tester, container, '/chats/c/d-mira-you');
    await sendText(tester, 'Remember me?');
    await container.read(circlePreviewSessionProvider.notifier).leave();
    await tester.pumpAndSettle();
    await container
        .read(circlePreviewSessionProvider.notifier)
        .enter(showcase: true);
    await tester.pumpAndSettle();
    final view = await conversationOf(container, 'd-mira-you');
    expect(view.messages.map((m) => m.text), isNot(contains('Remember me?')));
  });

  group('activity status', () {
    final activeDot = find.byKey(const ValueKey('circle-active-dot'));

    testWidgets('shown in 1:1 only; the privacy switch hides it both ways', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      final handle = tester.ensureSemantics();
      await go(tester, container, '/chats');
      // Only Mira is active now: one calm dot, nothing else in the row.
      expect(activeDot, findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Mira, active now')),
        findsOneWidget,
      );
      expect(find.textContaining('Active'), findsNothing);

      await go(tester, container, '/chats/c/d-mira-you');
      expect(find.text('Active now'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Mira, active now. Open chat details')),
        findsOneWidget,
      );
      await go(tester, container, '/chats/c/d-dev-you');
      expect(find.text('Active 2h ago'), findsOneWidget);
      // Never in group chats.
      await go(tester, container, '/chats/c/g-family');
      expect(find.textContaining('Active'), findsNothing);
      await go(tester, container, '/chats/c/g-family/details');
      expect(find.textContaining('Active'), findsNothing);
      expect(activeDot, findsNothing);

      await go(tester, container, '/you/privacy');
      final toggle = find.widgetWithText(
        SwitchListTile,
        'Show activity status',
      );
      await reveal(tester, toggle);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      expect(
        find.text(
          'When this is off, people can’t see when you were last active, '
          'and you can’t see theirs.',
        ),
        findsOneWidget,
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      expect(find.text('Activity status is off.'), findsOneWidget);

      await go(tester, container, '/chats');
      expect(activeDot, findsNothing);
      expect(find.bySemanticsLabel(RegExp('^Mira, active now')), findsNothing);
      await go(tester, container, '/chats/c/d-mira-you');
      expect(find.text('Active now'), findsNothing);
      expect(find.textContaining('In The Sunday table'), findsOneWidget);
      // Reciprocal: Mira can't see yours either.
      final hers = await conversationOf(
        container,
        'd-mira-you',
        viewer: 'mira',
      );
      expect(hers.activity, isNull);
      handle.dispose();
    });

    testWidgets('New chat shows activity under names', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/new');
      final search = find.widgetWithText(TextField, 'Search people');
      await tester.enterText(search, 'mira');
      await tester.pumpAndSettle();
      expect(find.text('Active now'), findsWidgets);
      await tester.enterText(search, 'priya');
      await tester.pumpAndSettle();
      expect(find.text('Active 35m ago'), findsOneWidget);
      // Unknown activity shows nothing; reasons still come first.
      await tester.enterText(search, 'noor');
      await tester.pumpAndSettle();
      expect(find.textContaining('Active'), findsNothing);
      expect(
        find.text('Only accepts messages from people they’ve chatted with'),
        findsOneWidget,
      );
    });
  });

  group('share picker', () {
    Finder inSheet(String text) => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(text),
    );
    const ride =
        'A slow ride, a long breakfast, and absolutely no one checking the time.';
    const table =
        'Same table, a few new stories. Sunday lunch is still my favourite '
        'way to bring everyone together.';
    const oldDays =
        'Found our old project notes. The ideas were ambitious. The '
        'handwriting, less so.';

    Future<void> openPicker(WidgetTester tester, String option) async {
      await tester.tap(
        find.byTooltip('Add photos, a Memory, an event or a poll'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(option));
      await tester.pumpAndSettle();
    }

    testWidgets('1:1 lists only what both people can see', (tester) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/d-mira-you');
      await openPicker(tester, 'Share a Memory');
      expect(inSheet(table), findsOneWidget);
      expect(inSheet(ride), findsOneWidget);
      // Mira isn't in The window-seat crew.
      expect(inSheet(oldDays), findsNothing);
      expect(inSheet('A private planning note.'), findsNothing);
    });

    testWidgets('group chat lists only what every member can see', (
      tester,
    ) async {
      final container = await openCircle(tester, now: fixed);
      await go(tester, container, '/chats/c/g-family');
      await openPicker(tester, 'Share a Memory');
      expect(inSheet(table), findsOneWidget);
      expect(inSheet(ride), findsNothing);
      expect(inSheet(oldDays), findsNothing);
      expect(
        inSheet('Fifteen years! Help me pick a place for the reunion dinner.'),
        findsNothing,
      );
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      await openPicker(tester, 'Share an event');
      expect(inSheet('Take the long way home'), findsNothing);
    });

    testWidgets('a calm empty state when nothing qualifies', (tester) async {
      final container = await openCircle(tester, now: fixed);
      // You and Lena share only Studio North, which has no Memories.
      await go(tester, container, '/chats/c/d-lena-you');
      await openPicker(tester, 'Share a Memory');
      expect(
        inSheet('Nothing here can be seen by everyone in this chat yet.'),
        findsOneWidget,
      );
    });
  });

  for (final size in [
    const Size(360, 800),
    const Size(393, 852),
    const Size(900, 1100),
  ]) {
    testWidgets('chat screens support dark, 200% text at $size', (
      tester,
    ) async {
      final container = await openCircle(
        tester,
        size: size,
        scale: 2,
        brightness: Brightness.dark,
        now: fixed,
      );
      for (final route in [
        '/chats',
        '/chats/new',
        '/chats/archived',
        '/chats/c/g-family',
        '/chats/c/g-college',
        '/chats/c/g-work',
        '/chats/c/d-mira-you',
        '/chats/c/d-dev-you',
        '/chats/c/d-kavya-you',
        '/chats/c/g-family/details',
        '/chats/c/d-mira-you/details',
        '/chats/c/g-unknown',
        '/you/privacy',
      ]) {
        await go(tester, container, route);
        expect(tester.takeException(), isNull, reason: route);
      }
      await go(tester, container, '/chats');
      await openTab(tester, 'Requests (1)');
      expect(tester.takeException(), isNull, reason: 'requests');
      await go(tester, container, '/chats/c/d-mira-you');
      await longPressText(tester, walk);
      expect(tester.takeException(), isNull, reason: 'message menu');
    });
  }

  for (final route in ['/chats', '/chats/c/d-mira-you', '/you/privacy']) {
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
}
