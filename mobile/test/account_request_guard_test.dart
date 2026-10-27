import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/auth_api.dart';
import 'support/fake_api.dart';

final config = ApiConfig.parse('https://fictional.example/api/v1')!;
TokenPair pair(String id, [String suffix = '']) => TokenPair(
  accessToken: 'fictional-$id$suffix',
  refreshToken: 'fictional-refresh-$id$suffix',
  server: config.baseUrl.toString(),
  account: StoredAccount(id: id, displayName: 'Fictional $id'),
);
ApiClient client(FakeHandler handler, MemoryTokenStore store) =>
    ApiClient(config: config, tokens: store, adapter: FakeHttpAdapter(handler));

class SlowStore extends MemoryTokenStore {
  final started = Completer<void>(), release = Completer<void>();
  int writes = 0;
  @override
  Future<void> write(TokenPair tokens) async {
    if (++writes == 1) {
      started.complete();
      await release.future;
    }
    await super.write(tokens);
  }
}

class ReLoginBeforeLogout extends ApiClient {
  ReLoginBeforeLogout(FakeHandler handler, MemoryTokenStore store)
    : super(config: config, tokens: store, adapter: FakeHttpAdapter(handler));
  @override
  Future<Object?> post(
    String path, {
    Object? body,
    bool auth = true,
    String? expectedAccount,
    int? expectedSession,
  }) async {
    if (path == '/auth/logout') await saveTokens(pair('1', '-new-login'));
    return super.post(
      path,
      body: body,
      auth: auth,
      expectedAccount: expectedAccount,
      expectedSession: expectedSession,
    );
  }
}

