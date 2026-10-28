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
    this.messageId = '',
    this.conversationId = '',
    this.eventRef = '',
    this.eventVersion = '',
  });
  final String eventId, type, memoryId, groupId, commentId, invitationId;
  final String messageId, conversationId, eventRef, eventVersion;
  bool get isChat => type == 'chat.message';
  bool get isEvent => type.startsWith('event.');
  bool get isInvitation => type == 'group.invitation';
  bool get isReport => type == 'group.report';
  String get authorizationPath => isChat
      ? '/chats/$conversationId/messages/$messageId'
      : isEvent
      ? '/events/$eventRef'
      : isReport
      ? '/groups/$groupId/reports'
      : isInvitation
      ? '/group-invitations/$invitationId'
      : '/memories/$memoryId';
  String get destination => isChat
      ? '/chats/c/$conversationId'
      : isEvent
      ? '/events/e/$eventRef'
      : isReport
      ? '/groups/g/$groupId/reports'
      : isInvitation
      ? '/you/invitations'
      : '/home/memory/$memoryId';
  final int expiresAt;
  final PushScope scope;

  static PushEnvelope? parse(
    Map<String, dynamic> data,
    PushScope scope,
    DateTime now,
  ) {
    final invitation = data['type'] == 'group.invitation';
    final report = data['type'] == 'group.report';
    final chat = data['type'] == 'chat.message',
        event =
            (data['type'] is String) &&
            (data['type'] as String).startsWith('event.');
    final groupEvent = invitation || report || chat || event;
    final keys = {
      'event_id',
      'type',
      'api_base_url',
      'recipient_id',
      'session_scope',
      'group_id',
      if (invitation)
        'invitation_id'
      else if (chat) ...[
        'conversation_id',
        'message_id',
      ] else if (event) ...[
        'event_ref',
        'event_version',
      ] else if (!report) ...[
        'memory_id',
        'comment_id',
      ],
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
    final eventKey = data['event_id'] as String, type = data['type'] as String;
    final memory = groupEvent ? '' : data['memory_id'] as String,
        group = data['group_id'] as String,
        comment = groupEvent ? '' : data['comment_id'] as String,
        invitationId = invitation ? data['invitation_id'] as String : '';
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(eventKey) ||
        (chat
            ? (!_id(data['conversation_id'] as String) ||
                  !_id(data['message_id'] as String))
            : event
            ? (!_id(data['event_ref'] as String) ||
                  !_id(data['event_version'] as String))
            : invitation
            ? !_id(invitationId)
            : !report && !_id(memory)) ||
        !_id(group)) {
      return null;
    }
    if (!const {
      'memory.created',
      'comment.created',
      'comment.reply',
      'group.invitation',
      'group.report',
      'chat.message',
      'event.created',
      'event.updated',
      'event.cancelled',
      'event.rsvp',
      'event.reminder',
    }.contains(type)) {
      return null;
    }
    if (!groupEvent &&
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
      eventId: eventKey,
      type: type,
      memoryId: memory,
      groupId: group,
      commentId: comment,
      invitationId: invitationId,
      expiresAt: expiry,
      scope: scope,
      messageId: chat ? data['message_id'] as String : '',
      conversationId: chat ? data['conversation_id'] as String : '',
      eventRef: event ? data['event_ref'] as String : '',
      eventVersion: event ? data['event_version'] as String : '',
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
    else if (isChat) ...{
      'conversation_id': conversationId,
      'message_id': messageId,
    } else if (isEvent) ...{
      'event_ref': eventRef,
      'event_version': eventVersion,
    } else if (!isReport) ...{
      'memory_id': memoryId,
      'comment_id': commentId,
    },
    'expires_at': '$expiresAt',
  };

  /// Content is fetched through the active account API, never a payload URL.
  bool authorizes(Map<String, dynamic> data, DateTime now) {
    if (isChat) {
      return '${data['id']}' == messageId &&
          '${data['conversation_id']}' == conversationId &&
          data['notification_allowed'] == true;
    }
    if (isEvent) {
      final start = DateTime.tryParse(data['start_at'] as String? ?? '');
      return '${data['id']}' == eventRef &&
          '${data['group_id']}' == groupId &&
          '${data['version']}' == eventVersion &&
          (type == 'event.cancelled'
              ? data['status'] == 'cancelled'
              : data['status'] == 'active') &&
          (type != 'event.reminder' ||
              (start != null && start.isAfter(now.toUtc())));
    }
    if (isReport) {
      return '${data['group_id']}' == groupId &&
          data['items'] is List &&
          (data['items'] as List).isNotEmpty;
    }
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
