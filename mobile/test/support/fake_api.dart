import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

/// One request as the fake server saw it.
class FakeRequest {
  FakeRequest(this.method, this.uri, this.headers, this.bytes);
  final String method;
  final Uri uri;
  final Map<String, Object?> headers;
  final Uint8List bytes;

  /// The path below `/api/v1`, e.g. `/groups/1`.
  String get path {
    final full = uri.path;
    const base = '/api/v1';
    return full.startsWith(base) ? full.substring(base.length) : full;
  }

  Map<String, String> get query => uri.queryParameters;

  String? get bearer {
    final value = headers['authorization'] ?? headers['Authorization'];
    final text = value is List ? value.first.toString() : value?.toString();
    return text != null && text.startsWith('Bearer ')
        ? text.substring(7)
        : null;
  }

  Map<String, Object?> get json {
    if (bytes.isEmpty) return const {};
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      return decoded is Map ? Map<String, Object?>.from(decoded) : const {};
    } on FormatException {
      // Raw bytes (photo uploads) aren't JSON.
      return const {};
    }
  }

  @override
  String toString() => '$method $path';
}

/// What the fake answers. [network] simulates a failure without a response.
class FakeResponse {
  const FakeResponse(this.status, [this.body, this.headers = const {}])
    : network = null;
  const FakeResponse.network(DioExceptionType this.network)
    : status = 0,
      body = null,
      headers = const {};

  final int status;
  final Object? body;
  final Map<String, String> headers;
  final DioExceptionType? network;

  static FakeResponse ok(Object? data, {int status = 200}) =>
      FakeResponse(status, {'success': true, 'message': 'OK', 'data': data});

  static FakeResponse page(List<Object?> items, Map<String, Object?> page) =>
      FakeResponse(200, {'success': true, 'data': items, 'pagination': page});

  static FakeResponse error(
    int status,
    String code, {
    String message = 'Raw server text that must never be shown.',
    Map<String, Object?>? details,
    Map<String, String> headers = const {},
  }) => FakeResponse(status, {
    'success': false,
    'error': {'code': code, 'message': message, 'details': ?details},
  }, headers);
}

typedef FakeHandler = FutureOr<FakeResponse> Function(FakeRequest request);

