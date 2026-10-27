import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/local_settings.dart';
import 'package:mobile/features/notifications/application/push_ledger.dart';
import 'package:mobile/features/notifications/application/push_presentation.dart';
import 'package:mobile/features/notifications/application/push_session_coordinator.dart';
import 'package:mobile/features/notifications/domain/push_envelope.dart';
import 'push_presentation_test.dart' show now, preferences, binding, payload;
import 'support/fake_api.dart';
import 'support/fake_fcm.dart';

void main() {
  for (final mode in [
    'success',
    'demoted',
    'empty',
    'wrong_group',
    'disabled',
    'quiet',
  ]) {
    test('report push rechecks private admin queue: $mode', () async {
      final gateway = Gateway();
      final current = binding((r) async {
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
        if (r.path.startsWith('/devices/')) return FakeResponse.ok(null);
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
      });
      final data = payload(current.scope)
        ..remove('memory_id')
        ..remove('comment_id');
      data['type'] = 'group.report';
      final envelope = PushEnvelope.parse(data, current.scope, now)!;
      expect(envelope.toData(), data);
      expect(data.length, 7);
      expect(envelope.destination, '/groups/g/3/reports');
      expect(
        PushEnvelope.parse({...data, 'reporter_id': '7'}, current.scope, now),
        isNull,
      );
      final coordinator = PushSessionCoordinator(
        gateway: gateway,
        current: () async => current,
        ledger: PushLedger(MemoryLocalSettingsStore()),
        enabled: true,
        clock: () => now,
      );
      final routes = <String>[];
      final presentation = PushPresentation(
        coordinator: coordinator,
        display: (r) async {
          routes.add('display');
          return true;
        },
        open: (r) async {
          routes.add(r.envelope.destination);
          return true;
        },
        dismiss: () {},
        clock: () => now,
      );
      await coordinator.start();
      await coordinator.ledger.stage(envelope, PushAction.display, now);
      await coordinator.ledger.stage(envelope, PushAction.open, now);
      await presentation.pump();
      expect(
        routes,
        mode == 'success' ? ['display', '/groups/g/3/reports'] : isEmpty,
      );
      presentation.dispose();
      await coordinator.stop();
      coordinator.dispose();
      await gateway.close();
    });
  }
}
