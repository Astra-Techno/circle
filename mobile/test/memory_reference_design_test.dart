import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/design.dart';
import 'package:mobile/features/memories/presentation/memory_card.dart';
import 'package:mobile/features/memories/presentation/memory_photos.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/circle_harness.dart';
import 'screen_audit_visual_review_test.dart' show capture;

const about = 'Memory from Mira in The Sunday table';

Future<void> tapTooltip(WidgetTester tester, String label) async {
  final finder = find.byTooltip(label);
  await reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('known photo proportions are preserved within timeline bounds', () {
    expect(CircleMemoryLayout.photoAspect(1200, 1200), 1);
    expect(CircleMemoryLayout.photoAspect(1600, 1200), closeTo(4 / 3, 0.001));
    expect(CircleMemoryLayout.photoAspect(100, 1000), 4 / 5);
    expect(CircleMemoryLayout.photoAspect(4000, 100), 1.91);
    expect(CircleMemoryLayout.photoAspect(null, null), 1);
  });

  testWidgets(
    'Home, detail and another profile have matching inset rounded post media',
    (tester) async {
      final c = await openCircle(tester);
      for (final route in ['/home', '/home/memory/table', '/people/mira']) {
        await go(tester, c, route);
        final photo = find.byType(MemoryPhotoGrid).first;
        await reveal(tester, photo);
        final rect = tester.getRect(photo);
        expect(
          rect.left,
          closeTo(CircleMemoryLayout.mediaInset, 0.01),
          reason: route,
        );
        expect(
          rect.width,
          closeTo(393 - 2 * CircleMemoryLayout.mediaInset, 0.01),
          reason: route,
        );
        expect(
          rect.height,
          closeTo(
            (393 - 2 * CircleMemoryLayout.mediaInset) /
                CircleMemoryLayout.collageAspect,
            0.01,
          ),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('tablet timeline stays one centered reading column', (
    tester,
  ) async {
    await openCircle(tester, size: const Size(900, 1100));
    final rect = tester.getRect(find.byType(CircleMemoryCard).first);
    expect(rect.left, closeTo(90, 0.01));
    expect(rect.width, closeTo(720, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long captions expand in place and detail starts fully readable',
    (tester) async {
      final c = await openCircle(tester, scale: 2, size: const Size(320, 1000));
      final text = List.filled(
        12,
        'A fictional moment worth remembering.',
      ).join(' ');
      final id = await c
          .read(circleWorkspaceProvider.notifier)
          .createMemory('family', text);
      await tester.pumpAndSettle();
      final surface = find.byKey(ValueKey('memory-surface-$id'));
      final caption = find.descendant(of: surface, matching: find.text(text));
      await reveal(tester, caption);
      expect(tester.widget<Text>(caption).maxLines, 3);
      final more = find.descendant(
        of: surface,
        matching: find.text('See more'),
      );
      await reveal(tester, more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(caption).maxLines, isNull);
      expect(more, findsNothing);
      await go(tester, c, '/home/memory/$id');
      expect(tester.widget<Text>(find.text(text)).maxLines, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final layout in [
    (393.0, 852.0, 1.0, Brightness.light),
    (393.0, 852.0, 1.0, Brightness.dark),
    (320.0, 1000.0, 2.0, Brightness.dark),
    (900.0, 1100.0, 2.0, Brightness.light),
  ]) {
    testWidgets(
      'single-photo reference layout ${layout.$1} ${layout.$3} ${layout.$4.name}',
      (tester) async {
        final c = await openCircle(
          tester,
          size: Size(layout.$1, layout.$2),
          scale: layout.$3,
          brightness: layout.$4,
        );
        final id = await c
            .read(circleWorkspaceProvider.notifier)
            .createMemory(
              'family',
              'A day together, a Memory to keep.',
              photos: [MemoryScene.hillTrip],
            );
        await tester.pumpAndSettle();
        final surface = find.byKey(ValueKey('memory-surface-$id'));
        final grid = find.descendant(
          of: surface,
          matching: find.byType(MemoryPhotoGrid),
        );
        final rect = tester.getRect(grid);
        expect(
          rect.width,
          closeTo(
            (layout.$1 > 720 ? 720 : layout.$1) -
                2 * CircleMemoryLayout.mediaInset,
            0.01,
          ),
        );
        expect(rect.height, closeTo(rect.width, 0.01));
        await capture(
          tester,
          'reference-single-photo',
          '${layout.$1.toInt()}-${layout.$3}-${layout.$4.name}',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final layout in [
    (393.0, 1.0, Brightness.light),
    (320.0, 2.0, Brightness.dark),
    (900.0, 2.0, Brightness.light),
  ]) {
    testWidgets('selected reaction aligns with footer icons ${layout.$1}', (
      tester,
    ) async {
      await openCircle(
        tester,
        size: Size(layout.$1, 1000),
        scale: layout.$2,
        brightness: layout.$3,
      );
      await tapTooltip(tester, 'Choose a reaction for $about');
      await tester.tap(find.widgetWithText(ChoiceChip, '❤️'));
      await tester.pumpAndSettle();
      final action = find.byTooltip('Choose a reaction for $about');
      // Love shows as the solid red heart tile, aligned with Comment.
      final heart = find.descendant(
        of: action,
        matching: find.byType(CircleActionIcon),
      );
      expect(tester.widget<CircleActionIcon>(heart).tinted, isFalse);
      final comment = find.descendant(
        of: find.byTooltip('Comment on $about'),
        matching: find.byType(CircleActionIcon),
      );
      expect(tester.widget<CircleActionIcon>(comment).tinted, isTrue);
      expect(
        tester.getCenter(heart).dy,
        closeTo(tester.getCenter(comment).dy, 0.01),
      );
      expect(tester.getSize(heart).height, CircleMemoryLayout.actionTile);
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(action).width, greaterThanOrEqualTo(48));
      await capture(
        tester,
        'aligned-footer',
        '${layout.$1.toInt()}-${layout.$2}',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reference heading preserves paragraphs and full detail text', (
    tester,
  ) async {
    final c = await openCircle(tester);
    const caption =
        'A question for our Circle\n\nWhich little moments made your week?\n\nShare the stories you want to remember.';
    final id = await c
        .read(circleWorkspaceProvider.notifier)
        .createMemory('family', caption);
    await go(tester, c, '/home/memory/$id');
    final text = tester.widget<Text>(find.text(caption));
    final span = text.textSpan! as TextSpan;
    expect(span.toPlainText(), caption);
    expect((span.children!.first as TextSpan).style!.fontSize, 18);
    expect(span.style!.fontSize, 16);
    expect(text.maxLines, isNull);
    await capture(tester, 'reference-text-detail', '393-1.0-light');
    expect(tester.takeException(), isNull);
  });

  testWidgets('icon actions persist real reactions and saved state', (
    tester,
  ) async {
    final c = await openCircle(tester);
    await tapTooltip(tester, 'Choose a reaction for $about');
    await tester.tap(find.widgetWithText(ChoiceChip, '😂'));
    await tester.pumpAndSettle();
    expect(
      workspaceOf(c).memories.firstWhere((m) => m.id == 'table').reactions.mine,
      '😂',
    );
    expect(find.text('😂'), findsWidgets);
    await tapTooltip(tester, 'Save $about');
    expect(
      workspaceOf(c).memories.firstWhere((m) => m.id == 'table').saved,
      isTrue,
    );
    expect(find.byIcon(CircleIcons.saved), findsWidgets);
    await tapTooltip(tester, 'Unsave $about');
    expect(
      workspaceOf(c).memories.firstWhere((m) => m.id == 'table').saved,
      isFalse,
    );
    await tapTooltip(tester, 'View 2 comments');
    expect(currentUri(c).path, '/home/memory/table');
    expect(find.text('Comments (2)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
