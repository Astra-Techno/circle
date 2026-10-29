import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/events/application/live_events.dart'
    show liveEventZones;
import 'package:mobile/core/api/api_providers.dart';
import 'package:mobile/features/workspace/application/server_session.dart';
import 'package:mobile/features/notifications/application/push_settings.dart';
import 'package:mobile/features/notifications/application/push_session_coordinator.dart';
import 'support/fake_api.dart';
import 'push_settings_ui_test.dart' show TrackingCoordinator;

class AcceptingCoordinator extends TrackingCoordinator {
  @override
  Future<bool> start({bool requestPermission = false}) async {
    starts++;
    return true;
  }
}

void main() {
  PushPreferences quiet(String zone) => PushPreferences(
    enabled: true,
    categories: {PushCategory.memories: true},
    quietHours: true,
    quietStart: 1320,
    quietEnd: 420,
    timezone: zone,
  );
  test(
    'UTC default quiet hours allow daytime and preserve overnight suppression',
    () {
      expect(
        pushQuietNow(quiet('UTC'), DateTime.utc(2026, 10, 29, 12)),
        isFalse,
      );
      expect(
        pushQuietNow(quiet('UTC'), DateTime.utc(2026, 10, 29, 23)),
        isTrue,
      );
      expect(
        pushQuietNow(quiet('GMT'), DateTime.utc(2026, 10, 29, 12)),
        isFalse,
      );
    },
  );
  test('Android legacy India time zone matches its canonical quiet hours', () {
    for (final hour in [2, 10, 20]) {
      final now = DateTime.utc(2026, 10, 29, hour);
      expect(
        pushQuietNow(quiet('Asia/Calcutta'), now),
        pushQuietNow(quiet('Asia/Kolkata'), now),
      );
    }
    expect(
      pushQuietNow(quiet('Asia/Calcutta'), DateTime.utc(2026, 10, 29, 2)),
      isFalse,
    );
    expect(
      pushQuietNow(quiet('Asia/Calcutta'), DateTime.utc(2026, 10, 29, 20)),
      isTrue,
    );
  });
  test(
    'device time zone picker accepts UTC and backward-compatible aliases',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(pushTimezonesProvider),
        containsAll(['UTC', 'GMT', 'Asia/Calcutta', 'Asia/Kolkata']),
      );
    },
  );

  test('opening Events cannot remove notification time zone aliases', () {
    final now = DateTime.utc(2026, 10, 29, 12);
    expect(pushQuietNow(quiet('UTC'), now), isFalse);
    expect(liveEventZones(), contains('UTC'));
    expect(pushQuietNow(quiet('UTC'), now), isFalse);
    expect(pushQuietNow(quiet('Asia/Calcutta'), now), isFalse);
  });
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
      final coordinator = AcceptingCoordinator();
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
      fail = false;
      await controller.change(
        categories: {PushCategory.memories: false, PushCategory.groups: true},
      );
      await controller.change(enabled: true, requestPermission: true);
      expect(coordinator.starts, 1);
      expect(container.read(pushSettingsProvider).requireValue.enabled, isTrue);
      expect(
        container
            .read(pushSettingsProvider)
            .requireValue
            .categories[PushCategory.groups],
        isTrue,
      );
    },
  );
}
