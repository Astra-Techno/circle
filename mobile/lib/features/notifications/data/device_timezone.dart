import 'package:flutter/services.dart';

class DeviceTimezone {
  const DeviceTimezone();
  static const _channel = MethodChannel('circle/notification_preferences');
  Future<String?> read() async {
    try {
      return await _channel.invokeMethod<String>('timezone');
    } catch (_) {
      return null;
    }
  }

  Future<bool> openSettings() async {
    try {
      await _channel.invokeMethod<void>('settings');
      return true;
    } catch (_) {
      return false;
    }
  }
}
