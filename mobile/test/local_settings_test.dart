import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/local_settings.dart';
import 'package:mobile/core/theme_controller.dart';

void main() {
  test('appearance survives a new provider container', () async {
    final storage = MemoryLocalSettingsStore();
    ProviderContainer open() => ProviderContainer(
      overrides: [localSettingsStoreProvider.overrideWithValue(storage)],
    );
    final first = open();
    first.read(themeProvider.notifier).change(ThemeMode.dark);
    await first.read(themeProvider.notifier).saved;
    first.dispose();
    final second = open();
    expect(second.read(themeProvider), ThemeMode.light);
    await Future<void>.delayed(Duration.zero);
    expect(second.read(themeProvider), ThemeMode.dark);
    second.dispose();
  });
  test(
    'drafts survive restart and stay isolated by server account and group',
    () async {
      final storage = MemoryLocalSettingsStore();
      const scope = DraftScope(
        server: 'https://example.test/api',
        account: 'fictional-a',
      );
      final store = MemoryDraftStore(storage);
      final lease = store.open(scope);
      await store.save(
        lease,
        const MemoryTextDraft(text: 'First', groupId: 'group-a'),
      );
      await store.save(
        lease,
        const MemoryTextDraft(text: 'Second', groupId: 'group-b'),
      );
      final restarted = MemoryDraftStore(storage);
      final restored = restarted.open(scope);
      expect(
        (await restarted.read(restored, groupId: 'group-a'))?.text,
        'First',
      );
      expect((await restarted.read(restored))?.groupId, 'group-b');
      expect(
        await restarted.read(
          restarted.open(
            const DraftScope(
              server: 'https://other.test/api',
              account: 'fictional-a',
            ),
          ),
        ),
        isNull,
      );
      expect(
        await restarted.read(
          restarted.open(
            const DraftScope(
              server: 'https://example.test/api',
              account: 'fictional-b',
            ),
          ),
        ),
        isNull,
      );
    },
  );
  test(
    'logout invalidates delayed saves and removes only its account drafts',
    () async {
      final storage = MemoryLocalSettingsStore();
      final store = MemoryDraftStore(storage);
      const scope = DraftScope(server: 'example', account: 'a');
      const other = DraftScope(server: 'example', account: 'b');
      final lease = store.open(scope), otherLease = store.open(other);
      await store.save(
        lease,
        const MemoryTextDraft(text: 'Private', groupId: 'g'),
      );
      await store.save(
        otherLease,
        const MemoryTextDraft(text: 'Other', groupId: 'g'),
      );
      await store.clearScope(scope);
      expect(
        await store.save(
          lease,
          const MemoryTextDraft(text: 'Stale', groupId: 'g'),
        ),
        isFalse,
      );
      expect(await store.read(store.open(scope)), isNull);
      expect((await store.read(otherLease))?.text, 'Other');
    },
  );
  test(
    'discard removes one group and corrupted entries cannot restore',
    () async {
      final storage = MemoryLocalSettingsStore();
      final store = MemoryDraftStore(storage);
      const scope = DraftScope(server: 'example', account: 'a');
      final lease = store.open(scope);
      await store.save(
        lease,
        const MemoryTextDraft(text: 'Draft', groupId: 'g'),
      );
      await store.remove(lease, 'g');
      expect(await store.read(lease, groupId: 'g'), isNull);
      storage.values[scope.key] = '{broken';
      expect(await store.read(lease), isNull);
      expect(MemoryTextDraft.decode({'text': 123}), isNull);
    },
  );
}
