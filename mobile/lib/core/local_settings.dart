import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local settings and text drafts only. Session tokens use their own store.
abstract interface class LocalSettingsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureLocalSettingsStore implements LocalSettingsStore {
  SecureLocalSettingsStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Tests can keep one instance across containers to simulate an app restart.
class MemoryLocalSettingsStore implements LocalSettingsStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

final localSettingsStoreProvider = Provider<LocalSettingsStore>(
  (ref) => SecureLocalSettingsStore(),
);

/// Storage errors are recoverable; callers must not claim a save succeeded.
Future<T?> readLocalSetting<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  } on Exception {
    return null;
  }
}

/// A private draft belongs to one authenticated account on one exact server.
class DraftScope {
  const DraftScope({required this.server, required this.account});
  final String server, account;
  String get key =>
      'circle.local.drafts.v1.${sha256.convert(utf8.encode(jsonEncode([server, account])))}';
}

class DraftLease {
  const DraftLease._(this.scope, this.revision);
  final DraftScope scope;
  final int revision;
}

class MemoryTextDraft {
  const MemoryTextDraft({
    required this.text,
    this.groupId,
    this.year = '',
    this.place = '',
  });
  final String text, year, place;
  final String? groupId;
  bool get isEmpty => text.isEmpty && year.isEmpty && place.isEmpty;
  String get audienceKey => groupId ?? '';
  Map<String, Object?> get json => {
    'text': text,
    'group': groupId,
    'year': year,
    'place': place,
  };
  static MemoryTextDraft? decode(Object? value) {
    if (value is! Map ||
        value['text'] is! String ||
        (value['group'] != null && value['group'] is! String)) {
      return null;
    }
    final text = value['text'] as String;
    final year = value['year'] is String ? value['year'] as String : '';
    final place = value['place'] is String ? value['place'] as String : '';
    // Bound data read from an old/corrupted local record.
    if (text.length > 10000 || year.length > 4 || place.length > 2000) {
      return null;
    }
    return MemoryTextDraft(
      text: text,
      groupId: value['group'] as String?,
      year: year,
      place: place,
    );
  }
}

final memoryDraftStoreProvider = Provider<MemoryDraftStore>(
  (ref) => MemoryDraftStore(ref.watch(localSettingsStoreProvider)),
);

/// Serial writes prevent a delayed autosave resurrecting a submitted/logged-out draft.
class MemoryDraftStore {
  MemoryDraftStore(this.storage);
  final LocalSettingsStore storage;
  final Map<String, int> _revisions = {};
  Future<void> _tail = Future.value();

  DraftLease open(DraftScope scope) {
    final revision = (_revisions[scope.key] ?? 0) + 1;
    _revisions[scope.key] = revision;
    return DraftLease._(scope, revision);
  }

  bool _active(DraftLease lease) =>
      _revisions[lease.scope.key] == lease.revision;

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Map<String, Object?>> _read(DraftScope scope) async {
    final raw = await storage.read(scope.key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, Object?>.from(decoded) : {};
    } on FormatException {
      return {};
    }
  }

  Future<MemoryTextDraft?> read(DraftLease lease, {String? groupId}) async {
    final data = await readLocalSetting(() => _read(lease.scope));
    if (!_active(lease) || data == null) return null;
    final drafts = data['drafts'];
    if (drafts is! Map) return null;
    final key =
        groupId ?? (data['last'] is String ? data['last'] as String : '');
    return MemoryTextDraft.decode(drafts[key]);
  }

  Future<bool> save(
    DraftLease lease,
    MemoryTextDraft draft,
  ) => _serial(() async {
    if (!_active(lease)) return false;
    return await readLocalSetting(() async {
          final data = await _read(lease.scope);
          if (!_active(lease)) return false;
          final existing = data['drafts'];
          final drafts = existing is Map
              ? Map<String, Object?>.from(existing)
              : <String, Object?>{};
          if (draft.isEmpty) {
            drafts.remove(draft.audienceKey);
          } else {
            drafts.remove(draft.audienceKey);
            drafts[draft.audienceKey] = draft.json;
          }
          // Keep a small number of text drafts, never image bytes or upload credentials.
          while (drafts.length > 10) {
            drafts.remove(drafts.keys.first);
          }
          if (drafts.isEmpty) {
            await storage.delete(lease.scope.key);
          } else {
            await storage.write(
              lease.scope.key,
              jsonEncode({'last': draft.audienceKey, 'drafts': drafts}),
            );
          }
          return true;
        }) ??
        false;
  });

  Future<bool> remove(DraftLease lease, String? groupId) =>
      save(lease, MemoryTextDraft(text: '', groupId: groupId));

  Future<bool> clearScope(DraftScope scope) {
    _revisions[scope.key] = (_revisions[scope.key] ?? 0) + 1;
    return _serial(
      () async =>
          await readLocalSetting(() async {
            await storage.delete(scope.key);
            return true;
          }) ??
          false,
    );
  }
}
