import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/circle_components.dart';
import 'package:mobile/features/memories/presentation/circle_memories.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/circle_harness.dart';

const _table = 'Memory from Mira in The Sunday table';

CircleMemory memoryOf(ProviderContainer container, String id) =>
    workspaceOf(container).memories.firstWhere((m) => m.id == id);

Future<void> enterField(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextField, label);
  await reveal(tester, field);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> tapTooltip(WidgetTester tester, String tooltip) async {
  await reveal(tester, find.byTooltip(tooltip));
  await tester.tap(find.byTooltip(tooltip).first);
  await tester.pumpAndSettle();
}

void main() {
  group('compose', () {
    testWidgets('photos, poll, year and place render on the new card', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/compose?group=family');
      await enterField(tester, 'Your Memory', 'A day by the water.');
      await tapText(tester, 'Add photos');
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is PreviewLabel &&
              w.text ==
                  'Preview: fictional illustrations — real uploads come later.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      for (final scene in ['Beach walk', 'Hill trip', 'Cricket match']) {
        await tapText(tester, scene);
      }
      expect(find.text('3 of 10 chosen'), findsOneWidget);
      await tapText(tester, 'Use 3 photos');
      expect(find.text('3 of 10 photos'), findsOneWidget);
      await tapTooltip(tester, 'Remove Cricket match photo');
      expect(find.text('2 of 10 photos'), findsOneWidget);

      await tapText(tester, 'Add a poll');
      await enterField(tester, 'Poll question', 'Swim or walk next time?');
      await enterField(tester, 'Option 1', 'Swim');
      await enterField(tester, 'Option 2', 'Walk');
      await tapText(tester, 'Add option');
      await enterField(tester, 'Option 3', 'Nap');
      await tapTooltip(tester, 'Remove option 3');
      expect(find.widgetWithText(TextField, 'Option 3'), findsNothing);

      await tapText(tester, 'More options');
      await enterField(tester, 'Year taken (optional)', '2007');
      await enterField(tester, 'Place (optional)', 'Kodaikanal');
      await tapText(tester, 'Share Memory');

      expect(currentUri(container).path, '/home');
      final memory = workspaceOf(
        container,
      ).memories.firstWhere((m) => m.text == 'A day by the water.');
      expect(memory.groupId, 'family');
      expect(memory.photos.map((p) => p.scene), [
        MemoryScene.beachWalk,
        MemoryScene.hillTrip,
      ]);
      expect(memory.poll!.options.map((o) => o.label), ['Swim', 'Walk']);
      expect(memory.takenLabel, 'Taken in 2007 · Kodaikanal');

      expect(find.text('A day by the water.'), findsOneWidget);
      expect(find.text('Taken in 2007 · Kodaikanal'), findsOneWidget);
      expect(find.text('Swim or walk next time?'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(
          'Photo 2 of 2: fictional illustration, Hill trip',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('a poll alone is enough; empty and invalid input is caught', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/compose?group=club');
      final before = workspaceOf(container).memories.length;
      await tapText(tester, 'Share Memory');
      expect(
        find.text(
          'Write 1–2000 characters, or add a photo or a poll, before sharing.',
        ),
        findsOneWidget,
      );
      await tapText(tester, 'Add a poll');
      await enterField(tester, 'Poll question', 'Which café?');
      await enterField(tester, 'Option 1', 'Corner café');
      await enterField(tester, 'Option 2', 'corner café ');
      await tapText(tester, 'More options');
      await enterField(tester, 'Year taken (optional)', '1900');
      await tapText(tester, 'Share Memory');
      expect(find.text('Each option needs to be different.'), findsOneWidget);
      expect(
        find.text('Use a year from 1950 to ${DateTime.now().year}.'),
        findsOneWidget,
      );
      expect(workspaceOf(container).memories, hasLength(before));
      await enterField(tester, 'Option 2', 'Lakeside kiosk');
      await enterField(tester, 'Year taken (optional)', '');
      await tapText(tester, 'Share Memory');
      expect(workspaceOf(container).memories, hasLength(before + 1));
      final memory = workspaceOf(container).memories.first;
      expect(memory.text, isEmpty);
      expect(memory.poll!.question, 'Which café?');
    });
  });

  group('polls', () {
    testWidgets('vote reveals results; change vote; undo; who voted', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/home/memory/reunion-poll');
      expect(find.text('Results appear after you vote.'), findsOneWidget);
      expect(find.text('3 votes · Closes in 2 days'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      await tapText(tester, 'Riverside café');
      expect(find.text('Vote saved.'), findsOneWidget);
      expect(find.text('50% · 2'), findsNWidgets(2));
      expect(find.text('4 votes · Closes in 2 days'), findsOneWidget);

      await tapText(tester, 'Change vote');
      expect(find.text('Choose one'), findsOneWidget);
      await tapText(tester, 'The old canteen');
      expect(find.text('75% · 3'), findsOneWidget);
      expect(memoryOf(container, 'reunion-poll').poll!.myChoices, {
        'reunion-canteen',
      });
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(memoryOf(container, 'reunion-poll').poll!.myChoices, {
        'reunion-cafe',
      });

      await tapText(tester, 'See who voted');
      expect(find.text('Who voted'), findsOneWidget);
      expect(find.text('Riverside café (2)'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('You'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('admins close a poll after confirming', (tester) async {
      final container = await openCircle(tester);
      await go(tester, container, '/home/memory/reunion-poll');
      await tapText(tester, 'Close poll');
      expect(find.text('Close this poll?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Close poll'));
      await tester.pumpAndSettle();
      final poll = memoryOf(container, 'reunion-poll').poll!;
      expect(poll.closed, isTrue);
      expect(find.text('Poll · Closed'), findsOneWidget);
      expect(find.text('3 votes · Closed'), findsOneWidget);
      expect(find.text('Close poll'), findsNothing);
      expect(find.text('Change vote'), findsNothing);
      // Closed: results show to everyone, including people who didn't vote.
      expect(find.text('67% · 2'), findsOneWidget);
    });

    testWidgets('closed anonymous poll shows counts but no names', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/home/memory/route-poll');
      expect(find.text('Anonymous votes'), findsOneWidget);
      expect(find.text('67% · 2'), findsOneWidget);
      expect(find.text('33% · 1'), findsOneWidget);
      expect(find.text('See who voted'), findsNothing);
      expect(find.text('Close poll'), findsNothing);
    });
  });

  group('reactions', () {
    testWidgets('picker sets one reaction; tapping it removes it', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/home/memory/table');
      await tapTooltip(tester, 'Choose a reaction for $_table');
      expect(find.text('React to this Memory'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '😂'));
      await tester.pumpAndSettle();
      expect(memoryOf(container, 'table').reactions.mine, '😂');
      expect(find.widgetWithText(TextButton, '😂'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp('Reacted with Laugh. Remove reaction')),
        findsOneWidget,
      );
      semantics.dispose();
      await tester.tap(find.widgetWithText(TextButton, '😂'));
      await tester.pumpAndSettle();
      expect(memoryOf(container, 'table').reactions.mine, isNull);
      expect(find.byTooltip('Love $_table'), findsOneWidget);

      // Long-press on Love opens the same picker.
      await reveal(tester, find.byTooltip('Love $_table'));
      await tester.longPress(find.byTooltip('Love $_table'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '❤️'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove love from $_table'), findsOneWidget);

      await tapTooltip(tester, 'Show reactions for $_table');
      expect(find.text('Reactions (17)'), findsOneWidget);
      expect(find.text('Includes you'), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
    });
  });

  group('comments', () {
    testWidgets('reply to a comment; replies indent; delete with undo', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/home/memory/table');
      expect(find.text('Comments (2)'), findsOneWidget);
      // Only top-level comments offer Reply.
      expect(find.text('Reply'), findsOneWidget);
      await tapText(tester, 'Reply');
      expect(find.text('Replying to Dev'), findsOneWidget);
      await tapText(tester, 'Cancel');
      expect(find.text('Replying to Dev'), findsNothing);
      await tapText(tester, 'Reply');
      await enterField(tester, 'Write a reply', 'Count me in.');
      await tapText(tester, 'Send reply');
      final reply = memoryOf(
        container,
        'table',
      ).comments.firstWhere((c) => c.text == 'Count me in.');
      expect(reply.parentId, 'table-comment-1');
      expect(find.text('Replying to Dev'), findsNothing);
      final parentX = tester.getTopLeft(find.byType(CommentBubble).first).dx;
      final replyX = tester.getTopLeft(find.byType(CommentBubble).last).dx;
      expect(replyX, greaterThan(parentX));

      // Own comments can be deleted; others' cannot.
      expect(find.text('Delete'), findsOneWidget);
      await tapText(tester, 'Delete');
      expect(find.text('Comment deleted.'), findsOneWidget);
      expect(
        memoryOf(container, 'table').comments.any((c) => c.id == reply.id),
        isFalse,
      );
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        memoryOf(container, 'table').comments.any((c) => c.id == reply.id),
        isTrue,
      );
    });

    testWidgets('card preview shows the latest comment with its author', (
      tester,
    ) async {
      await openCircle(tester);
      final preview = find.byType(CommentBubble).first;
      final text = tester.widget<Text>(
        find.descendant(of: preview, matching: find.byType(Text)),
      );
      expect(text.textSpan!.toPlainText(), 'Mira: Holding you to that.');
    });
  });

  group('photos', () {
    testWidgets('viewer swipes, steps with buttons and shows captions', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/home/memory/table');
      await tester.tap(find.byType(CircleSceneTile).first);
      await tester.pumpAndSettle();
      expect(find.byType(MemoryPhotoViewer), findsOneWidget);
      expect(find.text('1 of 4'), findsOneWidget);
      expect(find.text('Room for one more'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 of 4'), findsOneWidget);
      expect(find.text('Priya’s cake, slightly lopsided'), findsOneWidget);
      await tester.tap(find.byTooltip('Next photo'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 4'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous photo'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 4'), findsOneWidget);
    });

    testWidgets('"+N more" opens the viewer at that photo', (tester) async {
      final container = await openCircle(tester);
      await go(tester, container, '/home/memory/table');
      expect(find.text('+1 more'), findsOneWidget);
      await tester.tap(find.text('+1 more'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 4'), findsOneWidget);
      await go(tester, container, '/home/memory/table/photos?index=99');
      expect(find.text('4 of 4'), findsOneWidget);
      final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(next.onPressed, isNull);
      await go(tester, container, '/home/memory/private-memory/photos');
      expect(find.text('Photos unavailable'), findsOneWidget);
    });
  });

  group('own Memories', () {
    testWidgets('author edits and deletes with undo; others only save', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await container
          .read(circleWorkspaceProvider.notifier)
          .createMemory('family', 'My own words.');
      await tester.pumpAndSettle();
      const mine = 'Memory from You in The Sunday table';

      await tapTooltip(tester, 'More options for $_table');
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Edit text'), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(memoryOf(container, 'table').saved, isTrue);

      await tapTooltip(tester, 'More options for $mine');
      await tester.tap(find.text('Edit text'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Your Memory'),
        'My better words.',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('My better words.'), findsOneWidget);
      expect(find.textContaining('Just now · Edited'), findsOneWidget);

      await tapTooltip(tester, 'More options for $mine');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Memory deleted.'), findsOneWidget);
      expect(find.text('My better words.'), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('My better words.'), findsOneWidget);
    });

    testWidgets('deleting from the detail page returns home', (tester) async {
      final container = await openCircle(tester);
      final id = await container
          .read(circleWorkspaceProvider.notifier)
          .createMemory('club', 'Short-lived.');
      await go(tester, container, '/home');
      await go(tester, container, '/home/memory/$id');
      await tapTooltip(
        tester,
        'More options for Memory from You in Sunday miles',
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(currentUri(container).path, '/home');
      expect(workspaceOf(container).memories.any((m) => m.id == id), isFalse);
    });
  });

  testWidgets('saved poll-only Memories have a readable title on You', (
    tester,
  ) async {
    final container = await openCircle(tester);
    await container.read(circleWorkspaceProvider.notifier).save('route-poll');
    await go(tester, container, '/you');
    await reveal(
      tester,
      find.text('Poll: Which route for the season’s last ride?'),
    );
    expect(
      find.text('Poll: Which route for the season’s last ride?'),
      findsOneWidget,
    );
  });

  for (final route in ['/home/memory/table', '/home/memory/reunion-poll']) {
    testWidgets('$route has accessible labels and touch targets', (
      tester,
    ) async {
      final container = await openCircle(tester);
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
    testWidgets('Memories layouts hold at 200% text, dark, $size', (
      tester,
    ) async {
      final container = await openCircle(
        tester,
        size: size,
        scale: 2,
        brightness: Brightness.dark,
      );
      for (final route in [
        '/home',
        '/compose',
        '/home/memory/table',
        '/home/memory/reunion-poll',
        '/home/memory/route-poll',
        '/home/memory/old-days',
        '/home/memory/table/photos?index=1',
        '/home/memory/ride/photos',
      ]) {
        await go(tester, container, route);
        expect(tester.takeException(), isNull, reason: route);
      }
      // Compose with every section open.
      await go(tester, container, '/compose?group=family');
      await tapText(tester, 'Add photos');
      expect(tester.takeException(), isNull, reason: 'photo sheet');
      await tapText(tester, 'Beach walk');
      await tapText(tester, 'Use 1 photo');
      await tapText(tester, 'Add a poll');
      await tapText(tester, 'More poll options');
      await tapText(tester, 'More options');
      expect(tester.takeException(), isNull, reason: 'full compose');
      // Sheets on the detail page.
      await go(tester, container, '/home/memory/table');
      await tapTooltip(tester, 'Choose a reaction for $_table');
      expect(tester.takeException(), isNull, reason: 'reaction picker');
      await tester.tap(find.widgetWithText(ChoiceChip, '🎉'));
      await tester.pumpAndSettle();
      await go(tester, container, '/home/memory/reunion-poll');
      await tapText(tester, 'Riverside café');
      await tapText(tester, 'See who voted');
      expect(tester.takeException(), isNull, reason: 'voters sheet');
    });
  }
}
