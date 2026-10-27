import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/account_security_api.dart';
import 'package:mobile/core/api/api_client.dart';
import 'support/fake_api.dart';

final config = ApiConfig.parse('https://fictional.example/api/v1')!;
TokenPair pair([String suffix = '']) => TokenPair(
  accessToken: 'fictional-access$suffix',
  refreshToken: 'fictional-refresh$suffix',
  server: config.baseUrl.toString(),
  account: const StoredAccount(id: '7', displayName: 'Fictional tester'),
);
void main() {
  test(
    'password preserves raw input and never refreshes/replays a 401',
    () async {
      final calls = <FakeRequest>[];
      final api = ApiClient(
        config: config,
        tokens: MemoryTokenStore(pair()),
        adapter: FakeHttpAdapter((r) async {
          calls.add(r);
          return FakeResponse.error(401, 'invalid_token');
        }),
      );
      await api.currentTokens();
      await expectLater(
        AccountSecurityApi(
          api,
          '7',
          api.sessionRevision,
        ).password('  current phrase  ', '  next secure phrase  '),
        throwsA(isA<ApiError>()),
      );
      expect(calls, hasLength(1));
      expect(calls.single.path, '/auth/change-password');
      expect(calls.single.json, {
        'current_password': '  current phrase  ',
        'new_password': '  next secure phrase  ',
      });
    },
  );
  test(
    'password requires explicit sign-in response and is not retried after network loss',
    () async {
      var calls = 0;
      final api = ApiClient(
        config: config,
        tokens: MemoryTokenStore(pair()),
        adapter: FakeHttpAdapter((r) async {
          calls++;
          return FakeResponse.ok({'sign_in_required': false});
        }),
      );
      await expectLater(
        AccountSecurityApi(
          api,
          '7',
          api.sessionRevision,
        ).password('current', 'next'),
        throwsA(isA<ApiError>()),
      );
      expect(calls, 1);
    },
  );
  test('old same-account service cannot mutate a newer session', () async {
    var calls = 0;
    final api = ApiClient(
      config: config,
      tokens: MemoryTokenStore(pair()),
      adapter: FakeHttpAdapter((r) async {
        calls++;
        return FakeResponse.ok(null);
      }),
    );
    await api.currentTokens();
    final security = AccountSecurityApi(api, '7', api.sessionRevision);
    await api.saveTokens(pair('-new-login'));
    await expectLater(
      security.update({'location_label': 'Fictional city'}),
      throwsA(isA<ApiError>()),
    );
    await expectLater(security.revoke('a' * 32), throwsA(isA<ApiError>()));
    await expectLater(
      security.password('current', 'next'),
      throwsA(isA<ApiError>()),
    );
    expect(calls, 0);
  });
  test(
    'sessions use public handle, offset paging and explicit current revocation',
    () async {
      final calls = <FakeRequest>[];
      final id = 'a' * 32;
      final api = ApiClient(
        config: config,
        tokens: MemoryTokenStore(pair()),
        adapter: FakeHttpAdapter((r) async {
          calls.add(r);
          return r.method == 'GET'
              ? FakeResponse.page(
                  [
                    {
                      'id': id,
                      'is_current': true,
                      'device_label': 'Fictional phone',
                      'os_version': 'Android 16',
                      'app_version': '1.0.12 (13)',
                      'ip_address': '192.0.2.1',
                      'location_label': null,
                      'created_at': '2026-10-27 12:00:00',
                      'last_seen_at': '2026-10-27 12:01:00',
                    },
                  ],
                  {'total': 31, 'limit': 30, 'offset': 30},
                )
              : FakeResponse.ok({'current_session_revoked': true});
        }),
      );
      final security = AccountSecurityApi(api, '7', api.sessionRevision);
      final page = await security.sessions(offset: 30);
      expect(page.total, 31);
      expect(page.items.single.id, id);
      expect(page.items.single.current, isTrue);
      expect(calls.single.query, {'limit': '30', 'offset': '30'});
      expect(await security.revoke(id), isTrue);
      expect(calls.last.path, '/me/sessions/$id');
    },
  );
}
