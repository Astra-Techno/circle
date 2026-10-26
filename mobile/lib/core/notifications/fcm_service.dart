import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Background presentation requires authenticated scope validation in its own
/// isolate. Until that path is implemented, data-only messages do not display.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

abstract interface class FcmGateway {
  bool get supported;
  Future<void> initialize();
  Future<bool> permission({required bool request});
  Future<void> activate();
  Future<String?> token();
  Future<void> deactivate();
  Stream<String> get tokenChanges;
  Stream<Map<String, dynamic>> get foreground;
  Stream<Map<String, dynamic>> get opened;
  Future<Map<String, dynamic>?> initialMessage();
}

/// Lazy adapter: constructing providers never touches Firebase/plugin state.
class FirebaseFcmGateway implements FcmGateway {
  FirebaseMessaging get _sdk => FirebaseMessaging.instance;
  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
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
  Future<String?> token() => _sdk.getToken();
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
  Stream<Map<String, dynamic>> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);
  @override
  Future<Map<String, dynamic>?> initialMessage() async =>
      (await _sdk.getInitialMessage())?.data;
}

final fcmGatewayProvider = Provider<FcmGateway>((ref) => FirebaseFcmGateway());
