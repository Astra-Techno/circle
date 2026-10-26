import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/features/notifications/data/push_preferences_api.dart';
import 'support/fake_api.dart';

Map<String, Object?> policy() => {
  'enabled': false,
  'categories': {
    for (final category in PushCategory.values)
      category == PushCategory.repliesReactions
              ? 'replies_reactions'
              : category.name:
          false,
  },
  'quiet_hours': true,
  'quiet_start': 1320,
  'quiet_end': 420,
  'timezone': 'UTC',
};

void main() {
  final config = ApiConfig.parse('http://circle.test/api/v1')!;
  ApiClient client(FakeHandler handler) => ApiClient(
    config: config,
    tokens: MemoryTokenStore(
      TokenPair(
        accessToken: 'fictional-access',
        refreshToken: 'fictional-refresh',
        server: config.baseUrl.toString(),
      ),
    ),
    adapter: FakeHttpAdapter(handler),
  );

  test('reads complete opt-in defaults with authenticated API', () async {
    final api = PushPreferencesApi(
      client((request) async {
        expect(request.method, 'GET');
        expect(request.path, '/me/notification-preferences');
        expect(request.bearer, 'fictional-access');
        return FakeResponse.ok(policy());
      }),
    );
    final prefs = await api.load();
    expect(prefs.enabled, isFalse);
    expect(prefs.categories.values, everyElement(isFalse));
    expect(prefs.quietHours, isTrue);
    expect(prefs.quietStart, 1320);
    expect(prefs.quietEnd, 420);
    expect(prefs.timezone, 'UTC');
  });

  test('sends only changed fields including explicit false category', () async {
    final api = PushPreferencesApi(
      client((request) async {
        expect(request.method, 'PATCH');
        expect(request.json, {
          'enabled': false,
          'categories': {'replies_reactions': false, 'events': true},
          'timezone': 'Asia/Kolkata',
        });
        return FakeResponse.ok({
          ...policy(),
          'timezone': 'Asia/Kolkata',
          'categories': {...policy()['categories'] as Map, 'events': true},
        });
      }),
    );
    final saved = await api.update(
      enabled: false,
      categories: {
        PushCategory.repliesReactions: false,
        PushCategory.events: true,
      },
      timezone: 'Asia/Kolkata',
    );
    expect(saved.categories[PushCategory.events], isTrue);
    expect(saved.categories[PushCategory.chats], isFalse);
    expect(saved.timezone, 'Asia/Kolkata');
  });

  test(
    'rejects malformed response rather than implying settings work',
    () async {
      for (final malformed in [
        {...policy(), 'enabled': 'true'},
        {...policy(), 'categories': <String, bool>{}},
        {...policy(), 'quiet_start': 1440},
        {...policy(), 'quiet_end': 1320},
        {...policy(), 'timezone': null},
        {...policy(), 'quiet_hours': 1},
      ]) {
        final api = PushPreferencesApi(
          client((_) async => FakeResponse.ok(malformed)),
        );
        await expectLater(
          api.load(),
          throwsA(
            isA<ApiError>().having((e) => e.code, 'code', ApiError.badResponse),
          ),
        );
      }
    },
  );

  test('register/unregister preserve opaque token and platform', () async {
    final seen = <String>[];
    final api = PushPreferencesApi(
      client((request) async {
        seen.add(request.path);
        expect(request.bearer, 'fictional-access');
        expect(request.json['fcm_token'], 'Fictional:CaseSensitive_token-1');
        if (request.path.endsWith('/register')) {
          expect(request.json['platform'], 'ios');
        }
        if (request.path.endsWith('/unregister')) {
          expect(request.json.containsKey('platform'), isFalse);
        }
        return FakeResponse.ok({'registered': true});
      }),
    );
    await api.registerDevice(
      'Fictional:CaseSensitive_token-1',
      PushDevicePlatform.ios,
    );
    await api.unregisterDevice('Fictional:CaseSensitive_token-1');
    expect(seen, ['/devices/register', '/devices/unregister']);
  });

  test('server rejection propagates without Firebase initialization', () async {
    final api = PushPreferencesApi(
      client((_) async => FakeResponse.error(422, 'validation_error')),
    );
    await expectLater(api.update(quietEnd: 1440), throwsA(isA<ApiError>()));
  });
}
