import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/local_settings.dart';
import '../domain/capsule.dart';

/// Local-only capsule storage using the project's [LocalSettingsStore].
/// Capsules live on-device until the server API supports them; the domain
/// layer stays the same either way.
class LocalCapsuleRepository {
  LocalCapsuleRepository({required this.viewer, required this.storage});

  final String viewer;
  final LocalSettingsStore storage;
  List<Capsule>? _cache;

  String get _key => 'circle.capsules.v1.$viewer';

  Future<List<Capsule>> list() async {
    if (_cache != null) return _cache!;
    final raw = await readLocalSetting(() => storage.read(_key));
    if (raw == null || raw.isEmpty) {
      _cache = [];
      return _cache!;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _cache =
            decoded
                .whereType<Map<String, Object?>>()
                .map(_decode)
                .whereType<Capsule>()
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        _cache = [];
      }
    } catch (e) {
      debugPrint('Capsule list decode error: $e');
      _cache = [];
    }
    return _cache!;
  }

  Future<Capsule?> get(String id) async {
    final all = await list();
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<Capsule> create({
    required String groupId,
    required String title,
    required String message,
    required DateTime unlockAt,
  }) async {
    final now = DateTime.now();
    final capsule = Capsule(
      id: '${now.millisecondsSinceEpoch}',
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

  Future<void> seal(String id) async {
    final all = await list();
    final index = all.indexWhere((c) => c.id == id);
    if (index < 0) return;
    final c = all[index];
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
      photoCount: c.photoCount,
      messageCount: c.messageCount,
    );
    await _persist();
  }

  Future<void> delete(String id) async {
    final all = await list();
    _cache = all.where((c) => c.id != id).toList();
    await _persist();
  }

  Future<void> addEntry(String capsuleId, String text) async {
    final all = await list();
    final index = all.indexWhere((c) => c.id == capsuleId);
    if (index < 0) return;
    final c = all[index];
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
      contributors: c.contributors,
      photoCount: c.photoCount,
      messageCount: c.messageCount + 1,
    );
    await _persist();
  }

  Future<void> _persist() async {
    final encoded = jsonEncode((_cache ?? []).map(_encode).toList());
    await readLocalSetting(() => storage.write(_key, encoded));
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
  };

  static Capsule? _decode(Map<String, Object?> m) {
    try {
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
      );
    } catch (e) {
      debugPrint('Capsule decode error: $e');
      return null;
    }
  }
}
