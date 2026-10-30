import 'package:flutter/foundation.dart';
import '../local_settings.dart';
import 'fcm_service.dart';

/// Device permission only. No token is acquired or registered before sign-in.
Future<void> requestFirstLaunchNotifications({
  FcmGateway? gateway,
  LocalSettingsStore? store,
  bool? ios,
}) async {
  final service = gateway ?? FirebaseFcmGateway();
  if (!service.supported) return;
  final settings = store ?? SecureLocalSettingsStore();
  final apple = ios ?? defaultTargetPlatform == TargetPlatform.iOS;
  try {
    const key = 'circle.push.first-launch-prompt.v1';
    // On iOS the OS remembers denial/approval. Asking again is a no-op, and
    // checking with the OS also handles Keychain values surviving reinstall.
    if (!apple && await settings.read(key) == 'shown') return;
    await service.initialize();
    await settings.write(key, 'shown');
    await service.permission(request: true);
  } catch (_) {
    // Optional SDK/storage/permission errors never interrupt opening the app.
  }
}
