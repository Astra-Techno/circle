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
    required this.invitationId,
    required this.expiresAt,
    required this.scope,
  });
  final String eventId, type, memoryId, groupId, commentId, invitationId;
  bool get isInvitation => type == 'group.invitation';
  String get destination =>
      isInvitation ? '/you/invitations' : '/home/memory/$memoryId';
  final int expiresAt;
  final PushScope scope;

  static PushEnvelope? parse(
    Map<String, dynamic> data,
    PushScope scope,
    DateTime now,
  ) {
    final invitation = data['type'] == 'group.invitation';
    final keys = {
      'event_id',
      'type',
      'api_base_url',
      'recipient_id',
      'session_scope',
      'group_id',
      if (invitation) 'invitation_id' else ...['memory_id', 'comment_id'],
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
    final memory = invitation ? '' : data['memory_id'] as String,
        group = data['group_id'] as String,
        comment = invitation ? '' : data['comment_id'] as String,
        invitationId = invitation ? data['invitation_id'] as String : '';
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(event) ||
        (invitation ? !_id(invitationId) : !_id(memory)) ||
        !_id(group)) {
      return null;
    }
    if (!const {
      'memory.created',
      'comment.created',
      'comment.reply',
      'group.invitation',
    }.contains(type)) {
      return null;
    }
    if (!invitation &&
        (type == 'memory.created' ? comment.isNotEmpty : !_id(comment))) {
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
      invitationId: invitationId,
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
    if (isInvitation)
      'invitation_id': invitationId
    else ...{
      'memory_id': memoryId,
      'comment_id': commentId,
    },
    'expires_at': '$expiresAt',
  };

  /// Content is fetched through the active account API, never a payload URL.
  bool authorizes(Map<String, dynamic> data, DateTime now) {
    if (isInvitation) {
      final value = data['invitation'];
      if (value is! Map) return false;
      final expiryText = value['expires_at'];
      if (expiryText is! String) return false;
      final expiry = DateTime.tryParse(
        RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(expiryText)
            ? expiryText
            : '${expiryText.replaceFirst(' ', 'T')}Z',
      );
      return '${value['id']}' == invitationId &&
          '${value['group_id']}' == groupId &&
          '${value['recipient_id']}' == scope.account &&
          value['status'] == 'pending' &&
          expiry != null &&
          expiry.isAfter(now.toUtc());
    }
    if ('${data['id']}' != memoryId || '${data['group_id']}' != groupId) {
      return false;
    }
    final comments = data['comments'];
    return commentId.isEmpty ||
        (comments is List &&
            comments.any(
              (comment) => comment is Map && '${comment['id']}' == commentId,
            ));
  }

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