/// A Dio adapter that never touches the network: every request goes to
/// [handler]. Requests are recorded in order.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);
  FakeHandler handler;
  final List<FakeRequest> requests = [];

  int count(String method, String path) => requests
      .where((request) => request.method == method && request.path == path)
      .length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final chunks = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        chunks.addAll(chunk);
      }
    }
    final request = FakeRequest(options.method, options.uri, {
      for (final entry in options.headers.entries)
        entry.key.toLowerCase(): entry.value,
    }, Uint8List.fromList(chunks));
    requests.add(request);
    final response = await handler(request);
    if (response.network != null) {
      throw DioException(requestOptions: options, type: response.network!);
    }
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(response.body)),
      response.status,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
        for (final entry in response.headers.entries)
          entry.key.toLowerCase(): [entry.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A small in-memory CIRCLE API (contract 0.3.1 shapes) for tests: real
/// tokens with single-use refresh rotation, groups with members, invite
/// links, join requests, Memories with comments/reactions/saves, cursor
/// pages and the media upload pipeline.
class FakeCircleServer {
  FakeCircleServer({this.mediaAvailable = false, this.pageSize = 20}) {
    adapter = FakeHttpAdapter(handle);
  }

  late final FakeHttpAdapter adapter;

  /// False answers upload requests with `503 server_error` (no GD).
  bool mediaAvailable;
  final int pageSize;

  final Map<int, Map<String, Object?>> users = {};
  final Map<String, String> passwords = {};
  final Map<String, int> access = {}, refresh = {};
  final Set<String> expired = {};
  final Map<int, Map<String, Object?>> groups = {};
  final Map<int, Map<int, String>> members = {};
  final List<Map<String, Object?>> memories = [];
  final Map<int, List<Map<String, Object?>>> comments = {};
  final Map<int, Map<int, String>> reactions = {};
  final Map<int, Set<int>> saves = {};
  final Map<int, List<Map<String, Object?>>> joinRequests = {};
  final Map<String, Map<String, Object?>> links = {};
  final Map<String, Map<String, Object?>> uploads = {};
  int _ids = 0, _tokens = 0;

  static const now = '2026-10-23 10:00:00';

  int _next() => ++_ids;

  /// Adds an account directly (as if registered earlier).
  int addUser(String mobile, String password, String name) {
    final id = _next();
    users[id] = {'id': id, 'mobile': mobile, 'display_name': name};
    passwords[mobile] = password;
    return id;
  }

  /// Makes every current access token look expired (`401 invalid_token`).
  void expireAccessTokens() => expired.addAll(access.keys);

  Map<String, Object?> _pair(int user) {
    final a = 'access-${++_tokens}', r = 'refresh-$_tokens';
    access[a] = user;
    refresh[r] = user;
    return {
      'access_token': a,
      'refresh_token': r,
      'token_type': 'Bearer',
      'expires_in': 3600,
    };
  }

  Map<String, Object?> groupJson(int id, {int? viewer}) => {
    ...groups[id]!,
    if (viewer != null)
      'role': members[id]![viewer] == 'member' ? 'member' : 'admin',
  };

  /// Seeds a group owned by [owner].
  int addGroup(String name, int owner, {int? parent, String type = 'family'}) {
    final id = _next();
    groups[id] = {
      'id': id,
      'parent_id': parent,
      'root_id': parent == null ? id : groups[parent]!['root_id'],
      'depth': parent == null ? 1 : (groups[parent]!['depth'] as int) + 1,
      'type': type,
      'name': name,
      'description': '',
      'visibility': 'listed',
      'approval_mode': 'manual',
      'link_sharing': 'admins',
      'event_creation': 'members',
      'owner_user_id': owner,
      'created_at': now,
    };
    members[id] = {owner: 'admin'};
    return id;
  }

  int addMemory(int group, int author, String body, {String? created}) {
    final id = _next();
    memories.insert(0, {
      'id': id,
      'group_id': group,
      'author_id': author,
      'body': body,
      'memory_date': null,
      'place': null,
      'created_at': created ?? now,
      'updated_at': created ?? now,
      'author_name': users[author]!['display_name'],
      'author_avatar': null,
      'group_name': groups[group]!['name'],
      'group_type': groups[group]!['type'],
      'media': <Object?>[],
    });
    return id;
  }

  Map<String, Object?> _listItem(Map<String, Object?> memory, int viewer) {
    final id = memory['id'] as int;
    return {
      ...memory,
      'reaction_count': reactions[id]?.length ?? 0,
      'comment_count': comments[id]?.length ?? 0,
      'user_reacted': reactions[id]?.containsKey(viewer) ?? false ? 1 : 0,
      'user_saved': saves[id]?.contains(viewer) ?? false,
    };
  }

  FutureOr<FakeResponse> handle(FakeRequest r) {
    final path = r.path;
    final body = r.json;
    // Public endpoints.
    if (r.method == 'POST' && path == '/auth/register') {
      final mobile = body['mobile'] as String;
      if ((body['password'] as String).runes.length < 15) {
        return FakeResponse.error(
          422,
          'validation_error',
          message: 'Password must be 15–128 characters.',
        );
      }
      if (!passwords.containsKey(mobile)) {
        addUser(
          mobile,
          body['password'] as String,
          (body['display_name'] as String?) ?? '',
        );
      }
      return FakeResponse.ok({'next': 'login'}, status: 202);
    }
    if (r.method == 'POST' && path == '/auth/login') {
      final mobile = body['mobile'] as String;
      if (passwords[mobile] != body['password']) {
        return FakeResponse.error(401, 'invalid_credentials');
      }
      final user = users.values.firstWhere((u) => u['mobile'] == mobile);
      return FakeResponse.ok({..._pair(user['id'] as int), 'user': user});
    }
    if (r.method == 'POST' && path == '/auth/refresh') {
      final user = refresh.remove(body['refresh_token']);
      if (user == null) return FakeResponse.error(401, 'invalid_token');
      return FakeResponse.ok(_pair(user));
    }
    final invite = RegExp(r'^/invites/([A-Za-z0-9_-]+)$').firstMatch(path);
    if (r.method == 'GET' && invite != null) {
      final link = links[invite[1]];
      if (link == null) return FakeResponse.error(404, 'not_found');
      if (link['revoked'] == true) {
        return FakeResponse.error(410, 'link_revoked');
      }
      final group = groups[link['group_id']]!;
      return FakeResponse.ok({
        'group_name': group['name'],
        'group_type': group['type'],
        'cover_path': null,
        'is_subgroup': group['parent_id'] != null,
        'approval_required': group['approval_mode'] == 'manual',
        'member_count': members[group['id']]!.length,
      });
    }
    // Authenticated endpoints.
    final token = r.bearer;
    if (token == null) return FakeResponse.error(401, 'unauthorized');
    if (expired.contains(token) || !access.containsKey(token)) {
      return FakeResponse.error(401, 'invalid_token');
    }
    final me = access[token]!;
    final join = RegExp(r'^/invites/([A-Za-z0-9_-]+)/join$').firstMatch(path);
    if (r.method == 'POST' && join != null) {
      final link = links[join[1]];
      if (link == null) return FakeResponse.error(404, 'not_found');
      if (link['revoked'] == true) {
        return FakeResponse.error(410, 'link_revoked');
      }
      final id = link['group_id'] as int;
      if (members[id]!.containsKey(me)) {
        return FakeResponse.error(409, 'already_member');
      }
      link['uses'] = (link['uses'] as int) + 1;
      if (groups[id]!['approval_mode'] == 'manual') {
        joinRequests.putIfAbsent(id, () => []).add({
          'id': _next(),
          'user_id': me,
          'status': 'pending',
          'message': '',
          'created_at': now,
          'display_name': users[me]!['display_name'],
          'avatar_path': null,
        });
        return FakeResponse.ok({'status': 'pending_approval', 'group_id': id});
      }
      members[id]![me] = 'member';
      return FakeResponse.ok({'status': 'joined', 'group_id': id});
    }
    if (r.method == 'POST' && path == '/auth/logout') {
      access.removeWhere((_, user) => user == me);
      refresh.removeWhere((_, user) => user == me);
      return FakeResponse.ok(null);
    }
    if (path == '/me') {
      return FakeResponse.ok({
        ...users[me]!,
        'about': '',
        'avatar_path': null,
        'created_at': now,
      });
    }
    if (path == '/groups' && r.method == 'GET') {
      return FakeResponse.ok([
        for (final id in groups.keys)
          if (members[id]!.containsKey(me))
            {
              ...groupJson(id, viewer: me)
                ..remove('link_sharing')
                ..remove('event_creation'),
            },
      ]);
    }
    if (path == '/groups' && r.method == 'POST') {
      final parent = body['parent_id'] as int?;
      if (parent != null && !(members[parent]?.containsKey(me) ?? false)) {
        return FakeResponse.error(403, 'not_member');
      }
      final id = addGroup(
        body['name'] as String,
        me,
        parent: parent,
        type: body['type'] as String? ?? 'other',
      );
      groups[id]!['approval_mode'] = body['approval_mode'] ?? 'auto';
      groups[id]!['visibility'] = body['visibility'] ?? 'listed';
      return FakeResponse.ok(groups[id], status: 201);
    }
    final group = RegExp(r'^/groups/(\d+)(/.*)?$').firstMatch(path);
    if (group != null) {
      final id = int.parse(group[1]!);
      final rest = group[2] ?? '';
      if (!(members[id]?.containsKey(me) ?? false)) {
        return FakeResponse.error(403, 'not_member');
      }
      final admin = members[id]![me] == 'admin';
      switch ((r.method, rest)) {
        case ('GET', ''):
          return FakeResponse.ok({
            ...groups[id]!,
            'my_role': members[id]![me],
            'member_count': members[id]!.length,
            'ancestors': <Object?>[],
          });
        case ('PATCH', ''):
          if (!admin) return FakeResponse.error(403, 'forbidden');
          groups[id]!.addAll(body);
          return FakeResponse.ok(groups[id]);
        case ('GET', '/members'):
          final all = [
            for (final entry in members[id]!.entries)
              {
                'id': entry.key,
                'display_name': users[entry.key]!['display_name'],
                'about': '',
                'avatar_path': null,
                'role': entry.value,
                'joined_at': now,
                'is_owner': groups[id]!['owner_user_id'] == entry.key,
              },
          ];
          return FakeResponse.page(all, {
            'total': all.length,
            'limit': 100,
            'offset': 0,
          });
        case ('GET', '/join-requests'):
          if (!admin) return FakeResponse.error(403, 'forbidden');
          return FakeResponse.ok(joinRequests[id] ?? const []);
        case ('POST', '/leave'):
          members[id]!.remove(me);
          return FakeResponse.ok({
            'left_groups': [
              {'group_id': id},
            ],
          });
        case ('POST', '/invite-links'):
          final linkId = _next();
          final value = 'TokenCaseSensitive${linkId}abcdefXYZ';
          links[value] = {'id': linkId, 'group_id': id, 'uses': 0};
          return FakeResponse.ok({
            'id': linkId,
            'token': value,
            'expires_at': '2026-10-30 10:00:00',
            'max_uses': body['max_uses'],
            'link': '/i/$value',
          }, status: 201);
        case ('GET', '/invite-links'):
          return FakeResponse.ok([
            for (final link in links.values)
              if (link['group_id'] == id)
                {
                  'id': link['id'],
                  'created_by': me,
                  'created_by_name': 'x',
                  'created_at': now,
                  'expires_at': '2026-10-30 10:00:00',
                  'max_uses': null,
                  'use_count': link['uses'],
                  'revoked_at': null,
                  'status': link['revoked'] == true ? 'revoked' : 'active',
                },
          ]);
        case ('POST', '/memories'):
          final ids = (body['media_ids'] as List?)?.cast<String>() ?? const [];
          final text = (body['body'] as String?) ?? '';
          if (text.isEmpty && ids.isEmpty) {
            return FakeResponse.error(
              422,
              'validation_error',
              message: 'Write 1–2000 characters.',
            );
          }
          final memory = addMemory(
            id,
            me,
            text,
            created: '2026-10-23 10:05:00',
          );
          final json = memories.firstWhere((m) => m['id'] == memory);
          json['memory_date'] = body['memory_date'];
          json['place'] = body['place'];
          json['media'] = [
            for (final mediaId in ids)
              {'id': mediaId, 'width': 800, 'height': 600},
          ];
          return FakeResponse.ok(json, status: 201);
        case ('POST', '/media/uploads'):
          if (!mediaAvailable) {
            return FakeResponse.error(
              503,
              'server_error',
              message: 'Photo uploads are temporarily unavailable.',
            );
          }
          if (body['mime_type'] == 'image/heic') {
            return FakeResponse.error(415, 'media_type_not_allowed');
          }
          final key = body['client_upload_id'] as String;
          final existing = uploads[key];
          final uploadId =
              existing?['upload_id'] as String? ??
              'a1b2c3d4-0000-4000-8000-${(_next()).toString().padLeft(12, '0')}';
          uploads[key] = {
            'upload_id': uploadId,
            'size': body['byte_size'],
            'group': id,
          };
          return FakeResponse.ok({
            'upload_id': uploadId,
            'upload_path': '/media/uploads/$uploadId/content',
            'expires_at': '2026-10-23 10:15:00',
            'max_bytes': body['byte_size'],
          }, status: 201);
      }
    }
    final content = RegExp(
      r'^/media/uploads/([a-f0-9-]+)/content$',
    ).firstMatch(path);
    if (r.method == 'PUT' && content != null) {
      final upload = uploads.values.firstWhere(
        (u) => u['upload_id'] == content[1],
      );
      if (r.bytes.length != upload['size']) {
        return FakeResponse.error(422, 'media_invalid');
      }
      return FakeResponse.ok({
        'id': content[1],
        'group_id': upload['group'],
        'uploader_id': me,
        'kind': 'image',
        'mime_type': 'image/webp',
        'width': 800,
        'height': 600,
        'byte_size': 1234,
        'status': 'ready',
        'sizes': ['thumb', 'medium', 'full'],
        'created_at': now,
      });
    }
    final media = RegExp(r'^/media/([a-f0-9-]+)$').firstMatch(path);
    if (media != null && r.method == 'GET') {
      final size = r.query['size'] ?? 'medium';
      return FakeResponse.ok({
        'url':
            '/media/files/${media[1]}/$size?expires=1792758951&sig=${'a' * 64}',
        'expires_at': '2026-10-23 10:05:00',
        'width': 320,
        'height': 240,
        'mime_type': 'image/webp',
      });
    }
    if (media != null && r.method == 'DELETE') return FakeResponse.ok(null);
    if (path == '/memories' && r.method == 'GET') {
      final mine = [
        for (final memory in memories)
          if (members[memory['group_id']]?.containsKey(me) ?? false) memory,
      ];
      final start = int.tryParse(r.query['cursor'] ?? '') ?? 0;
      final end = (start + pageSize).clamp(0, mine.length);
      final more = end < mine.length;
      return FakeResponse.page(
        [for (final memory in mine.sublist(start, end)) _listItem(memory, me)],
        {
          'next_cursor': more ? '$end' : null,
          'has_more': more,
          'limit': pageSize,
        },
      );
    }
    final memory = RegExp(r'^/memories/(\d+)(/.*)?$').firstMatch(path);
    if (memory != null) {
      final id = int.parse(memory[1]!);
      final json = memories.where((m) => m['id'] == id).firstOrNull;
      if (json == null ||
          !(members[json['group_id']]?.containsKey(me) ?? false)) {
        return FakeResponse.error(404, 'not_found');
      }
      switch ((r.method, memory[2] ?? '')) {
        case ('GET', ''):
          return FakeResponse.ok({
            ...json,
            'comments': comments[id] ?? const [],
            'reactions': [
              for (final entry
                  in (reactions[id] ?? const <int, String>{}).entries)
                {
                  'user_id': entry.key,
                  'emoji': entry.value,
                  'display_name': users[entry.key]!['display_name'],
                },
            ],
          });
        case ('PATCH', ''):
          json['body'] = body['body'];
          json['updated_at'] = '2026-10-23 11:00:00';
          return FakeResponse.ok(json);
        case ('DELETE', ''):
          memories.remove(json);
          return FakeResponse.ok(null);
        case ('POST', '/reactions'):
          final map = reactions.putIfAbsent(id, () => {});
          final emoji = body['emoji'] as String;
          if (map[me] == emoji) {
            map.remove(me);
            return FakeResponse.ok({'reacted': false, 'emoji': null});
          }
          map[me] = emoji;
          return FakeResponse.ok({'reacted': true, 'emoji': emoji});
        case ('POST', '/save'):
          final set = saves.putIfAbsent(id, () => {});
          final saved = set.add(me) || !set.remove(me);
          return FakeResponse.ok({'saved': saved});
        case ('POST', '/comments'):
          final comment = {
            'id': _next(),
            'parent_id': body['parent_id'],
            'author_id': me,
            'body': body['body'],
            'created_at': now,
            'author_name': users[me]!['display_name'],
            'author_avatar': null,
          };
          comments.putIfAbsent(id, () => []).add(comment);
          return FakeResponse.ok(comment, status: 201);
      }
    }
    return FakeResponse.error(404, 'not_found');
  }
}
