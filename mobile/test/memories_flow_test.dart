import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
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
    testWidgets('Home shows Video tile but it is not tappable', (tester) async {
      await openCircle(tester);
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
      // Video tile is present but disabled (V1: not yet supported).
      final videoInk = find.ancestor(
        of: find.text('Video'),
        matching: find.byType(InkWell),
      );
      final inkWell = tester.widget<InkWell>(videoInk.first);
      expect(inkWell.onTap, isNull);
    });

    testWidgets('caption, year and place render on the new card', (
      tester,
    ) async {
      final container = await openCircle(tester);
      await go(tester, container, '/compose?group=family');
      // Photos first: no demo illustrations, only the phone's own photos.
      expect(find.text('Beach walk'), findsNothing);
      expect(find.text('Add a poll'), findsNothing);
      await enterField(
        tester,
        'Share a memory with your Circle...',
        'A day by the water.',
      );
      await tapText(tester, 'More options');
      await enterField(tester, 'Year taken (optional)', '2019');
      await enterField(tester, 'Place (optional)', 'Fictional lake');
      await tapText(tester, 'Done');
      await tester.tap(find.widgetWithText(FilledButton, 'Create Memory'));
      await tester.pumpAndSettle();
      expect(currentUri(container).path, '/home');
      final memory = workspaceOf(container).memories.first;
      expect(memory.text, 'A day by the water.');
      expect(memory.groupId, 'family');
      expect(memory.photos, isEmpty);
      expect(memory.poll, isNull);
    });

    testWidgets('empty and invalid input is caught calmly', (tester) async {
      final container = await openCircle(tester);
      await go(tester, container, '/compose?group=club');
      final before = workspaceOf(container).memories.length;
      await tester.tap(find.widgetWithText(FilledButton, 'Create Memory'));
      await tester.pumpAndSettle();
      expect(
        find.text('Write 1–2000 characters, or add a photo, before sharing.'),
        findsOneWidget,
      );
      await enterField(
        tester,
        'Share a memory with your Circle...',
        'Lakeside kiosk at noon.',
      );
      await tapText(tester, 'More options');
      await enterField(tester, 'Year taken (optional)', '1900');
      await tapText(tester, 'Done');
      await tester.tap(find.widgetWithText(FilledButton, 'Create Memory'));
      await tester.pumpAndSettle();
      await tapText(tester, 'More options');
      expect(
        find.text('Use a year from 1950 to ${DateTime.now().year}.'),
        findsOneWidget,
      );
      expect(workspaceOf(container).memories, hasLength(before));
      await enterField(tester, 'Year taken (optional)', '');
      await tapText(tester, 'Done');
      await tester.tap(find.widgetWithText(FilledButton, 'Create Memory'));
      await tester.pumpAndSettle();
      expect(workspaceOf(container).memories, hasLength(before + 1));
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
      // The emoji appears in the reaction summary row.
      expect(find.text('😂'), findsWidgets);

      // Remove by picking the same emoji again.
      await tapTooltip(tester, 'Choose a reaction for $_table');
      await tester.tap(find.widgetWithText(ChoiceChip, '😂'));
      await tester.pumpAndSettle();
      expect(memoryOf(container, 'table').reactions.mine, isNull);

      // Pick a different reaction via the picker.
      await tapTooltip(tester, 'Choose a reaction for $_table');
      await tester.tap(find.widgetWithText(ChoiceChip, '❤️'));
      await tester.pumpAndSettle();
      expect(memoryOf(container, 'table').reactions.mine, '❤️');

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
      await enterField(tester, 'Write a reply...', 'Count me in.');
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pumpAndSettle();
      final reply = memoryOf(
        container,
        'table',
      ).comments.firstWhere((c) => c.text == 'Count me in.');
      expect(reply.parentId, 'table-comment-1');
      expect(find.text('Replying to Dev'), findsNothing);
      final parentX = tester.getTopLeft(find.byType(CommentBubble).first).dx;
      final replyX = tester.getTopLeft(find.byType(CommentBubble).last).dx;
      expect(replyX, greaterThan(parentX));

      // Deleting comments isn't on the server yet, so it isn't offered.
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('comment count opens the Memory comments', (tester) async {
      final container = await openCircle(tester);
      await tapText(tester, '2 comments');
      expect(currentUri(container).path, '/home/memory/table');
      expect(find.text('Comments (2)'), findsOneWidget);
      expect(find.byType(CommentBubble), findsWidgets);
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
      expect(find.text('+1'), findsOneWidget);
      await tester.tap(find.text('+1'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 4'), findsOneWidget);
      await go(tester, container, '/home/memory/table/photos?index=99');
      expect(find.text('4 of 4'), findsOneWidget);
      final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, LucideIcons.chevron_right),
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
      await tapText(tester, 'More options');
      expect(tester.takeException(), isNull, reason: 'full compose');
      // Sheets on the detail page.
      await go(tester, container, '/home/memory/table');
      await tapTooltip(tester, 'Choose a reaction for $_table');
      expect(tester.takeException(), isNull, reason: 'reaction picker');
      await tester.tap(find.widgetWithText(ChoiceChip, '🎉'));
      await tester.pumpAndSettle();
    });
  }
}
