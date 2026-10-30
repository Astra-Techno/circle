import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/local_settings.dart';
import 'package:mobile/core/notifications/fcm_service.dart';
import 'package:mobile/core/notifications/first_launch_permission.dart';

class Gateway implements FcmGateway {
  int requests = 0;
  bool broken = false;
  @override
  bool get supported => true;
  @override
  Future<void> initialize() async {
    if (broken) throw StateError('unavailable');
  }

  @override
  Future<bool> permission({required bool request}) async {
    if (request) requests++;
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'first launch requests permission once despite denial on Android',
    () async {
      final gateway = Gateway(), store = MemoryLocalSettingsStore();
      await requestFirstLaunchNotifications(
        gateway: gateway,
        store: store,
        ios: false,
      );
      await requestFirstLaunchNotifications(
        gateway: gateway,
        store: store,
        ios: false,
      );
      expect(gateway.requests, 1);
    },
  );
  test('iOS checks OS permission despite surviving Keychain marker', () async {
    final gateway = Gateway(), store = MemoryLocalSettingsStore();
    store.values['circle.push.first-launch-prompt.v1'] = 'shown';
    await requestFirstLaunchNotifications(
      gateway: gateway,
      store: store,
      ios: true,
    );
    expect(gateway.requests, 1);
  });
  test('SDK failure is optional and does not mark successful prompt', () async {
    final gateway = Gateway()..broken = true,
        store = MemoryLocalSettingsStore();
    await requestFirstLaunchNotifications(
      gateway: gateway,
      store: store,
      ios: false,
    );
    expect(gateway.requests, 0);
    expect(store.values, isEmpty);
  });
}
