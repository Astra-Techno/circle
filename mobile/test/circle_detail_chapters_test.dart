import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/circle_harness.dart';
import 'support/mock_circle_repository.dart';

/// Server-paginated double: pages come from queryMemories, so the Chapter
/// year filter must happen in the provider after each fetch.
class _ChapterPages extends MockCircleRepository implements MemoryQueryReader {
  _ChapterPages({super.now}) : super(showcase: true);

  @override
  Future<MemoryPage> queryMemories(
    String viewer,
    MemoryQuery query, {
    String? cursor,
  }) async {
    if (cursor != null) return MemoryPage(items: const []);
    return MemoryPage(
      items: [
        for (final memory in (await load(viewer)).memories)
          if (query.groupId == null || memory.groupId == query.groupId) memory,
      ],
      hasMore: false,
    );
  }
}

void main() {
  testWidgets('Inner circles row lists member sub-circles and opens them', (
    tester,
  ) async {
    final c = await openCircle(tester);
    await go(tester, c, '/groups/g/college');
    await reveal(tester, find.text('Inner circles'));
    final tile = find.text('Computer science');
    await reveal(tester, tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(currentUri(c).path, '/groups/g/cse');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the New tile opens the create InCircle sheet', (tester) async {
    final c = await openCircle(tester);
    await go(tester, c, '/groups/g/college');
    final tile = find.text('New');
    await reveal(tester, tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('New InCircle in Northbank 2009'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chapters filter the timeline by year and All restores it', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 6, 15, 12);
    DateTime clock() => now;
    final repository = MockCircleRepository(showcase: true, now: clock);
    final c = await openCircle(tester, repository: repository, clock: clock);
    final controller = c.read(circleWorkspaceProvider.notifier);
    await controller.createMemory('college', 'Fictional reunion this year');
    now = DateTime.utc(2013, 5, 20, 12);
    await controller.createMemory('college', 'Fictional throwback day');
    await tester.pumpAndSettle();

    await go(tester, c, '/groups/g/college');
    await reveal(tester, find.text('Chapters'));
    expect(find.text('2013'), findsOneWidget);
    expect(find.text('2026'), findsWidgets);
    expect(find.text('Fictional reunion this year'), findsWidgets);
    expect(find.text('Fictional throwback day'), findsWidgets);

    await tester.tap(find.text('2013'));
    await tester.pumpAndSettle();
    expect(find.text('Fictional throwback day'), findsWidgets);
    expect(find.text('Fictional reunion this year'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Fictional reunion this year'), findsWidgets);
    expect(find.text('Fictional throwback day'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('a Chapter filters server pages after each fetch', () async {
    var now = DateTime.utc(2026, 6, 15, 12);
    DateTime clock() => now;
    final repository = _ChapterPages(now: clock);
    await repository.createMemory('you', 'college', 'Now memory');
    now = DateTime.utc(2013, 5, 20, 12);
    await repository.createMemory('you', 'college', 'Old memory');
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        circleRepositoryProvider.overrideWithValue(repository),
        circleViewerProvider.overrideWithValue('you'),
      ],
    );
    addTearDown(container.dispose);

    final chapter = await container.read(
      memoryTimelineProvider(
        const MemoryQuery(groupId: 'college', year: 2013),
      ).future,
    );
    expect(chapter.items.map((memory) => memory.text), ['Old memory']);
    expect(chapter.hasMore, isFalse);

    final all = await container.read(
      memoryTimelineProvider(const MemoryQuery(groupId: 'college')).future,
    );
    // The seeded reunion Memory stays alongside the two created here.
    expect(
      all.items.map((memory) => memory.text),
      containsAll(<String>['Now memory', 'Old memory']),
    );
  });
}
