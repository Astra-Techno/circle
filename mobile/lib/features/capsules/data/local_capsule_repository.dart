import 'dart:convert';
import '../../../core/local_settings.dart';
import '../../../core/api/api_config.dart';
import '../domain/capsule.dart';
import '../domain/capsule_repository.dart';

/// Local-only capsule storage using the project's [LocalSettingsStore].
/// Capsules live on-device until the server API supports them; the domain
/// layer stays the same either way.
class LocalCapsuleRepository implements CapsuleRepository {
  LocalCapsuleRepository({
    required this.viewer,
    required this.storage,
    this.server = ApiConfig.deployedApi,
  });

  final String viewer;
  final String server;
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  final LocalSettingsStore storage;
  List<Capsule>? _cache;

  String get _key =>
      '${DraftScope(server: server, account: viewer).key}.capsules';

  @override
  Future<List<Capsule>> list() async {
    if (_cache != null) return _cache!;
    var raw = await storage.read(_key);
    // Only the original deployment may adopt pre-scope records. Keep the old
    // key as a recovery copy; never expose it to another server with equal IDs.
    if (raw == null && server == ApiConfig.deployedApi) {
      raw = await storage.read('circle.capsules.v1.$viewer');
      if (raw != null) await storage.write(_key, raw);
    }
    if (raw == null || raw.isEmpty) {
      _cache = [];
      return _cache!;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Capsule storage is not a list.');
    }
    _cache =
        decoded
            .map((item) => _decode(Map<String, Object?>.from(item as Map)))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _cache!;
  }

