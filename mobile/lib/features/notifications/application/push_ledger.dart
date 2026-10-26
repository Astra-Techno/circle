import 'dart:convert';
import '../../../core/local_settings.dart';
import '../domain/push_envelope.dart';

/// One serialized foreground coordinator owns this ledger. No background
/// isolate may independently present messages until atomic dedup is designed.
class PushLedger {
  PushLedger(this.store, {this.capacity = 512});
  final LocalSettingsStore store;
  final int capacity;
  Future<void> _tail = Future.value();

  Future<bool> claim(PushEnvelope envelope, PushAction action, DateTime now) {
    final result = _tail.then((_) async {
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
    _tail = result.then<void>((_) {});
    return result;
  }

  /// Explicit account-data cleanup only, never an ordinary transport stop.
  Future<void> clear(PushScope scope) {
    final result = _tail.then((_) async {
      try {
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
    _tail = result;
    return result;
  }
}
