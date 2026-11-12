import '../../../core/api/api_json.dart';
import '../../../core/api/scoped_api.dart';
import '../domain/capsule_repository.dart';
import '../domain/capsule.dart';

/// New capsules are shared on the server. Legacy device records remain readable
/// in their original account/server scope; they are never silently uploaded.
class ServerCapsuleRepository implements CapsuleRepository {
  ServerCapsuleRepository({
    required this.scope,
    required this.groups,
    required this.legacy,
  });
  final ScopedApi scope;
  final List<String> groups;
  final CapsuleRepository legacy;
  bool _remote(String id) => id.startsWith('server:');
  String _id(String id) => id.substring('server:'.length);

  Capsule _decode(
    Map<String, Object?> row, {
    List<CapsuleEntry> entries = const [],
  }) => Capsule(
    id: 'server:${ApiJson.id(row['id'])}',
    groupId: ApiJson.id(row['group_id']),
    creatorId: ApiJson.id(row['creator_id']),
    creator: ApiJson.string(row['creator_name']),
    title: ApiJson.string(row['title']),
    message: ApiJson.string(row['message']),
    unlockAt: _date(row['unlock_at']),
    createdAt: _date(row['created_at']),
    sealedAt: row['sealed_at'] == null ? null : _date(row['sealed_at']),
    serverUnlocked: ApiJson.boolean(row['is_unlocked']),
    messageCount: ApiJson.integer(row['entry_count']) ?? 0,
    entries: entries,
    contributors: [
      for (final value in ApiJson.list(row['contributors']))
        CapsuleContributor(
          id: ApiJson.id(ApiJson.map(value)['author_id']),
          name: ApiJson.string(ApiJson.map(value)['display_name']),
          addedMessages:
              ApiJson.integer(ApiJson.map(value)['message_count']) ?? 0,
        ),
    ],
  );
  DateTime _date(Object? value) =>
      DateTime.parse('${ApiJson.string(value).replaceAll(' ', 'T')}Z');

  @override
  Future<List<Capsule>> list() async {
    final result = [...await legacy.list()];
    for (final group in groups) {
      for (var offset = 0; ; offset += 100) {
        final data = await scope.get(
          '/groups/$group/capsules',
          query: {'limit': 100, 'offset': offset},
        );
        result.addAll(
          ApiJson.list(
            data['items'],
          ).map((value) => _decode(ApiJson.map(value))),
        );
        if (!ApiJson.boolean(data['has_more'])) break;
      }
    }
    scope.check();
    return result..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Capsule?> get(String id) async {
    if (!_remote(id)) return legacy.get(id);
    final data = await scope.get('/capsules/${_id(id)}');
    final entries = <CapsuleEntry>[];
    if (ApiJson.boolean(data['is_unlocked'])) {
      for (var offset = 0; ; offset += 100) {
        final page = await scope.get(
          '/capsules/${_id(id)}/entries',
          query: {'limit': 100, 'offset': offset},
        );
        for (final raw in ApiJson.list(page['items'])) {
          final row = ApiJson.map(raw);
          entries.add(
            CapsuleEntry(
              id: ApiJson.id(row['id']),
              authorId: ApiJson.id(row['author_id']),
              author: ApiJson.string(row['author_name']),
              text: ApiJson.string(row['body']),
              addedAt: _date(row['added_at']),
            ),
          );
        }
        if (!ApiJson.boolean(page['has_more'])) break;
      }
    }
    return _decode(data, entries: entries);
  }

  @override
  Future<Capsule> create({
    required String groupId,
    required String title,
    required String message,
    required DateTime unlockAt,
  }) async {
    final data = await scope.change('POST', '/groups/$groupId/capsules', {
      'title': title.trim(),
      'message': message.trim(),
      'unlock_at': unlockAt.toUtc().toIso8601String(),
    });
    return (await get('server:${ApiJson.id(data['id'])}'))!;
  }

  @override
  Future<void> seal(String id) async {
    if (!_remote(id)) return legacy.seal(id);
    await scope.change('POST', '/capsules/${_id(id)}/seal', {});
  }

  @override
  Future<void> delete(String id) async {
    if (!_remote(id)) return legacy.delete(id);
    await scope.remove('/capsules/${_id(id)}');
  }

  @override
  Future<void> addEntry(String capsuleId, String text) async {
    if (!_remote(capsuleId)) return legacy.addEntry(capsuleId, text);
    await scope.change('POST', '/capsules/${_id(capsuleId)}/entries', {
      'body': text.trim(),
    });
  }
}
