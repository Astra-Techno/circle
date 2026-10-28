import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../core/api/scoped_api.dart';
import '../../../core/api/api_error.dart';
import '../../../core/local_settings.dart';

/// Encrypted device-local send intents, isolated by server/account/JWT session.
/// The application never stores tokens in an outbox key or message record.
class ChatOutbox {
  ChatOutbox(this.scope, this.store, {this.testSession});
  final ScopedApi scope;
  final LocalSettingsStore store;
  final String? testSession;
  String? _key;
  Future<void> _tail = Future.value();
  Future<T> _serial<T>(Future<T> Function() work) {
    final task = _tail.then((_) => work());
    _tail = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  Future<String> _storageKey() async {
    scope.check();
    if (_key != null) return _key!;
    var session = testSession;
    if (session == null) {
      final tokens = await scope.api.currentTokens();
      scope.check();
      try {
        final payload = jsonDecode(
          utf8.decode(
            base64Url.decode(
              base64Url.normalize(tokens!.accessToken.split('.')[1]),
            ),
          ),
        );
        final sid = payload['sid'];
        if (sid is String && RegExp(r'^[a-f0-9]{32}$').hasMatch(sid)) {
          session = sid;
        }
      } catch (_) {
        /* Non-JWT test sessions use a non-secret revision scope. */
      }
      session ??= 'local-${scope.session}';
    }
    return _key =
        'circle.chat.outbox.v1.${sha256.convert(utf8.encode(jsonEncode([scope.api.config.baseUrl.toString(), scope.account, session])))}';
  }

  Future<List<Map<String, Object?>>> _read() async {
    final key = await _storageKey();
    final raw = await store.read(key);
    scope.check();
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.length > 50) {
      throw const ApiError(
        'Pending messages could not be read.',
        code: 'outbox_error',
      );
    }
    return decoded.map((v) => Map<String, Object?>.from(v as Map)).toList();
  }

  Future<void> _write(List<Map<String, Object?>> rows) async {
    scope.check();
    final key = await _storageKey();
    if (rows.isEmpty) {
      await store.delete(key);
    } else {
      await store.write(key, jsonEncode(rows));
    }
    scope.check();
  }

  Future<List<Map<String, Object?>>> pending() => _serial(_read);
  Future<void> send(
    String chat,
    Map<String, Object?> body,
    Future<void> Function(String, Map<String, Object?>) deliver,
  ) => _serial(() async {
    final rows = await _read(), key = body['client_id'];
    if (!rows.any((r) => (r['body'] as Map)['client_id'] == key)) {
      if (rows.length >= 50) {
        throw const ApiError(
          'Review your pending messages before sending more.',
          code: 'outbox_full',
        );
      }
      rows.add({'chat': chat, 'body': body, 'failed': false});
      await _write(rows);
    }
    try {
      await deliver(chat, body);
      rows.removeWhere((r) => (r['body'] as Map)['client_id'] == key);
      await _write(rows);
    } on ApiError catch (error) {
      if (!_transient(error)) {
        for (final r in rows) {
          if ((r['body'] as Map)['client_id'] == key) r['failed'] = true;
        }
        await _write(rows);
      }
      rethrow;
    }
  });
  bool _transient(ApiError error) =>
      error.status == null || (error.status ?? 0) >= 500 || error.status == 429;
  Future<void> flush(
    Future<void> Function(String, Map<String, Object?>) deliver,
  ) => _serial(() async {
    final rows = await _read();
    var changed = false;
    for (final row in List<Map<String, Object?>>.of(rows).take(5)) {
      if (row['failed'] == true) continue;
      try {
        scope.check();
        await deliver(
          row['chat'] as String,
          Map<String, Object?>.from(row['body'] as Map),
        );
        rows.remove(row);
        changed = true;
      } on ApiError catch (error) {
        if (!_transient(error)) {
          row['failed'] = true;
          changed = true;
        } else {
          break;
        }
      }
    }
    if (changed) await _write(rows);
  });
  Future<void> discard(String key) => _serial(() async {
    final rows = await _read();
    rows.removeWhere((r) => (r['body'] as Map)['client_id'] == key);
    await _write(rows);
  });
  Future<void> retry(String key) => _serial(() async {
    final rows = await _read();
    for (final r in rows) {
      if ((r['body'] as Map)['client_id'] == key) r['failed'] = false;
    }
    await _write(rows);
  });
  Future<void> dispose() async {
    final key = _key;
    if (key == null) return;
    await _tail;
    if (scope.api.sessionRevision != scope.session) await store.delete(key);
  }
}
