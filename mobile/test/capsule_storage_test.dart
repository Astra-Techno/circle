import 'dart:convert';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/capsules/application/capsule_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_config.dart';
import 'package:mobile/core/local_settings.dart';
import 'package:mobile/features/capsules/data/local_capsule_repository.dart';

class FailingCapsuleStore extends MemoryLocalSettingsStore {
  bool fail = false;
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('Storage unavailable');
    await super.write(key, value);
  }
}

final testCapsuleViewer = NotifierProvider<TestCapsuleViewer, String>(
  TestCapsuleViewer.new,
);

class TestCapsuleViewer extends Notifier<String> {
  @override
  String build() => 'fictional-a';
  void switchTo(String viewer) => state = viewer;
}

class DelayedCapsuleStore extends MemoryLocalSettingsStore {
  Completer<void>? pending;
  final started = Completer<void>();
  @override
  Future<void> write(String key, String value) async {
    if (pending != null) {
      if (!started.isCompleted) started.complete();
      await pending!.future;
    }
    await super.write(key, value);
  }
}

void main() {
  test(
    'account switch clears state and rejects a stale save completion',
    () async {
      final storage = DelayedCapsuleStore();
      final container = ProviderContainer(
        overrides: [
          capsuleRepositoryProvider.overrideWith(
            (ref) => LocalCapsuleRepository(
              viewer: ref.watch(testCapsuleViewer),
              storage: storage,
              server: 'https://fictional.test/api/v1',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(capsulesProvider, (_, _) {});
      addTearDown(subscription.close);
      expect(await container.read(capsulesProvider.future), isEmpty);
      storage.pending = Completer<void>();
      final oldSave = container
          .read(capsulesProvider.notifier)
          .create(
            groupId: 'fictional-circle',
            title: 'Private A',
            message: '',
            unlockAt: DateTime.now().add(const Duration(days: 2)),
          );
      await storage.started.future;
      container.read(testCapsuleViewer.notifier).switchTo('fictional-b');
      expect(await container.read(capsulesProvider.future), isEmpty);
      storage.pending!.complete();
      await oldSave;
      expect(container.read(capsulesProvider).requireValue, isEmpty);
      expect(
        (await LocalCapsuleRepository(
          viewer: 'fictional-a',
          storage: storage,
          server: 'https://fictional.test/api/v1',
        ).list()).single.title,
        'Private A',
      );
    },
  );

  test(
    'contributions survive restart, sealing and concurrent writes',
    () async {
      final store = MemoryLocalSettingsStore();
      final repository = LocalCapsuleRepository(
        viewer: 'fictional-a',
        storage: store,
      );
      final capsule = await repository.create(
        groupId: 'fictional-circle',
        title: 'Later',
        message: 'Opening note',
        unlockAt: DateTime.now().add(const Duration(days: 2)),
      );
      await Future.wait([
        repository.addEntry(capsule.id, 'First message'),
        repository.addEntry(capsule.id, 'Second message'),
      ]);
      await repository.seal(capsule.id);
      final restarted = LocalCapsuleRepository(
        viewer: 'fictional-a',
        storage: store,
      );
      final restored = (await restarted.list()).single;
      expect(restored.entries.map((e) => e.text), [
        'First message',
        'Second message',
      ]);
      expect(restored.messageCount, 2);
      expect(restored.contributors.single.addedMessages, 2);
      expect(restored.isSealed, isTrue);
      await expectLater(
        restarted.addEntry(capsule.id, 'Too late'),
        throwsStateError,
      );
      expect(
        await LocalCapsuleRepository(
          viewer: 'fictional-b',
          storage: store,
        ).list(),
        isEmpty,
      );
      expect(
        await LocalCapsuleRepository(
          viewer: 'fictional-a',
          storage: store,
          server: 'https://fictional.test/api/v1',
        ).list(),
        isEmpty,
      );
    },
  );

  test('failed write is reported and does not survive in cache', () async {
    final store = FailingCapsuleStore();
    final repository = LocalCapsuleRepository(
      viewer: 'fictional-a',
      storage: store,
    );
    final capsule = await repository.create(
      groupId: 'fictional-circle',
      title: 'Later',
      message: '',
      unlockAt: DateTime.now().add(const Duration(days: 2)),
    );
    store.fail = true;
    await expectLater(
      repository.addEntry(capsule.id, 'Unsaved'),
      throwsStateError,
    );
    expect((await repository.list()).single.entries, isEmpty);
    store.fail = false;
    await repository.addEntry(capsule.id, 'Saved');
    expect((await repository.list()).single.entries.single.text, 'Saved');
  });

  test(
    'legacy records are adopted only by the original server and retained',
    () async {
      final store = MemoryLocalSettingsStore();
      await store.write(
        'circle.capsules.v1.fictional-a',
        jsonEncode([
          {
            'id': 'old',
            'groupId': 'fictional-circle',
            'creatorId': 'fictional-a',
            'creator': 'Fictional A',
            'title': 'Legacy',
            'message': '',
            'unlockAt': '2030-01-01T00:00:00Z',
            'createdAt': '2026-01-01T00:00:00Z',
            'messageCount': 3,
          },
        ]),
      );
      expect(
        await LocalCapsuleRepository(
          viewer: 'fictional-a',
          storage: store,
          server: 'https://fictional.test/api/v1',
        ).list(),
        isEmpty,
      );
      final restored = await LocalCapsuleRepository(
        viewer: 'fictional-a',
        storage: store,
        server: ApiConfig.deployedApi,
      ).list();
      expect(restored.single.id, 'old');
      expect(restored.single.messageCount, 3);
      expect(await store.read('circle.capsules.v1.fictional-a'), isNotNull);
    },
  );

  test('corrupt storage cannot be overwritten with an empty list', () async {
    final store = MemoryLocalSettingsStore();
    final key =
        '${const DraftScope(server: ApiConfig.deployedApi, account: 'fictional-a').key}.capsules';
    await store.write(key, '{broken');
    final repository = LocalCapsuleRepository(
      viewer: 'fictional-a',
      storage: store,
    );
    await expectLater(repository.list(), throwsFormatException);
    expect(await store.read(key), '{broken');
  });
}
