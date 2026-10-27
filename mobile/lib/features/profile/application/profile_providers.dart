import '../../workspace/application/workspace_providers.dart'
    show circleWorkspaceProvider;
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/circle_failure.dart';
import '../../workspace/application/server_session.dart';
import '../data/profile_photo_picker.dart';

export '../../../core/api/auth_api.dart'
    show ProfilePhotoKind, ProfilePickedPhoto;
export '../data/profile_photo_picker.dart' show ProfilePhotoPicker;

final profilePhotoPickerProvider = Provider<ProfilePhotoPicker>(
  (ref) => DeviceProfilePhotoPicker(),
);

/// Private bytes are scoped by the active account, API server and opaque photo
/// version. No bearer token or private path is ever put in a public image URL.
final profilePhotoBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, ({ProfilePhotoKind kind, String version})>((
      ref,
      photo,
    ) async {
      final account = ref.watch(
        serverAccountProvider.select(
          (a) => (id: a?.id, version: a?.photoVersion(photo.kind)),
        ),
      );
      final api = ref.watch(apiClientProvider);
      if (account.id == null ||
          api == null ||
          photo.version.isEmpty ||
          account.version != photo.version) {
        throw const CircleFailure('Please log in again to view your photo.');
      }
      final bytes = await api.getBytes(
        '/me/photos/${photo.kind.name}',
        query: {
          'size': photo.kind == ProfilePhotoKind.avatar ? 'thumb' : 'medium',
        },
      );
      if (!ref.mounted) throw const CircleFailure('Your session changed.');
      final current = ref.read(serverAccountProvider);
      if (current?.id != account.id ||
          current?.photoVersion(photo.kind) != photo.version ||
          !identical(ref.read(apiClientProvider), api)) {
        throw const CircleFailure('Your session changed.');
      }
      return bytes;
    }, retry: (_, _) => null);

/// Another member's photos are fetched through the existing private endpoint.
/// Exact shared membership is required both here and again by the server.
final sharedProfilePhotoBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, ({String person, ProfilePhotoKind kind})>((
      ref,
      photo,
    ) async {
      final account = ref.watch(serverAccountProvider);
      final api = ref.watch(apiClientProvider);
      final shared = ref.watch(
        circleWorkspaceProvider.select((state) {
          final workspace = state.value;
          return workspace != null &&
              workspace.viewer == account?.id &&
              workspace.groups.any(
                (group) =>
                    group.isMember(workspace.viewer) &&
                    group.isMember(photo.person),
              );
        }),
      );
      if (account == null ||
          api == null ||
          !shared ||
          !RegExp(r'^[1-9][0-9]*$').hasMatch(photo.person)) {
        throw const CircleFailure('This profile isn’t available.');
      }
      final version = ref.watch(
        circleWorkspaceProvider.select(
          (state) => state.value?.avatarVersions[photo.person],
        ),
      );
      final cache = ref.watch(personPhotoCacheProvider);
      final key =
          '${api.sessionRevision}:${photo.person}:${photo.kind.name}:${version ?? ''}';
      if (photo.kind == ProfilePhotoKind.avatar) {
        final cached = cache.read(key, api.sessionRevision);
        if (cached != null) return cached.bytes;
      }
      final revision = api.sessionRevision;
      try {
        final bytes = await api.getBytes(
          '/profiles/${photo.person}/photos/${photo.kind.name}',
          query: {
            'size': photo.kind == ProfilePhotoKind.avatar ? 'thumb' : 'medium',
          },
          expectedAccount: account.id,
          expectedSession: revision,
        );
        if (!ref.mounted ||
            !identical(ref.read(apiClientProvider), api) ||
            api.sessionRevision != revision ||
            ref.read(serverAccountProvider)?.id != account.id) {
          throw const CircleFailure('Your session changed.');
        }
        if (photo.kind == ProfilePhotoKind.avatar) {
          cache.put(key, bytes, revision);
        }
        return bytes;
      } on ApiError catch (error) {
        // No photo and inaccessible photos deliberately have the same response.
        if (error.status == 404) {
          if (photo.kind == ProfilePhotoKind.avatar &&
              api.sessionRevision == revision) {
            cache.put(key, null, revision);
          }
          return null;
        }
        rethrow;
      }
    }, retry: (_, _) => null);

class PersonPhotoCacheEntry {
  PersonPhotoCacheEntry(this.bytes, this.at);
  final Uint8List? bytes;
  final DateTime at;
}

/// Bounded in-memory LRU; lazy expiry avoids timers/background work. Cache is
/// isolated by API/account and cleared on session revision or explicit refresh.
class PersonPhotoCache {
  PersonPhotoCache(this.now);
  final DateTime Function() now;
  final _entries = <String, PersonPhotoCacheEntry>{};
  int? _revision;
  void _scope(int revision) {
    if (_revision != revision) {
      _entries.clear();
      _revision = revision;
    }
  }

  PersonPhotoCacheEntry? read(String key, int revision) {
    _scope(revision);
    final value = _entries.remove(key);
    if (value == null ||
        now().difference(value.at) >= const Duration(seconds: 45)) {
      return null;
    }
    _entries[key] = value;
    return value;
  }

  void put(String key, Uint8List? bytes, int revision) {
    _scope(revision);
    _entries.remove(key);
    _entries[key] = PersonPhotoCacheEntry(bytes, now());
    while (_entries.length > 64) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();
}

final personPhotoCacheProvider = Provider<PersonPhotoCache>((ref) {
  ref.watch(apiClientProvider);
  ref.watch(serverAccountProvider.select((a) => a?.id));
  return PersonPhotoCache(DateTime.now);
});
