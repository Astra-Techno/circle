import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/local_settings.dart';
import 'package:mobile/core/notifications/native_push.dart';
import 'package:mobile/features/notifications/application/background_push.dart';
import 'package:mobile/features/notifications/application/push_ledger.dart';
import 'package:mobile/features/notifications/domain/push_envelope.dart';
import 'support/fake_api.dart';
import 'push_presentation_test.dart' show now, payload, preferences;

final config = ApiConfig.parse('https://fictional.example/api/v1')!;
TokenPair token([String sid = 'a']) => TokenPair(
  accessToken:
      'fictional.${base64Url.encode(utf8.encode(jsonEncode({'type': 'access', 'sub': 7, 'sid': sid * 32}))).replaceAll('=', '')}.fictional',
  refreshToken: 'fictional-refresh',
  server: config.baseUrl.toString(),
  account: const StoredAccount(id: '7', displayName: 'Fictional'),
);
PushScope scope(TokenPair tokens) => PushScope.fromAccessToken(
  server: tokens.server,
  account: tokens.account!.id,
  token: tokens.accessToken,
)!;

class Mutex implements PushMutex {
  Future<void> tail = Future.value();
  int calls = 0;
  @override
  Future<T> run<T>(Future<T> Function() action) {
    calls++;
    final task = tail.then((_) => action());
    tail = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }
}

void main() {
  for (final mode in [
    'success',
    'offline',
    'expired',
    'not_member',
    'disabled',
    'quiet',
    'wrong_group',
    'missing_comment',
    'logout',
    'same_account_new_session',
    'show_failed',
    'foreign_server',
  ]) {
    test(
      'background $mode validates, authorizes and preserves safe retry',
      () async {
        TokenPair? live = token();
        final initial = live;
        final store = MemoryLocalSettingsStore(), mutex = Mutex();
        final ledger = PushLedger(store, mutex: mutex);
        var shown = 0;
        final paths = <String>[];
        final processor = BackgroundPushProcessor(
          config: config,
          readTokens: () async => live,
          ledger: ledger,
          clock: () => now,
          show: (envelope) async {
            shown++;
            return mode != 'show_failed';
          },
          clientFactory: (tokens) => ApiClient(
            config: config,
            tokens: MemoryTokenStore(tokens),
            allowRefresh: false,
            adapter: FakeHttpAdapter((r) async {
              paths.add(r.path);
              if (r.path == '/me/notification-preferences') {
                if (mode == 'expired') {
                  return FakeResponse.error(401, 'invalid_token');
                }
                return FakeResponse.ok({
                  ...preferences(),
                  if (mode == 'disabled') 'enabled': false,
                  if (mode == 'quiet') ...{
                    'quiet_hours': true,
                    'quiet_start': 0,
                    'quiet_end': 1439,
                  },
                });
              }
              if (mode == 'logout') live = null;
              if (mode == 'same_account_new_session') live = token('b');
              if (mode == 'offline') {
                return FakeResponse.error(503, 'server_error');
              }
              if (mode == 'not_member') {
                return FakeResponse.error(403, 'not_member');
              }
              return FakeResponse.ok({
                'id': 4,
                'group_id': mode == 'wrong_group' ? 99 : 3,
                'comments': [],
              });
            }),
          ),
        );
        final data = payload(scope(initial));
        if (mode == 'missing_comment') {
          data.addAll({'type': 'comment.created', 'comment_id': '8'});
        }
        if (mode == 'foreign_server') {
          data['api_base_url'] = 'https://foreign.example/api/v1';
        }
        await processor.receive(data);
        expect(paths, isNot(contains('/auth/refresh')));
        expect(initial.refreshToken, 'fictional-refresh');
        expect(shown, ['success', 'show_failed'].contains(mode) ? 1 : 0);
        final pending = await ledger.pending(scope(initial), now);
        expect(
          pending.length,
          [
                'offline',
                'expired',
                'quiet',
                'logout',
                'same_account_new_session',
                'show_failed',
              ].contains(mode)
              ? 1
              : 0,
        );
        if (mode == 'foreign_server') expect(paths, isEmpty);
        if (mode == 'success') {
          await processor.receive(data);
          expect(shown, 1);
          expect(paths.length, 2);
        }
      },
    );
  }
  test(
    'two engine ledgers serialize duplicate stage and preserve other session pending',
    () async {
      final store = MemoryLocalSettingsStore(), mutex = Mutex();
      final first = PushLedger(store, mutex: mutex),
          second = PushLedger(store, mutex: mutex);
      final a = scope(token()), b = scope(token('b'));
      final envelope = PushEnvelope.parse(payload(a), a, now)!;
      final results = await Future.wait([
        first.stage(envelope, PushAction.display, now),
        second.stage(envelope, PushAction.display, now),
      ]);
      expect(results.where((v) => v), hasLength(1));
      final other = PushEnvelope.parse(payload(b), b, now)!;
      await second.stage(other, PushAction.display, now);
      expect(await first.pending(a, now), hasLength(1));
      expect(await second.pending(b, now), hasLength(1));
      await first.clear(a);
      expect(await first.pending(a, now), isEmpty);
      expect(await second.pending(b, now), hasLength(1));
      expect(mutex.calls, greaterThan(3));
    },
  );
}