void main() {
  test(
    'logout cannot revoke a newer same-account login before dispatch',
    () async {
      var calls = 0;
      final store = MemoryTokenStore(pair('1'));
      final api = ReLoginBeforeLogout((r) async {
        calls++;
        return FakeResponse.ok({});
      }, store);
      await AuthApi(api).logout();
      expect(calls, 0);
      expect((await store.read())!.accessToken, 'fictional-1-new-login');
    },
  );
  test('stale end-session cannot clear or notify a newer login', () async {
    final store = MemoryTokenStore(pair('1'));
    final api = client((r) async => FakeResponse.ok({}), store);
    await api.currentTokens();
    final revision = api.sessionRevision;
    var ended = 0;
    api.onSessionEnded = (_) {
      ended++;
    };
    await api.saveTokens(pair('1', '-new-login'));
    await api.endSession('Fictional expired', expectedSession: revision);
    expect(ended, 0);
    expect((await store.read())!.accessToken, 'fictional-1-new-login');
  });

  for (final status in [401, 403]) {
    test(
      'old unguarded $status cannot affect same-account new login',
      () async {
        final started = Completer<void>(), release = Completer<void>();
        var calls = 0;
        final store = MemoryTokenStore(pair('1'));
        final api = client((r) async {
          calls++;
          started.complete();
          await release.future;
          return FakeResponse.error(
            status,
            status == 403 ? 'account_inactive' : 'invalid_token',
          );
        }, store);
        final pending = api.get('/me');
        final checked = expectLater(
          pending,
          throwsA(
            isA<ApiError>().having((e) => e.code, 'code', 'session_changed'),
          ),
        );
        await started.future;
        await api.saveTokens(pair('1', '-new-login'));
        release.complete();
        await checked;
        expect(calls, 1);
        expect((await store.read())!.accessToken, 'fictional-1-new-login');
      },
    );
  }
  test(
    'stale device binding cannot register into same-account new session',
    () async {
      var calls = 0;
      final api = client((r) async {
        calls++;
        return FakeResponse.ok({});
      }, MemoryTokenStore(pair('1')));
      await api.currentTokens();
      final old = api.sessionRevision;
      await api.saveTokens(pair('1', '-new-login'));
      await expectLater(
        api.post(
          '/devices/register',
          expectedAccount: '1',
          expectedSession: old,
        ),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'session_changed'),
        ),
      );
      expect(calls, 0);
    },
  );

  test(
    'stale expected-account mutation is rejected before network dispatch',
    () async {
      var calls = 0;
      final api = client((r) async {
        calls++;
        return FakeResponse.ok({});
      }, MemoryTokenStore(pair('2')));
      await expectLater(
        api.patch(
          '/me/notification-preferences',
          expectedAccount: '1',
          body: {'enabled': true},
        ),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'session_changed'),
        ),
      );
      expect(calls, 0);
      expect((await api.currentTokens())!.account!.id, '2');
    },
  );
  test('old 401 cannot retry a mutation under a different account', () async {
    final started = Completer<void>(), release = Completer<void>();
    final seen = <String>[];
    final store = MemoryTokenStore(pair('1'));
    final api = client((r) async {
      seen.add(r.path);
      started.complete();
      await release.future;
      return FakeResponse.error(401, 'invalid_token');
    }, store);
    final pending = api.patch(
      '/me/notification-preferences',
      expectedAccount: '1',
      body: {'enabled': true},
    );
    final checked = expectLater(
      pending,
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'session_changed')),
    );
    await started.future;
    await api.saveTokens(pair('2'));
    release.complete();
    await checked;
    expect(seen, ['/me/notification-preferences']);
    expect((await store.read())!.account!.id, '2');
  });
  test('old refresh result cannot overwrite the next login', () async {
    final started = Completer<void>(), release = Completer<void>();
    var calls = 0;
    final store = MemoryTokenStore(pair('1'));
    final api = client((r) async {
      calls++;
      if (r.path == '/auth/refresh') {
        started.complete();
        await release.future;
        return FakeResponse.ok({
          'access_token': 'fictional-fresh-1',
          'refresh_token': 'fictional-fresh-refresh-1',
        });
      }
      return FakeResponse.error(401, 'invalid_token');
    }, store);
    final pending = api.get(
      '/me/notification-preferences',
      expectedAccount: '1',
    );
    final checked = expectLater(
      pending,
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'session_changed')),
    );
    await started.future;
    await api.saveTokens(pair('2'));
    release.complete();
    await checked;
    expect(calls, 2);
    expect((await store.read())!.accessToken, 'fictional-2');
  });
  test(
    'profile-only token metadata changes survive a same-session refresh',
    () async {
      final started = Completer<void>(), release = Completer<void>();
      var privateCalls = 0;
      final store = MemoryTokenStore(pair('1'));
      final api = client((r) async {
        if (r.path == '/auth/refresh') {
          started.complete();
          await release.future;
          return FakeResponse.ok({
            'access_token': 'fictional-fresh',
            'refresh_token': 'fictional-refresh-fresh',
          });
        }
        if (++privateCalls == 1) {
          return FakeResponse.error(401, 'invalid_token');
        }
        return FakeResponse.ok({'ready': true});
      }, store);
      final request = api.get(
        '/me/notification-preferences',
        expectedAccount: '1',
      );
      await started.future;
      final revision = api.sessionRevision;
      await api.saveTokens(
        (await api.currentTokens())!.copyWith(
          account: const StoredAccount(
            id: '1',
            displayName: 'Updated fictional name',
          ),
        ),
      );
      release.complete();
      await request;
      expect(api.sessionRevision, revision);
      expect(
        (await store.read())!.account!.displayName,
        'Updated fictional name',
      );
    },
  );
  test('serialized persistence keeps newer login after a slow write', () async {
    final store = SlowStore();
    final api = client((_) async => FakeResponse.ok({}), store);
    final first = api.saveTokens(pair('1'));
    await store.started.future;
    final second = api.saveTokens(pair('2'));
    store.release.complete();
    await Future.wait([first, second]);
    expect((await store.read())!.account!.id, '2');
    expect((await api.currentTokens())!.account!.id, '2');
  });
  test(
    'late logout and rejected stale login cannot erase newer credentials',
    () async {
      final started = Completer<void>(), release = Completer<void>();
      final store = MemoryTokenStore(pair('1'));
      final api = client((r) async {
        if (r.path == '/auth/logout') {
          started.complete();
          await release.future;
          return FakeResponse.ok(null);
        }
        return FakeResponse.ok({
          'access_token': 'fictional-3',
          'refresh_token': 'fictional-refresh-3',
          'user': {'id': 3, 'display_name': 'Fictional 3'},
        });
      }, store);
      final logout = AuthApi(api).logout();
      await started.future;
      await api.saveTokens(pair('2'));
      release.complete();
      await logout;
      expect((await store.read())!.account!.id, '2');
      await expectLater(
        AuthApi(
          api,
          canCommitSession: () => false,
        ).login(mobile: '+9995550000911', password: 'fictional password'),
        throwsA(isA<ApiError>()),
      );
      expect((await store.read())!.account!.id, '2');
    },
  );
}
