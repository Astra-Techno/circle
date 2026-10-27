import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

/// Main and Firebase headless engines share the Android plugin's process mutex.
/// No expiring lease: a dead isolate fails closed until process restart rather
/// than allowing concurrent encrypted-store transactions after a timeout.
abstract interface class PushMutex {
  Future<T> run<T>(Future<T> Function() action);
}

class NativePushBridge implements PushMutex {
  const NativePushBridge();
  static const _methods = MethodChannel('circle/push_native');
  static const _events = EventChannel('circle/push_taps');
  Future<void> acknowledge(String id) =>
      _methods.invokeMethod<void>('ack', {'id': id});
  Future<void> bind(String? scope) =>
      _methods.invokeMethod<void>('bind', {'scope': scope ?? ''});
  Future<bool> show({
    required String scope,
    required String event,
    required int expires,
    required Map<String, String> data,
  }) async =>
      await _methods.invokeMethod<bool>('show', {
        'scope': scope,
        'event': event,
        'expires': expires,
        'payload': jsonEncode(data),
      }) ??
      false;
  Stream<Map<String, dynamic>> get opened => _events
      .receiveBroadcastStream()
      .map(_decode)
      .where((data) => data != null)
      .cast<Map<String, dynamic>>();
  Future<Map<String, dynamic>?> initial() async =>
      _decode(await _methods.invokeMethod<String>('initial'));
  static Map<String, dynamic>? _decode(dynamic raw) {
    try {
      if (raw is! String || raw.length > 4096) return null;
      final data = jsonDecode(raw);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<T> run<T>(Future<T> Function() action) async {
    String? lease;
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    do {
      lease = await _methods.invokeMethod<String>('lock');
      if (lease != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    } while (DateTime.now().isBefore(deadline));
    if (lease == null) throw StateError('Notification storage is busy.');
    try {
      return await action();
    } finally {
      await _methods.invokeMethod<void>('unlock', {'lease': lease});
    }
  }
}
