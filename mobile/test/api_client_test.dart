import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/auth_api.dart';
import 'support/fake_api.dart';

final config = ApiConfig.parse('http://circle.test/api/v1')!;

ApiClient clientFor(FakeHandler handler, {TokenStore? tokens}) => ApiClient(
  config: config,
  tokens: tokens ?? MemoryTokenStore(),
  adapter: FakeHttpAdapter(handler),
);

TokenPair pair(String access, String refresh) => TokenPair(
  accessToken: access,
  refreshToken: refresh,
  server: config.baseUrl.toString(),
);

void main() {
  group('ApiConfig', () {
    test('accepts http(s) base URLs and shows the host', () {
      final local = ApiConfig.parse('http://10.0.2.2:8080/api/v1/')!;
      expect(local.baseUrl.toString(), 'http://10.0.2.2:8080/api/v1');
      expect(local.host, '10.0.2.2:8080');
      expect(local.secure, isFalse);
      final production = ApiConfig.parse('https://api.example.org/api/v1')!;
      expect(production.host, 'api.example.org');
      expect(production.secure, isTrue);
    });

    test('refuses anything else', () {
      for (final bad in [
        '',
        'ftp://x/api',
        '/api/v1',
        'http://user:pw@host/api',
        'http://host/api?x=1',
        'not a url',
      ]) {
        expect(ApiConfig.parse(bad), isNull, reason: bad);
      }
    });
  });

  group('ApiError mapping', () {
    const codes = [
      'validation_error',
      'invalid_cursor',
      'unauthorized',
      'invalid_token',
      'invalid_credentials',
      'account_inactive',
      'forbidden',
      'not_member',
      'not_found',
      'member_not_found',
      'owner_protected',
      'last_admin',
      'subgroup_handover_required',
      'depth_limit',
      'already_member',
      'not_parent_member',
      'join_not_allowed',
      'link_revoked',
      'link_expired',
      'link_exhausted',
      'conflict',
      'rate_limited',
      'server_error',
      'media_too_large',
      'media_type_not_allowed',
      'media_invalid',
      'media_limit_reached',
      'upload_expired',
      'media_link_invalid',
    ];

    test('every contract code has calm words, never the server text', () {
      const raw = 'SQLSTATE[23000] raw server text';
      for (final code in codes) {
        final error = ApiError.fromResponse(400, {
          'success': false,
          'error': {'code': code, 'message': raw},
        });
        expect(error.code, code);
        expect(error.message, isNot(contains('SQLSTATE')), reason: code);
        expect(error.message, isNotEmpty);
        expect(
          error.message,
          isNot('That didn’t work. Please try again.'),
          reason: '$code should have its own wording',
        );
      }
    });

    test('short validation messages name the field', () {
      final error = ApiError.fromResponse(422, {
        'success': false,
        'error': {
          'code': 'validation_error',
          'message': 'Name must be 1–100 characters.',
        },
      });
      expect(error.message, 'Name must be 1–100 characters.');
      final long = ApiError.fromResponse(422, {
        'success': false,
        'error': {'code': 'validation_error', 'message': 'x' * 300},
      });
      expect(long.message, 'Please check what you entered and try again.');
    });

    test('500s never leak the server text', () {
      final error = ApiError.fromResponse(500, {
        'success': false,
        'error': {
          'code': 'server_error',
          'message': 'PDOException: table users at /var/www',
        },
      });
      expect(error.message, isNot(contains('PDO')));
      expect(error.message, contains('Something went wrong on the server'));
      final html = ApiError.fromResponse(502, '<html>Bad gateway</html>');
      expect(html.code, 'server_error');
      expect(html.message, isNot(contains('html')));
    });

    test('429 says when to try again', () {
      final error = ApiError.fromResponse(429, {
        'success': false,
        'error': {'code': 'rate_limited', 'message': 'Too many requests'},
      }, retryAfterHeader: '42');
      expect(error.retryAfter, const Duration(seconds: 42));
      expect(error.message, contains('42 seconds'));
      final soon = ApiError.fromResponse(429, {
        'success': false,
        'error': {'code': 'rate_limited', 'message': 'x'},
      });
      expect(soon.message, contains('in a moment'));
    });

    test('lists the subgroups to hand over', () {
      final error = ApiError.fromResponse(409, {
        'success': false,
        'error': {
          'code': 'subgroup_handover_required',
          'message': 'x',
          'details': {
            'groups': [
              {'id': 4, 'name': 'Sec A', 'reason': 'owner'},
            ],
          },
        },
      });
      expect(error.message, contains('Sec A'));
    });

    test('offline, timeouts and odd answers', () async {
      for (final (type, words) in [
        (DioExceptionType.connectionError, 'offline'),
        (DioExceptionType.connectionTimeout, 'taking too long'),
        (DioExceptionType.receiveTimeout, 'taking too long'),
        (DioExceptionType.badCertificate, 'certificate'),
      ]) {
        final api = clientFor((_) => FakeResponse.network(type));
        await expectLater(
          api.get('/groups'),
          throwsA(
            isA<ApiError>().having(
              (e) => e.message,
              'message',
              contains(words),
            ),
          ),
        );
      }
      final odd = clientFor((_) => const FakeResponse(200, {'hello': 1}));
      await expectLater(
        odd.get('/groups'),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'bad_response')),
      );
    });
  });

  group('auth', () {
    test('register (202) → log in → tokens stored → /me', () async {
      final server = FakeCircleServer();
      final store = MemoryTokenStore();
      final api = ApiClient(
        config: config,
        tokens: store,
        adapter: server.adapter,
      );
      final auth = AuthApi(api);
      // Spaces in a passphrase are kept exactly (never trimmed).
      const password = '  correct horse battery  ';
      await auth.register(
        mobile: '+15550001111',
        password: password,
        displayName: ' Asha ',
      );
      final account = await auth.login(
        mobile: '+15550001111',
        password: password,
      );
      expect(account.displayName, 'Asha');
      expect(server.passwords['+15550001111'], password);
      final stored = await store.read();
      expect(stored?.accessToken, startsWith('access-'));
      expect(stored?.server, config.baseUrl.toString());
      expect(stored?.account?.id, account.id);
      expect((await auth.me()).id, account.id);
      final me = server.adapter.requests.last;
      expect(me.bearer, stored!.accessToken);
      // The register request carried no bearer and no tokens came back.
      final register = server.adapter.requests.first;
      expect(register.path, '/auth/register');
      expect(register.bearer, isNull);
      expect(stored.toString(), isNot(contains('access-')));
    });

    test('a failed log-in is generic and stores nothing', () async {
      final server = FakeCircleServer()..addUser('+15550002222', 'x' * 20, 'B');
      final store = MemoryTokenStore();
      final api = ApiClient(
        config: config,
        tokens: store,
        adapter: server.adapter,
      );
      await expectLater(
        AuthApi(api).login(mobile: '+15550002222', password: 'wrong' * 4),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', 'invalid_credentials')
              .having((e) => e.message, 'message', contains('didn’t work')),
        ),
      );
      expect(await store.read(), isNull);
    });

    test('logout revokes on the server and clears tokens', () async {
      final server = FakeCircleServer();
      final user = server.addUser('+15550003333', 'y' * 20, 'C');
      final store = MemoryTokenStore();
      final api = ApiClient(
        config: config,
        tokens: store,
        adapter: server.adapter,
      );
      await AuthApi(api).login(mobile: '+15550003333', password: 'y' * 20);
      await AuthApi(api).logout();
      expect(server.adapter.count('POST', '/auth/logout'), 1);
      expect(server.access.values, isNot(contains(user)));
      expect(await store.read(), isNull);
    });

    test('logout offline still forgets the session', () async {
      final store = MemoryTokenStore(pair('a', 'r'));
      final api = clientFor(
        (_) => const FakeResponse.network(DioExceptionType.connectionError),
        tokens: store,
      );
      await AuthApi(api).logout();
      expect(await store.read(), isNull);
    });

    test('tokens from another server are ignored', () async {
      final store = MemoryTokenStore(
        const TokenPair(
          accessToken: 'a',
          refreshToken: 'r',
          server: 'http://other.test/api/v1',
        ),
      );
      final api = clientFor((_) => FakeResponse.ok(null), tokens: store);
      expect(await api.currentTokens(), isNull);
    });
  });

  group('token refresh', () {
    test('two concurrent 401s share one refresh, then both retry', () async {
      var refreshes = 0;
      final gate = Completer<void>();
      final seen = <String?>[];
      final api = clientFor((request) async {
        if (request.path == '/auth/refresh') {
          refreshes++;
          expect(request.json['refresh_token'], 'r1');
          expect(request.bearer, isNull);
          await gate.future;
          return FakeResponse.ok({
            'access_token': 'a2',
            'refresh_token': 'r2',
            'token_type': 'Bearer',
            'expires_in': 3600,
          });
        }
        seen.add(request.bearer);
        return request.bearer == 'a2'
            ? FakeResponse.ok({'path': request.path})
            : FakeResponse.error(401, 'invalid_token');
      }, tokens: MemoryTokenStore(pair('a1', 'r1')));
      final first = api.get('/groups');
      final second = api.get('/memories');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();
      expect(await first, {'path': '/groups'});
      expect(await second, {'path': '/memories'});
      expect(refreshes, 1, reason: 'refresh tokens are single-use');
      expect(seen.where((token) => token == 'a1'), hasLength(2));
      expect(seen.where((token) => token == 'a2'), hasLength(2));
      final tokens = await api.currentTokens();
      expect(tokens?.accessToken, 'a2');
      expect(tokens?.refreshToken, 'r2');
    });

    test('a refused refresh ends the session calmly', () async {
      final store = MemoryTokenStore(pair('a1', 'r1'));
      final ended = <String>[];
      final api = clientFor((request) {
        if (request.path == '/auth/refresh') {
          return FakeResponse.error(401, 'invalid_token');
        }
        return FakeResponse.error(401, 'invalid_token');
      }, tokens: store)..onSessionEnded = ended.add;
      await expectLater(
        api.get('/groups'),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'session_expired'),
        ),
      );
      expect(ended, ['Your session ended. Please log in again.']);
      expect(await store.read(), isNull);
    });

    test('offline during refresh keeps the session', () async {
      final store = MemoryTokenStore(pair('a1', 'r1'));
      final ended = <String>[];
      final api = clientFor((request) {
        if (request.path == '/auth/refresh') {
          return const FakeResponse.network(DioExceptionType.connectionError);
        }
        return FakeResponse.error(401, 'invalid_token');
      }, tokens: store)..onSessionEnded = ended.add;
      await expectLater(
        api.get('/groups'),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'network_offline'),
        ),
      );
      expect(ended, isEmpty);
      expect(await store.read(), isNotNull);
    });

    test('a retried request that fails again is not refreshed twice', () async {
      var refreshes = 0;
      final api = clientFor((request) {
        if (request.path == '/auth/refresh') {
          refreshes++;
          return FakeResponse.ok({
            'access_token': 'a$refreshes',
            'refresh_token': 'r$refreshes',
          });
        }
        return FakeResponse.error(401, 'invalid_token');
      }, tokens: MemoryTokenStore(pair('a0', 'r0')));
      await expectLater(api.get('/groups'), throwsA(isA<ApiError>()));
      expect(refreshes, 1);
    });

    test('an inactive account ends the session', () async {
      final store = MemoryTokenStore(pair('a1', 'r1'));
      final ended = <String>[];
      final api = clientFor(
        (_) => FakeResponse.error(403, 'account_inactive'),
        tokens: store,
      )..onSessionEnded = ended.add;
      await expectLater(api.get('/me'), throwsA(isA<ApiError>()));
      expect(ended.single, contains('can’t be used'));
      expect(await store.read(), isNull);
    });
  });
}