  @override
  Future<Capsule?> get(String id) async {
    final all = await list();
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<Capsule> create({
    required String groupId,
    required String title,
    required String message,
    required DateTime unlockAt,
  }) => _serial(
    () => _create(
      groupId: groupId,
      title: title,
      message: message,
      unlockAt: unlockAt,
    ),
  );

  Future<Capsule> _create({
    required String groupId,
    required String title,
    required String message,
    required DateTime unlockAt,
  }) async {
    if (!CapsuleRules.checkTitle(title).allowed ||
        !CapsuleRules.checkMessage(message).allowed ||
        !CapsuleRules.checkUnlockDate(unlockAt, DateTime.now()).allowed) {
      throw ArgumentError('Choose a valid title, message and unlock date.');
    }
    final now = DateTime.now();
    final capsule = Capsule(
      id: '${now.microsecondsSinceEpoch}',
      groupId: groupId,
      creatorId: viewer,
      creator: 'You',
      title: title.trim(),
      message: message.trim(),
      unlockAt: unlockAt,
      createdAt: now,
    );
    final all = await list();
    _cache = [capsule, ...all];
    await _persist();
    return capsule;
  }

  @override
  Future<void> seal(String id) => _serial(() => _seal(id));

  Future<void> _seal(String id) async {
    final all = await list();
    final index = all.indexWhere((c) => c.id == id);
    if (index < 0) throw StateError('Capsule not found.');
    final c = all[index];
    if (!CapsuleRules.canManage(c.creatorId, viewer).allowed || !c.isOpen) {
      throw StateError('This capsule cannot be sealed.');
    }
    _cache = [...all];
    _cache![index] = Capsule(
      id: c.id,
      groupId: c.groupId,
      creatorId: c.creatorId,
      creator: c.creator,
      title: c.title,
      message: c.message,
      unlockAt: c.unlockAt,
      createdAt: c.createdAt,
      sealedAt: DateTime.now(),
      contributors: c.contributors,
      entries: c.entries,
      photoCount: c.photoCount,
      messageCount: c.messageCount,
    );
    await _persist();
  }

  @override
  Future<void> delete(String id) => _serial(() => _delete(id));

  Future<void> _delete(String id) async {
    final all = await list();
    final c = await get(id);
    if (c == null || !CapsuleRules.canManage(c.creatorId, viewer).allowed) {
      throw StateError('This capsule cannot be deleted.');
    }
    _cache = all.where((c) => c.id != id).toList();
    await _persist();
  }

  @override
  Future<void> addEntry(String capsuleId, String text) =>
      _serial(() => _addEntry(capsuleId, text));

  Future<void> _addEntry(String capsuleId, String text) async {
    final all = await list();
    final index = all.indexWhere((c) => c.id == capsuleId);
    if (index < 0) throw StateError('Capsule not found.');
    final c = all[index];
    final body = text.trim();
    if (!c.isOpen) {
      throw StateError('This capsule is closed for contributions.');
    }
    if (body.isEmpty || !CapsuleRules.checkMessage(body).allowed) {
      throw ArgumentError('Write a message of up to 500 characters.');
    }
    if (c.messageCount >= CapsuleRules.maxEntriesPerCapsule) {
      throw StateError('This capsule has reached its contribution limit.');
    }
    final now = DateTime.now();
    _cache = [...all];
    _cache![index] = Capsule(
      id: c.id,
      groupId: c.groupId,
      creatorId: c.creatorId,
      creator: c.creator,
      title: c.title,
      message: c.message,
      unlockAt: c.unlockAt,
      createdAt: c.createdAt,
      sealedAt: c.sealedAt,
      contributors: [
        for (final contributor in c.contributors)
          if (contributor.id != viewer) contributor,
        CapsuleContributor(
          id: viewer,
          name: 'You',
          addedMessages:
              c.entries.where((e) => e.authorId == viewer).length + 1,
        ),
      ],
      entries: [
        ...c.entries,
        CapsuleEntry(
          id: '${now.microsecondsSinceEpoch}',
          authorId: viewer,
          author: 'You',
          text: body,
          addedAt: now,
        ),
      ],
      photoCount: c.photoCount,
      messageCount: c.messageCount + 1,
    );
    await _persist();
  }

  Future<void> _persist() async {
    final encoded = jsonEncode((_cache ?? []).map(_encode).toList());
    try {
      await storage.write(_key, encoded);
    } catch (_) {
      _cache = null;
      rethrow;
    }
  }

  static Map<String, Object?> _encode(Capsule c) => {
    'id': c.id,
    'groupId': c.groupId,
    'creatorId': c.creatorId,
    'creator': c.creator,
    'title': c.title,
    'message': c.message,
    'unlockAt': c.unlockAt.toIso8601String(),
    'createdAt': c.createdAt.toIso8601String(),
    if (c.sealedAt != null) 'sealedAt': c.sealedAt!.toIso8601String(),
    'photoCount': c.photoCount,
    'messageCount': c.messageCount,
    'contributors': [
      for (final p in c.contributors)
        {
          'id': p.id,
          'name': p.name,
          'addedPhotos': p.addedPhotos,
          'addedMessages': p.addedMessages,
        },
    ],
    'entries': [
      for (final e in c.entries)
        {
          'id': e.id,
          'authorId': e.authorId,
          'author': e.author,
          'text': e.text,
          'photoIds': e.photoIds,
          'addedAt': e.addedAt.toIso8601String(),
        },
    ],
  };

  static Capsule _decode(Map<String, Object?> m) {
    return Capsule(
      id: m['id'] as String,
      groupId: m['groupId'] as String,
      creatorId: m['creatorId'] as String,
      creator: m['creator'] as String,
      title: m['title'] as String,
      message: (m['message'] as String?) ?? '',
      unlockAt: DateTime.parse(m['unlockAt'] as String),
      createdAt: DateTime.parse(m['createdAt'] as String),
      sealedAt: m['sealedAt'] != null
          ? DateTime.parse(m['sealedAt'] as String)
          : null,
      photoCount: (m['photoCount'] as num?)?.toInt() ?? 0,
      messageCount: (m['messageCount'] as num?)?.toInt() ?? 0,
      contributors: [
        for (final p in (m['contributors'] as List? ?? const []))
          CapsuleContributor(
            id: p['id'] as String,
            name: p['name'] as String,
            addedPhotos: (p['addedPhotos'] as num).toInt(),
            addedMessages: (p['addedMessages'] as num).toInt(),
          ),
      ],
      entries: [
        for (final raw in (m['entries'] as List? ?? const []))
          CapsuleEntry(
            id: raw['id'] as String,
            authorId: raw['authorId'] as String,
            author: raw['author'] as String,
            text: raw['text'] as String,
            photoIds: List<String>.from(raw['photoIds'] as List? ?? const []),
            addedAt: DateTime.parse(raw['addedAt'] as String),
          ),
      ],
    );
  }
}
