import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Local scope derived from the active, previously authenticated token store.
/// Decoding a JWT locally does not authenticate it; all content still uses API authorization.
class PushScope {
  const PushScope({
    required this.server,
    required this.account,
    required this.sessionHash,
  });
  final String server, account, sessionHash;
  String get key => sha256
      .convert(utf8.encode(jsonEncode([server, account, sessionHash])))
      .toString();

  static PushScope? fromAccessToken({
    required String server,
    required String account,
    required String token,
  }) {
    final uri = Uri.tryParse(server);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        server != server.trim() ||
        !uri.path.endsWith('/api/v1') ||
        token.length > 16384 ||
        !_id(account)) {
      return null;
    }
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (claims is! Map ||
          claims['type'] != 'access' ||
          '${claims['sub']}' != account) {
        return null;
      }
      final sid = claims['sid'];
      if (sid is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(sid)) {
        return null;
      }
      return PushScope(
        server: server,
        account: account,
        sessionHash: sha256.convert(utf8.encode(sid)).toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

bool _id(String value) =>
    value.length <= 20 &&
    RegExp(r'^[1-9][0-9]*$').hasMatch(value) &&
    BigInt.parse(value) <= BigInt.parse('18446744073709551615');

enum PushAction { display, open }

class PushEnvelope {
  const PushEnvelope._({
    required this.eventId,
    required this.type,
    required this.memoryId,
    required this.groupId,
    required this.commentId,
    required this.expiresAt,
    required this.scope,
  });
  final String eventId, type, memoryId, groupId, commentId;
  final int expiresAt;
  final PushScope scope;

  static PushEnvelope? parse(
    Map<String, dynamic> data,
    PushScope scope,
    DateTime now,
  ) {
    const keys = {
      'event_id',
      'type',
      'api_base_url',
      'recipient_id',
      'session_scope',
      'group_id',
      'memory_id',
      'comment_id',
      'expires_at',
    };
    if (data.length != keys.length ||
        !keys.every(data.containsKey) ||
        data.values.any((v) => v is! String)) {
      return null;
    }
    if (data['api_base_url'] != scope.server ||
        data['recipient_id'] != scope.account ||
        data['session_scope'] != scope.sessionHash) {
      return null;
    }
    final event = data['event_id'] as String, type = data['type'] as String;
    final memory = data['memory_id'] as String,
        group = data['group_id'] as String,
        comment = data['comment_id'] as String;
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(event) ||
        !_id(memory) ||
        !_id(group)) {
      return null;
    }
    if (!const {
      'memory.created',
      'comment.created',
      'comment.reply',
    }.contains(type)) {
      return null;
    }
    if (type == 'memory.created' ? comment.isNotEmpty : !_id(comment)) {
      return null;
    }
    final expiryText = data['expires_at'] as String;
    if (!RegExp(r'^[0-9]{1,13}$').hasMatch(expiryText)) return null;
    final expiry = int.tryParse(expiryText),
        seconds = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (expiry == null || expiry <= seconds || expiry > seconds + 86700) {
      return null;
    }
    return PushEnvelope._(
      eventId: event,
      type: type,
      memoryId: memory,
      groupId: group,
      commentId: comment,
      expiresAt: expiry,
      scope: scope,
    );
  }

  Map<String, String> toData() => {
    'event_id': eventId,
    'type': type,
    'api_base_url': scope.server,
    'recipient_id': scope.account,
    'session_scope': scope.sessionHash,
    'group_id': groupId,
    'memory_id': memoryId,
    'comment_id': commentId,
    'expires_at': '$expiresAt',
  };

  /// Presentation must recheck this after any asynchronous authorization fetch.
  bool belongsTo(PushScope current, DateTime now) =>
      scope.key == current.key &&
      expiresAt > now.toUtc().millisecondsSinceEpoch ~/ 1000;
}

class PushReception {
  const PushReception(this.envelope, this.action);
  final PushEnvelope envelope;
  final PushAction action;
}
