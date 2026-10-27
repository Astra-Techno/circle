import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_providers.dart';
import 'package:mobile/features/workspace/application/server_session.dart';
import 'package:mobile/features/notifications/application/push_settings.dart';
import 'package:mobile/features/notifications/application/push_session_coordinator.dart';
import 'support/fake_api.dart';
import 'push_settings_ui_test.dart' show TrackingCoordinator;

void main() {
  test(
    'real controller serializes partial writes and restores failed choices without permission',
    () async {
      final config = ApiConfig.parse('https://fictional.example/api/v1')!;
      var fail = false;
      final saved = <String, Object?>{
        'enabled': false,
        'categories': {
          for (final c in PushCategory.values)
            c == PushCategory.repliesReactions ? 'replies_reactions' : c.name:
                false,
        },
        'quiet_hours': true,
        'quiet_start': 1320,
        'quiet_end': 420,
        'timezone': 'UTC',
      };
      final api = ApiClient(
        config: config,
        tokens: MemoryTokenStore(
          TokenPair(
            accessToken: 'fictional-access',
            refreshToken: 'fictional-refresh',
            server: config.baseUrl.toString(),
            account: const StoredAccount(
              id: '7',
              displayName: 'Fictional Person',
            ),
          ),
        ),
        adapter: FakeHttpAdapter((r) async {
          if (r.method == 'PATCH') {
            if (fail) return FakeResponse.error(503, 'unavailable');
            final changes = r.json;
            if (changes['categories'] is Map) {
              saved['categories'] = {
                ...saved['categories'] as Map,
                ...changes['categories'] as Map,
              };
            }
            saved.addAll({...changes}..remove('categories'));
          }
          return FakeResponse.ok(saved);
        }),
      );
      final coordinator = TrackingCoordinator();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          serverAccountProvider.overrideWithValue(
            const ApiAccount(id: '7', displayName: 'Fictional Person'),
          ),
          pushSessionCoordinatorProvider.overrideWithValue(coordinator),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(pushSettingsProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(pushSettingsProvider.future);
      final controller = container.read(pushSettingsProvider.notifier);
      await Future.wait([
        controller.change(categories: {PushCategory.memories: true}),
        controller.change(timezone: 'Asia/Kolkata'),
      ]);
      final choices = container.read(pushSettingsProvider).requireValue;
      expect(choices.categories[PushCategory.memories], isTrue);
      expect(choices.timezone, 'Asia/Kolkata');
      expect(choices.enabled, isFalse);
      expect(coordinator.starts, 0);
      fail = true;
      await expectLater(
        controller.change(timezone: 'Europe/London'),
        throwsA(isA<ApiError>()),
      );
      expect(
        container.read(pushSettingsProvider).requireValue.timezone,
        'Asia/Kolkata',
      );
      expect(container.read(pushSettingsProvider).isLoading, isFalse);
    },
  );
}
