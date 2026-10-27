import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/local_settings.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/features/notifications/application/background_push.dart';
import 'package:mobile/features/notifications/application/push_ledger.dart';
import 'background_push_test.dart' show config, token, scope;
import 'push_presentation_test.dart' show now, preferences, payload;
import 'support/fake_api.dart';

void main() {
  for (final mode in [
    'success',
    'demoted',
    'empty',
    'wrong_group',
    'disabled',
    'quiet',
  ]) {
    test('headless report authorization: $mode', () async {
      final tokens = token();
      var shown = 0;
      final processor = BackgroundPushProcessor(
        config: config,
        readTokens: () async => tokens,
        ledger: PushLedger(MemoryLocalSettingsStore()),
        clock: () => now,
        show: (_) async {
          shown++;
          return true;
        },
        clientFactory: (tokens) => ApiClient(
          config: config,
          tokens: MemoryTokenStore(tokens),
          allowRefresh: false,
          adapter: FakeHttpAdapter((r) async {
            if (r.path == '/me/notification-preferences') {
              return FakeResponse.ok({
                ...preferences(),
                if (mode == 'disabled')
                  'categories': {
                    ...preferences()['categories'] as Map,
                    'groups': false,
                  },
                if (mode == 'quiet') ...{
                  'quiet_hours': true,
                  'quiet_start': 0,
                  'quiet_end': 1439,
                },
              });
            }
            expect(r.path, '/groups/3/reports');
            if (mode == 'demoted') return FakeResponse.error(403, 'forbidden');
            return FakeResponse.ok({
              'group_id': mode == 'wrong_group' ? 9 : 3,
              'items': mode == 'empty'
                  ? []
                  : [
                      {'id': 1},
                    ],
            });
          }),
        ),
      );
      final data = payload(scope(tokens))
        ..remove('memory_id')
        ..remove('comment_id');
      data['type'] = 'group.report';
      await processor.receive(data);
      expect(shown, mode == 'success' ? 1 : 0);
    });
  }
}
