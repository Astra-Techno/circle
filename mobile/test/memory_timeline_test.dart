import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'package:mobile/features/workspace/data/mock_circle_repository.dart';

class PendingPageRepository extends MockCircleRepository
    implements MemoryQueryReader {
  final older = Completer<MemoryPage>();
  int requests = 0;
  @override
  Future<MemoryPage> queryMemories(
    String viewer,
    MemoryQuery query, {
    String? cursor,
  }) async {
    if (cursor != null) return older.future;
    requests++;
    return MemoryPage(items: [], cursor: 'generation-$requests', hasMore: true);
  }
}

void main() {
  test(
    'a refreshed timeline rejects an older in-flight pagination result',
    () async {
      final repository = PendingPageRepository();
      final container = ProviderContainer(
        overrides: [circleRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final provider = memoryTimelineProvider(const MemoryQuery(saved: true));
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(provider.future);
      final notifier = container.read(provider.notifier);
      final pending = notifier.loadMore();
      await notifier.refresh();
      expect(container.read(provider).requireValue.cursor, 'generation-2');
      repository.older.complete(MemoryPage(items: [], cursor: 'stale'));
      await pending;
      expect(container.read(provider).requireValue.cursor, 'generation-2');
    },
  );
}
