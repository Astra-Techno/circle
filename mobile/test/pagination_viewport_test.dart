import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/memories/presentation/scoped_memory_list.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/mock_circle_repository.dart';

class PagedRepository extends MockCircleRepository
    implements MemoryQueryReader {
  PagedRepository() : super(showcase: true);
  final cursors = <String?>[];
  bool fail = false;
  @override
  Future<MemoryPage> queryMemories(
    String viewer,
    MemoryQuery query, {
    String? cursor,
  }) async {
    cursors.add(cursor);
    if (fail && cursor != null) throw Exception('offline');
    final memories = (await load(viewer)).memories;
    final count = cursor == null ? 1 : int.parse(cursor) + 1;
    return MemoryPage(
      items: memories.take(count).toList(),
      cursor: '$count',
      hasMore: count < 3,
    );
  }
}

class SwitchingQueryRepository extends MockCircleRepository
    implements MemoryQueryReader {
  SwitchingQueryRepository() : super(showcase: true);
  final oldPage = Completer<MemoryPage>();
  final calls = <String>[];
  @override
  Future<MemoryPage> queryMemories(
    String viewer,
    MemoryQuery query, {
    String? cursor,
  }) async {
    calls.add('${query.text}:${cursor == null ? 'first' : 'more'}');
    if (cursor != null && query.text == 'old') return oldPage.future;
    final memories = (await load(viewer)).memories;
    return cursor == null
        ? MemoryPage(
            items: memories.take(1).toList(),
            cursor: 'same-cursor',
            hasMore: true,
          )
        : MemoryPage(items: memories.take(2).toList());
  }
}

void main() {
  testWidgets(
    'new query resets a same-cursor sentinel and ignores old pagination failure',
    (tester) async {
      final repo = SwitchingQueryRepository();
      final query = ValueNotifier(const MemoryQuery(text: 'old'));
      addTearDown(query.dispose);
      addTearDown(() {
        if (!repo.oldPage.isCompleted) {
          repo.oldPage.complete(MemoryPage(items: []));
        }
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            circleRepositoryProvider.overrideWithValue(repo),
            circleViewerProvider.overrideWithValue('you'),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ValueListenableBuilder<MemoryQuery>(
                  valueListenable: query,
                  builder: (_, value, _) => ScopedMemoryList(
                    query: value,
                    empty: const Text('Empty'),
                    itemBuilder: (_, memory) =>
                        SizedBox(height: 80, child: Text(memory.id)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(repo.calls, contains('old:more'));
      query.value = const MemoryQuery(text: 'new');
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(repo.calls, contains('new:more'));
      expect(find.text("You've seen all Memories"), findsOneWidget);
      repo.oldPage.completeError(Exception('old request failed'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Retry loading older Memories'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'pagination waits for viewport, retries errors and continues across cursors',
    (tester) async {
      final repo = PagedRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            circleRepositoryProvider.overrideWithValue(repo),
            circleViewerProvider.overrideWithValue('you'),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ScopedMemoryList(
                  query: const MemoryQuery(saved: true),
                  empty: const Text('Empty'),
                  itemBuilder: (_, memory) =>
                      SizedBox(height: 900, child: Text(memory.id)),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(repo.cursors, [null]);
      repo.fail = true;
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1000),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('Retry loading older Memories'), findsOneWidget);
      repo.fail = false;
      await tester.ensureVisible(find.text('Retry loading older Memories'));
      await tester.tap(find.text('Retry loading older Memories'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(repo.cursors, [null, '1', '1']);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1400),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(repo.cursors, [null, '1', '1', '2']);
      expect(find.text("You've seen all Memories"), findsOneWidget);
    },
  );
}
