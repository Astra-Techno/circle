import 'dart:convert';
import '../../../core/local_settings.dart';
import '../../../core/notifications/native_push.dart';
import '../domain/push_envelope.dart';

/// Production Android writers share the native process mutex across engines.
/// Tests may omit it for a single-isolate in-memory store.
class PushLedger {
  PushLedger(this.store, {this.capacity = 512, this.mutex});
  final PushMutex? mutex;
  final LocalSettingsStore store;
  final int capacity;
  Future<void> _tail = Future.value();

  Future<bool> claim(PushEnvelope envelope, PushAction action, DateTime now) {
    return _serialized(() async {
      try {
        const key = 'circle.push.v1.history';
        final raw = await store.read(key);
        final decoded = raw == null ? <String, dynamic>{} : jsonDecode(raw);
        if (decoded is! Map<String, dynamic> ||
            decoded.values.any((v) => v is! int)) {
          return false;
        }
        final seconds = now.toUtc().millisecondsSinceEpoch ~/ 1000;
        final entries = <String, int>{
          for (final entry in decoded.entries)
            if ((entry.value as int) > seconds) entry.key: entry.value as int,
        };
        final id = '${envelope.scope.key}:${action.name}:${envelope.eventId}';
        if (entries.containsKey(id) ||
            entries.length >= capacity ||
            envelope.expiresAt <= seconds) {
          return false;
        }
        entries[id] = envelope.expiresAt;
        await store.write(key, jsonEncode(entries));
        return true;
      } catch (_) {
        return false;
      }
    });
  }

  static const _pendingKey = 'circle.push.v2.pending';
  String _id(PushEnvelope envelope, PushAction action) =>
      '${envelope.scope.key}:${action.name}:${envelope.eventId}';

  Future<Map<String, dynamic>> _read(String key) async {
    final raw = await store.read(key);
    final value = raw == null ? <String, dynamic>{} : jsonDecode(raw);
    if (value is! Map<String, dynamic>) {
      throw StateError('Notification history is unavailable.');
    }
    return value;
  }

  Future<Map<String, dynamic>> _history(DateTime now) async {
    final history = await _read('circle.push.v1.history');
    if (history.values.any((value) => value is! int)) {
      throw StateError('Notification history is unavailable.');
    }
    history.removeWhere(
      (_, value) => value <= now.toUtc().millisecondsSinceEpoch ~/ 1000,
    );
    return history;
  }

  void _prune(Map<String, dynamic> pending, PushScope scope, DateTime now) {
    final seconds = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    pending.removeWhere(
      (key, value) =>
          value is! Map ||
          value['data'] is! Map ||
          (int.tryParse('${value['data']['expires_at']}') ?? 0) <= seconds,
    );
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _tail.then(
      (_) => mutex == null ? action() : mutex!.run(action),
    );
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  /// Persist before emission; no presentation/handled claim is made here.
  Future<bool> stage(PushEnvelope envelope, PushAction action, DateTime now) =>
      _serialized(() async {
        try {
          final history = await _history(now),
              pending = await _read(_pendingKey);
          _prune(pending, envelope.scope, now);
          final id = _id(envelope, action);
          if (history.containsKey(id) ||
              pending.containsKey(id) ||
              pending.length >= 64 ||
              history.length + pending.length >= capacity ||
              !envelope.belongsTo(envelope.scope, now)) {
            return false;
          }
          pending[id] = {'data': envelope.toData(), 'action': action.name};
          await store.write(_pendingKey, jsonEncode(pending));
          return true;
        } catch (_) {
          return false;
        }
      });

  Future<List<PushReception>> pending(PushScope scope, DateTime now) =>
      _serialized(() async {
        try {
          final history = await _history(now),
              pending = await _read(_pendingKey);
          _prune(pending, scope, now);
          final result = <PushReception>[];
          pending.removeWhere((key, value) => history.containsKey(key));
          for (final value in pending.values) {
            final data = Map<String, dynamic>.from(value['data'] as Map);
            final envelope = PushEnvelope.parse(data, scope, now);
            final action = switch (value['action']) {
              'display' => PushAction.display,
              'open' => PushAction.open,
              _ => null,
            };
            if (envelope != null && action != null) {
              result.add(PushReception(envelope, action));
            }
          }
          await store.write(_pendingKey, jsonEncode(pending));
          return result;
        } catch (_) {
          return [];
        }
      });

  Future<bool> recorded(
    PushEnvelope envelope,
    PushAction action,
    DateTime now,
  ) => _serialized(() async {
    final id = _id(envelope, action);
    return (await _history(now)).containsKey(id) ||
        (await _read(_pendingKey)).containsKey(id);
  });

  /// Acknowledge only after a successful handoff or permanent authorization denial.
  Future<bool> complete(
    PushReception reception,
    DateTime now,
  ) => _serialized(() async {
    try {
      final history = await _history(now), pending = await _read(_pendingKey);
      final id = _id(reception.envelope, reception.action);
      if (!history.containsKey(id) && history.length >= capacity) return false;
      history[id] = reception.envelope.expiresAt;
      await store.write('circle.push.v1.history', jsonEncode(history));
      pending.remove(id);
      await store.write(_pendingKey, jsonEncode(pending));
      return true;
    } catch (_) {
      return false;
    }
  });

  /// Explicit account-data cleanup only, never an ordinary transport stop.
  Future<void> clear(PushScope scope) {
    return _serialized(() async {
      try {
        final pending = await _read(_pendingKey);
        pending.removeWhere((key, _) => key.startsWith('${scope.key}:'));
        if (pending.isEmpty) {
          await store.delete(_pendingKey);
        } else {
          await store.write(_pendingKey, jsonEncode(pending));
        }
        const key = 'circle.push.v1.history';
        final raw = await store.read(key);
        if (raw == null) return;
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) return;
        decoded.removeWhere((key, _) => key.startsWith('${scope.key}:'));
        if (decoded.isEmpty) {
          await store.delete(key);
        } else {
          await store.write(key, jsonEncode(decoded));
        }
      } catch (_) {}
    });
  }
}
