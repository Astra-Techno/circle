import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/api/api_providers.dart';
import 'package:mobile/features/workspace/application/server_session.dart';
import 'package:mobile/core/local_settings.dart';
import 'support/fake_fcm.dart';
import 'package:mobile/core/notifications/fcm_service.dart';
import 'package:mobile/core/notifications/push_lifecycle.dart';
import 'package:mobile/features/notifications/application/push_ledger.dart';
import 'package:mobile/features/notifications/application/push_session_coordinator.dart';
import 'package:mobile/features/notifications/domain/push_envelope.dart';
import 'support/fake_api.dart';

Future<void> flush() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final clock = DateTime.utc(2026, 10, 27, 5);
Map<String, dynamic> message(PushScope scope) => {
  'event_id': 'a' * 64,
  'type': 'memory.created',
  'api_base_url': scope.server,
  'recipient_id': scope.account,
  'session_scope': scope.sessionHash,
  'group_id': '3',
  'memory_id': '4',
  'comment_id': '',
  'expires_at': '${clock.millisecondsSinceEpoch ~/ 1000 + 3600}',
};
PushBinding binding(String account, FakeHandler handler) {
  final config = ApiConfig.parse('https://fictional.example/api/v1')!;
  return PushBinding(
    ApiClient(
      config: config,
      tokens: MemoryTokenStore(
        TokenPair(
          account: StoredAccount(id: account, displayName: 'Fictional Person'),
          accessToken: 'fictional-$account',
          refreshToken: 'fictional-refresh',
          server: config.baseUrl.toString(),
        ),
      ),
      adapter: FakeHttpAdapter(handler),
    ),
    PushScope(
      server: config.baseUrl.toString(),
      account: account,
      sessionHash: account.padLeft(64, 'a'),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native tap acknowledgement follows durable open staging', () async {
    final gateway = Gateway(), store = MemoryLocalSettingsStore();
    final current = binding('1', (r) async => FakeResponse.ok({}));
    final ledger = PushLedger(store);
    final coordinator = PushSessionCoordinator(
      gateway: gateway,
      current: () async => current,
      ledger: ledger,
      enabled: true,
      clock: () => clock,
    );
    const channel = MethodChannel('circle/push_native');
    var acknowledgements = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'ack') {
            expect(await ledger.pending(current.scope, clock), hasLength(1));
            acknowledgements++;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      coordinator.dispose();
    });
    expect(await coordinator.start(), isTrue);
    gateway.taps.add({
      'circle_native_tap': {
        'id': 'fictional-tap',
        'data': message(current.scope),
      },
    });
    await flush();
    expect(acknowledgements, 1);
    expect(
      (await ledger.pending(current.scope, clock)).single.action,
      PushAction.open,
    );
  });
  test(
    'explicit enable only; repeated start has one subscription and registration',
    () async {
      final gateway = Gateway(), seen = <FakeRequest>[];
      final current = binding('1', (r) async {
        seen.add(r);
        return FakeResponse.ok({'registered': true});
      });
      final coordinator = PushSessionCoordinator(
        gateway: gateway,
        current: () async => current,
        ledger: PushLedger(MemoryLocalSettingsStore()),
        enabled: true,
        clock: () => clock,
      );
      final accepted = <PushReception>[];
      final sub = coordinator.accepted.listen(accepted.add);
      expect(await coordinator.start(requestPermission: true), isTrue);
      expect(await coordinator.start(), isTrue);
      expect(gateway.initialized, 1);
      expect(gateway.requests, 1);
      expect(seen.length, 1);
      gateway.messages.add(message(current.scope));
      gateway.messages.add(message(current.scope));
      gateway.taps.add(message(current.scope));
      await flush();
      expect(accepted.map((x) => x.action), [
        PushAction.display,
        PushAction.open,
      ]);
      gateway.tokens.add('fictional-rotated');
      await flush();
      expect(seen.map((r) => r.path), [
        '/devices/register',
        '/devices/register',
        '/devices/unregister',
      ]);
      expect(seen.last.json['fcm_token'], 'fictional-device');
      await coordinator.stop();
      gateway.messages.add(message(current.scope));
      gateway.tokens.add('fictional-late');
      await flush();
      expect(accepted.length, 2);
      expect(seen.last.path, '/devices/unregister');
      await sub.cancel();
      coordinator.dispose();
      await flush();
      await gateway.close();
    },
  );

  test(
    'same-scope transport restart preserves persisted dedup and allows one tap',
    () async {
      final gateway = Gateway();
      final current = binding('1', (_) async => FakeResponse.ok({}));
      final store = MemoryLocalSettingsStore();
      final coordinator = PushSessionCoordinator(
        gateway: gateway,
        current: () async => current,
        ledger: PushLedger(store),
        enabled: true,
        clock: () => clock,
      );
      final events = <PushReception>[];
      final sub = coordinator.accepted.listen(events.add);
      expect(await coordinator.start(), isTrue);
      gateway.messages.add(message(current.scope));
      await flush();
      await coordinator.stop();
      expect(await coordinator.start(), isTrue);
      gateway.messages.add(message(current.scope));
      gateway.taps.add(message(current.scope));
      await flush();
      expect(events.map((e) => e.action), [
        PushAction.display,
        PushAction.open,
      ]);
      await coordinator.stop();
      await sub.cancel();
      coordinator.dispose();
      await flush();
      await gateway.close();
    },
  );

  test(
    'authentication invalidation remains synchronous and resilient to listener failure',
    () {
      final lifecycle = PushLifecycle();
      lifecycle.listen(
        () => throw StateError('Fictional optional service failure'),
      );
      var invalidated = false;
      final remove = lifecycle.listen(() {
        invalidated = true;
      });
      lifecycle.invalidate();
      expect(invalidated, isTrue);
      remove();
      invalidated = false;
      lifecycle.invalidate();
      expect(invalidated, isFalse);
    },
  );

  test(
    'initialized optional provider cannot create an auth dependency cycle',
    () async {
      final gateway = Gateway();
      final config = ApiConfig.parse('https://fictional.example/api/v1')!;
      final api = ApiClient(
        config: config,
        tokens: MemoryTokenStore(),
        adapter: FakeHttpAdapter((request) async {
          if (request.path == '/auth/login') {
            return FakeResponse.ok({
              'access_token': 'fictional-access',
              'refresh_token': 'fictional-refresh',
              'user': {'id': 1, 'display_name': 'Fictional Person'},
            });
          }
          return FakeResponse.ok({});
        }),
      );
      final container = ProviderContainer(
        overrides: [
          apiConfigProvider.overrideWithValue(config),
          apiClientProvider.overrideWithValue(api),
          fcmGatewayProvider.overrideWithValue(gateway),
          localSettingsStoreProvider.overrideWithValue(
            MemoryLocalSettingsStore(),
          ),
        ],
      );
      container.read(pushSessionCoordinatorProvider);
      await flush();
      expect(
        await container
            .read(serverSessionProvider.notifier)
            .logIn(mobile: '+9995550000811', password: 'fictional password'),
        isNull,
      );
      expect(container.read(serverAccountProvider)?.id, '1');
      expect(gateway.initialized, 0);
      await container.read(serverSessionProvider.notifier).logOut();
      expect(container.read(serverAccountProvider), isNull);
      container.dispose();
      await flush();
      await gateway.close();
    },
  );

  test(
    'SDK failure, denied permission, unsupported platform and disabled flag are calm',
    () async {
      for (final scenario in ['failure', 'denied', 'platform', 'disabled']) {
        final gateway = Gateway();
        var calls = 0;
        gateway.failInit = scenario == 'failure';
        gateway.allowed = scenario != 'denied';
        gateway.supported = scenario != 'platform';
        final current = binding('1', (r) async {
          calls++;
          return FakeResponse.ok({});
        });
        final coordinator = PushSessionCoordinator(
          gateway: gateway,
          current: () async => current,
          ledger: PushLedger(MemoryLocalSettingsStore()),
          enabled: scenario != 'disabled',
        );
        expect(await coordinator.start(), isFalse, reason: scenario);
        expect(calls, 0);
        expect(gateway.requests, 0);
        coordinator.dispose();
        await flush();
        await gateway.close();
      }
    },
  );

  test(
    'logout during SDK initialization cannot install late listeners or register',
    () async {
      final gateway = Gateway()..initGate = Completer<void>();
      var calls = 0;
      PushBinding? current = binding('1', (r) async {
        calls++;
        return FakeResponse.ok({});
      });
      final coordinator = PushSessionCoordinator(
        gateway: gateway,
        current: () async => current,
        ledger: PushLedger(MemoryLocalSettingsStore()),
        enabled: true,
      );
      final starting = coordinator.start(requestPermission: true);
      await flush();
      current = null;
      final stopping = coordinator.stop();
      gateway.initGate!.complete();
      expect(await starting, isFalse);
      await stopping;
      expect(calls, 0);
      expect(gateway.activated, 0);
      coordinator.dispose();
      await flush();
      await gateway.close();
    },
  );

  test(
    'in-flight old registration completes before new account registration; old payload ignored',
    () async {
      final gateway = Gateway(),
          started = Completer<void>(),
          release = Completer<void>();
      final order = <String>[];
      final first = binding('1', (r) async {
        if (r.path == '/devices/register') {
          order.add('A');
          started.complete();
          await release.future;
        }
        return FakeResponse.ok({});
      });
      final second = binding('2', (r) async {
        if (r.path == '/devices/register') order.add('B');
        return FakeResponse.ok({});
      });
      PushBinding? current = first;
      final coordinator = PushSessionCoordinator(
        gateway: gateway,
        current: () async => current,
        ledger: PushLedger(MemoryLocalSettingsStore()),
        enabled: true,
        clock: () => clock,
      );
      final accepted = <PushReception>[];
      final sub = coordinator.accepted.listen(accepted.add);
      final firstStart = coordinator.start();
      await started.future;
      current = second;
      unawaited(coordinator.stop());
      final secondStart = coordinator.start();
      release.complete();
      expect(await firstStart, isFalse);
      expect(await secondStart, isTrue);
      expect(order, ['A', 'B']);
      gateway.messages.add(message(first.scope));
      gateway.messages.add(message(second.scope));
      await flush();
      expect(accepted.length, 1);
      expect(accepted.single.envelope.scope.account, '2');
      await coordinator.stop();
      await sub.cancel();
      coordinator.dispose();
      await flush();
      await gateway.close();
    },
  );

  test(
    'permission revocation and registration failure do not escape as exceptions',
    () async {
      final gateway = Gateway();
      var failing = false;
      final current = binding(
        '1',
        (r) async => failing
            ? FakeResponse.error(503, 'server_error')
            : FakeResponse.ok({}),
      );
      final coordinator = PushSessionCoordinator(
        gateway: gateway,
        current: () async => current,
        ledger: PushLedger(MemoryLocalSettingsStore()),
        enabled: true,
      );
      expect(await coordinator.start(), isTrue);
      gateway.allowed = false;
      expect(await coordinator.start(), isFalse);
      await flush();
      expect(gateway.deactivated, greaterThan(0));
      gateway.allowed = true;
      failing = true;
      expect(await coordinator.start(), isFalse);
      coordinator.dispose();
      await flush();
      await gateway.close();
    },
  );
}
