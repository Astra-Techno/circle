import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_providers.dart';

/// Handles background messages when the app is terminated or in background.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
}

/// Manages Firebase Cloud Messaging: permission, token registration,
/// foreground display, and token refresh.
class FcmService {
  FcmService({required this.ref});
  final Ref ref;

  final _messaging = FirebaseMessaging.instance;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Initialise FCM after Firebase.initializeApp() has been called.
  Future<void> init() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Notification permission denied');
      return;
    }

    // Register the current token with the backend.
    final token = await _messaging.getToken();
    if (token != null) await _registerToken(token);

    // Listen for token refresh (happens periodically or on reinstall).
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(_registerToken);

    // Foreground messages.
    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // When user taps a notification that opened the app from background.
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

    // Check if app was opened from a terminated state via notification.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _onNotificationTap(initial);
  }

  /// Send the FCM token to the backend so it can push to this device.
  Future<void> _registerToken(String token) async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    try {
      await client.post(
        '/devices/register',
        body: {'fcm_token': token, 'platform': defaultTargetPlatform.name},
      );
      debugPrint('[FCM] Token registered with backend');
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  /// Unregister this device's token on logout.
  Future<void> unregisterToken() async {
    final client = ref.read(apiClientProvider);
    final token = await _messaging.getToken();
    if (client == null || token == null) return;
    try {
      await client.post('/devices/unregister', body: {'fcm_token': token});
      debugPrint('[FCM] Token unregistered');
    } catch (e) {
      debugPrint('[FCM] Token unregister failed: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    debugPrint('[FCM] Foreground: ${notification.title} — ${notification.body}');
    // The notification is already shown by the system on Android 13+.
    // For older Android, a local notification channel would be needed.
  }

  void _onNotificationTap(RemoteMessage message) {
    final route = message.data['route'] as String?;
    if (route != null) {
      debugPrint('[FCM] Tapped notification, route: $route');
      // Navigation will be handled by the router when we wire deep links.
    }
  }

  void dispose() {
    _foregroundSub?.cancel();
    _tokenRefreshSub?.cancel();
  }
}

/// Global FCM service provider.
final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService(ref: ref);
  ref.onDispose(service.dispose);
  return service;
});
