import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/local_settings.dart';
import 'package:mobile/features/notifications/application/push_ledger.dart';
import 'package:mobile/features/notifications/application/push_presentation.dart';
import 'package:mobile/features/notifications/application/push_session_coordinator.dart';
import 'package:mobile/features/notifications/domain/push_envelope.dart';
import 'support/fake_api.dart';
import 'support/fake_fcm.dart';

final now = DateTime.utc(2026, 10, 27, 10);
Map<String, Object?> preferences() => {
  'enabled': true,
  'categories': {
    for (final k in [
      'memories',
      'replies_reactions',
      'groups',
      'chats',
      'events',
      'polls',
      'albums',
      'security',
    ])
      k: true,
  },
  'quiet_hours': false,
  'quiet_start': 1320,
  'quiet_end': 420,
  'timezone': 'UTC',
};
Map<String, dynamic> payload(PushScope scope) => {
  'event_id': 'a' * 64,
  'type': 'memory.created',
  'api_base_url': scope.server,
  'recipient_id': scope.account,
  'session_scope': scope.sessionHash,
  'group_id': '3',
  'memory_id': '4',
  'comment_id': '',
  'expires_at': '${now.millisecondsSinceEpoch ~/ 1000 + 3600}',
};
Future<void> flush() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

PushBinding binding(FakeHandler handler) {
  final config = ApiConfig.parse('https://fictional.example/api/v1')!;
  return PushBinding(
    ApiClient(
      config: config,
      tokens: MemoryTokenStore(
        TokenPair(
          accessToken: 'fictional-access',
          refreshToken: 'fictional-refresh',
          server: config.baseUrl.toString(),
          account: const StoredAccount(id: '7', displayName: 'Fictional'),
        ),
      ),
      adapter: FakeHttpAdapter(handler),
    ),
    PushScope(
      server: config.baseUrl.toString(),
      account: '7',
      sessionHash: 'b' * 64,
    ),
  );
}

