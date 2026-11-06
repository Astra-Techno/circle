import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/workspace/application/workspace_providers.dart';
import 'support/mock_circle_repository.dart';

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

class FailedPageRepository extends MockCircleRepository
    implements MemoryQueryReader {
  int requests = 0;
  @override
  Future<MemoryPage> queryMemories(
    String viewer,
    MemoryQuery query, {
    String? cursor,
  }) async {
    requests++;
    throw const CircleFailure('The server is busy. Try again later.');
  }
}

class FailedWorkspaceRepository extends MockCircleRepository {
  int requests = 0;
  @override
  Future<CircleWorkspace> load(String viewer) async {
    requests++;
    throw const CircleFailure('The server is busy. Try again later.');
  }
}

void main() {
  test('failed timeline stays in error until an explicit retry', () async {
    final repository = FailedPageRepository();
    final c = ProviderContainer(
      overrides: [circleRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(c.dispose);
    final provider = memoryTimelineProvider(const MemoryQuery(saved: true));
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await expectLater(c.read(provider.future), throwsA(isA<CircleFailure>()));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(c.read(provider).hasError, isTrue);
    expect(repository.requests, 1);
    c.invalidate(provider);
    await expectLater(c.read(provider.future), throwsA(isA<CircleFailure>()));
    expect(repository.requests, 2);
  });

  test(
    'failed workspace does not enter automatic retry loading loops',
    () async {
      final repository = FailedWorkspaceRepository();
      final c = ProviderContainer(
        overrides: [circleRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(c.dispose);
      final sub = c.listen(circleWorkspaceProvider, (_, _) {});
      addTearDown(sub.close);
      await expectLater(
        c.read(circleWorkspaceProvider.future),
        throwsA(isA<CircleFailure>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(c.read(circleWorkspaceProvider).hasError, isTrue);
      expect(repository.requests, 1);
    },
  );

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
