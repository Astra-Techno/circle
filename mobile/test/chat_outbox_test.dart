import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/scoped_api.dart';
import 'package:mobile/core/local_settings.dart';
import 'package:mobile/features/chat/application/chat_outbox.dart';

void main() {
  test(
    'committed-but-offline send survives restart, retries same id and clears after success',
    () async {
      final store = MemoryLocalSettingsStore(),
          api = ApiClient(
            config: ApiConfig.parse('http://circle.test/api/v1')!,
            tokens: MemoryTokenStore(),
          );
      final scope = ScopedApi(api, '7', api.sessionRevision, () => true);
      final delivered = <String>{};
      final first = ChatOutbox(scope, store, testSession: 'fictional-A');
      const body = {
        'body': 'Fictional pending message',
        'client_id': 'fictional-pending-001',
      };
      await expectLater(
        first.send('8', body, (chat, b) async {
          delivered.add(b['client_id'] as String);
          throw const ApiError('Offline', code: ApiError.offline);
        }),
        throwsA(isA<ApiError>()),
      );
      expect(await first.pending(), hasLength(1));
      await first.dispose();
      final restored = ChatOutbox(scope, store, testSession: 'fictional-A');
      expect(await restored.pending(), hasLength(1));
      await restored.flush((chat, b) async {
        expect(chat, '8');
        delivered.add(b['client_id'] as String);
      });
      expect(delivered, hasLength(1));
      expect(await restored.pending(), isEmpty);
    },
  );
  test(
    'outbox is isolated by session and permanent failures wait for explicit retry',
    () async {
      final store = MemoryLocalSettingsStore(),
          api = ApiClient(
            config: ApiConfig.parse('http://circle.test/api/v1')!,
            tokens: MemoryTokenStore(),
          );
      var active = true;
      final scope = ScopedApi(api, '7', api.sessionRevision, () => active);
      final queue = ChatOutbox(scope, store, testSession: 'A');
      const body = {'body': 'Fictional', 'client_id': 'fictional-pending-002'};
      await expectLater(
        queue.send(
          '8',
          body,
          (chat, b) async => throw const ApiError(
            'Read-only',
            code: 'not_member',
            status: 403,
          ),
        ),
        throwsA(isA<ApiError>()),
      );
      var calls = 0;
      await queue.flush((chat, b) async {
        calls++;
      });
      expect(calls, 0);
      expect(
        await ChatOutbox(scope, store, testSession: 'B').pending(),
        isEmpty,
      );
      await queue.retry(body['client_id']!);
      await queue.flush((chat, b) async {
        calls++;
      });
      expect(calls, 1);
      expect(await queue.pending(), isEmpty);
      active = false;
      await expectLater(
        queue.send('8', body, (chat, b) async {
          calls++;
        }),
        throwsA(isA<ApiError>()),
      );
      expect(calls, 1);
    },
  );
}
