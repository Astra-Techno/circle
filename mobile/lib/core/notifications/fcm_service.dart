import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'native_push.dart';

abstract interface class FcmGateway {
  bool get supported;
  Future<void> initialize();
  Future<bool> permission({required bool request});
  Future<void> activate();
  Future<void> bindScope(String? scope);
  Future<String?> token();
  Future<void> deactivate();
  Stream<String> get tokenChanges;
  Stream<Map<String, dynamic>> get foreground;
  Stream<Map<String, dynamic>> get opened;
  Future<Map<String, dynamic>?> initialMessage();
}

/// Lazy adapter: constructing providers never touches Firebase/plugin state.
class FirebaseFcmGateway implements FcmGateway {
  static Future<void>? _initializing;
  FirebaseMessaging get _sdk => FirebaseMessaging.instance;
  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  @override
  Future<void> initialize() async {
    if (Firebase.apps.isNotEmpty) return;
    final work = _initializing ??= Firebase.initializeApp().then<void>((_) {});
    try {
      await work;
    } finally {
      if (identical(_initializing, work)) _initializing = null;
    }
  }

  @override
  Future<bool> permission({required bool request}) async {
    final settings = request
        ? await _sdk.requestPermission(alert: true, badge: true, sound: true)
        : await _sdk.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  // Keep Firebase auto-init off across restarts; token acquisition is explicit.
  Future<void> activate() => _sdk.setAutoInitEnabled(false);
  @override
  Future<void> bindScope(String? scope) => const NativePushBridge().bind(scope);
  @override
  Future<String?> token() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // APNs registration can complete after the permission dialog closes.
      for (var attempt = 0; attempt < 10; attempt++) {
        if (await _sdk.getAPNSToken() != null) return _sdk.getToken();
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      return null;
    }
    return _sdk.getToken();
  }

  @override
  Future<void> deactivate() async {
    try {
      await _sdk.setAutoInitEnabled(false);
    } catch (_) {}
    try {
      await _sdk.deleteToken();
    } catch (_) {}
  }

  @override
  Stream<String> get tokenChanges => _sdk.onTokenRefresh;
  @override
  Stream<Map<String, dynamic>> get foreground =>
      FirebaseMessaging.onMessage.map((m) => m.data);
  @override
  Stream<Map<String, dynamic>> get opened => Stream.multi((controller) {
    final subscriptions = [
      FirebaseMessaging.onMessageOpenedApp
          .map((m) => m.data)
          .listen(controller.add, onError: controller.addError),
      const NativePushBridge().opened.listen(
        controller.add,
        onError: controller.addError,
      ),
    ];
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
  }, isBroadcast: true);
  @override
  Future<Map<String, dynamic>?> initialMessage() async =>
      await const NativePushBridge().initial() ??
      (await _sdk.getInitialMessage())?.data;
}

final fcmGatewayProvider = Provider<FcmGateway>((ref) => FirebaseFcmGateway());