void main() {
  test(
    'reception persists without a renderer and completes after authorized display',
    () async {
      final gateway = Gateway(), store = MemoryLocalSettingsStore();
      var unavailable = true;
      final calls = <String>[];
      final current = binding((r) async {
        calls.add(r.path);
        if (r.path == '/me/notification-preferences') {
          return FakeResponse.ok(preferences());
        }
        if (r.path == '/memories/4') {
          return unavailable
              ? FakeResponse.error(503, 'server_error')
              : FakeResponse.ok({'id': 4, 'group_id': 3, 'comments': []});
        }
        return FakeResponse.ok({});
      });
      final coordinator = PushSessionCoordinator(
        gateway: gateway,
        current: () async => current,
        ledger: PushLedger(store),
        enabled: true,
        clock: () => now,
      );
      expect(await coordinator.start(), isTrue);
      gateway.messages.add(payload(current.scope));
      await flush();
      expect((await PushLedger(store).pending(current.scope, now)).length, 1);
      var displays = 0, opens = 0;
      final presenter = PushPresentation(
        coordinator: coordinator,
        display: (r) async {
          displays++;
          return true;
        },
        open: (r) async {
          opens++;
          return true;
        },
        dismiss: () {},
        clock: () => now,
      );
      presenter.listen();
      await presenter.pump();
      expect(displays, 0);
      expect((await coordinator.pending()).length, 1);
      unavailable = false;
      await presenter.pump();
      expect(displays, 1);
      expect(await coordinator.pending(), isEmpty);
      gateway.messages.add(payload(current.scope));
      await flush();
      expect(displays, 1);
      gateway.taps.add(payload(current.scope));
      await flush();
      await presenter.pump();
      expect(opens, 1);
      expect(calls.every((p) => !p.startsWith('https://')), isTrue);
      presenter.dispose();
      await coordinator.stop();
      coordinator.dispose();
      await flush();
      await gateway.close();
    },
  );
  test(
    'permanent loss of access cancels pending and never displays content',
    () async {
      final gateway = Gateway(),
          current = binding((r) async {
            if (r.path == '/me/notification-preferences') {
              return FakeResponse.ok(preferences());
            }
            if (r.path == '/memories/4') {
              return FakeResponse.error(404, 'not_found');
            }
            return FakeResponse.ok({});
          });
      final coordinator = PushSessionCoordinator(
        gateway: gateway,
        current: () async => current,
        ledger: PushLedger(MemoryLocalSettingsStore()),
        enabled: true,
        clock: () => now,
      );
      var shown = 0, unavailable = 0;
      final presenter = PushPresentation(
        coordinator: coordinator,
        display: (r) async {
          shown++;
          return true;
        },
        open: (r) async {
          shown++;
          return true;
        },
        dismiss: () {},
        unavailable: () {
          unavailable++;
        },
        clock: () => now,
      );
      presenter.listen();
      await coordinator.start();
      gateway.messages.add(payload(current.scope));
      await flush();
      await presenter.pump();
      gateway.taps.add(payload(current.scope));
      await flush();
      await presenter.pump();
      expect(unavailable, 1);
      expect(shown, 0);
      expect(await coordinator.pending(), isEmpty);
      presenter.dispose();
      await coordinator.stop();
      coordinator.dispose();
      await flush();
      await gateway.close();
    },
  );
  test(
    'logout during content lookup cannot present an old account update',
    () async {
      final gateway = Gateway(),
          started = Completer<void>(),
          release = Completer<void>();
      PushBinding? current = binding((r) async {
        if (r.path == '/me/notification-preferences') {
          return FakeResponse.ok(preferences());
        }
        if (r.path == '/memories/4') {
          started.complete();
          await release.future;
          return FakeResponse.ok({'id': 4, 'group_id': 3, 'comments': []});
        }
        return FakeResponse.ok({});
      });
      final original = current;
      final coordinator = PushSessionCoordinator(
        gateway: gateway,
        current: () async => current,
        ledger: PushLedger(MemoryLocalSettingsStore()),
        enabled: true,
        clock: () => now,
      );
      var shown = 0;
      final presenter = PushPresentation(
        coordinator: coordinator,
        display: (r) async {
          shown++;
          return true;
        },
        open: (r) async {
          shown++;
          return true;
        },
        dismiss: () {},
        clock: () => now,
      );
      presenter.listen();
      await coordinator.start();
      gateway.messages.add(payload(original.scope));
      await started.future;
      current = null;
      unawaited(coordinator.stop());
      release.complete();
      await flush();
      await presenter.pump();
      expect(shown, 0);
      presenter.dispose();
      coordinator.dispose();
      await flush();
      await gateway.close();
    },
  );
  test(
    'failed UI handoff stays pending until a renderer can accept it',
    () async {
      final gateway = Gateway(),
          current = binding(
            (r) async => FakeResponse.ok(
              r.path == '/me/notification-preferences'
                  ? preferences()
                  : r.path == '/memories/4'
                  ? {'id': 4, 'group_id': 3, 'comments': []}
                  : {},
            ),
          );
      final coordinator = PushSessionCoordinator(
        gateway: gateway,
        current: () async => current,
        ledger: PushLedger(MemoryLocalSettingsStore()),
        enabled: true,
        clock: () => now,
      );
      var ready = false;
      final presenter = PushPresentation(
        coordinator: coordinator,
        display: (r) async => ready,
        open: (r) async => ready,
        dismiss: () {},
        clock: () => now,
      );
      presenter.listen();
      await coordinator.start();
      gateway.messages.add(payload(current.scope));
      await flush();
      await presenter.pump();
      expect((await coordinator.pending()).length, 1);
      ready = true;
      await presenter.pump();
      expect(await coordinator.pending(), isEmpty);
      presenter.dispose();
      await coordinator.stop();
      coordinator.dispose();
      await flush();
      await gateway.close();
    },
  );
}
