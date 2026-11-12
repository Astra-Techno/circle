import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/mock_album_repository.dart';
import '../data/api_album_repository.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/scoped_api.dart';
import '../domain/album_repository.dart';

export '../domain/album_repository.dart';

/// Authenticated sessions use the exact-Circle album API; fictional fixtures
/// retain their isolated repository for offline tests.
final albumRepositoryProvider = Provider<AlbumRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final account = ref.watch(serverAccountProvider)?.id;
  if (api != null && account != null) {
    return ApiAlbumRepository(
      ScopedApi(
        api,
        account,
        api.sessionRevision,
        () =>
            ref.mounted &&
            identical(ref.read(apiClientProvider), api) &&
            ref.read(serverAccountProvider)?.id == account,
      ),
    );
  }
  return MockAlbumRepository(
    groups: ref.watch(circleRepositoryProvider),
    showcase: false,
    now: ref.watch(circleClockProvider),
  );
});

/// Runs album changes for the current viewer. Its state is a revision that
/// album reads watch, so every change refreshes them.
final albumControllerProvider = NotifierProvider<AlbumController, int>(
  AlbumController.new,
);

/// A value, or the calm reason it can't be shown.
typedef AlbumLoad<T> = ({T? value, String? unavailable});

Future<AlbumLoad<T>> _load<T>(Future<T> Function() read) async {
  try {
    return (value: await read(), unavailable: null);
  } on CircleFailure catch (failure) {
    return (value: null, unavailable: failure.message);
  }
}

final groupAlbumsProvider =
    FutureProvider.family<AlbumLoad<List<Album>>, String>((ref, groupId) {
      ref.watch(albumControllerProvider);
      ref.watch(circleWorkspaceProvider);
      final viewer = ref.watch(circleViewerProvider);
      final repository = ref.watch(albumRepositoryProvider);
      return _load(() => repository.albums(viewer, groupId));
    });

final albumProvider = FutureProvider.family<AlbumLoad<Album>, String>((
  ref,
  albumId,
) {
  ref.watch(albumControllerProvider);
  ref.watch(circleWorkspaceProvider);
  final viewer = ref.watch(circleViewerProvider);
  final repository = ref.watch(albumRepositoryProvider);
  return _load(() => repository.album(viewer, albumId));
});

final eventAlbumProvider = FutureProvider.family<AlbumLoad<Album?>, String>((
  ref,
  eventId,
) {
  ref.watch(albumControllerProvider);
  ref.watch(circleWorkspaceProvider);
  final viewer = ref.watch(circleViewerProvider);
  final repository = ref.watch(albumRepositoryProvider);
  return _load<Album?>(() => repository.eventAlbum(viewer, eventId));
});

class AlbumController extends Notifier<int> {
  @override
  int build() {
    ref.watch(albumRepositoryProvider);
    return 0;
  }

  Future<T> _run<T>(Future<T> Function(AlbumRepository, String) change) async {
    try {
      return await change(
        ref.read(albumRepositoryProvider),
        ref.read(circleViewerProvider),
      );
    } finally {
      // Refresh even after a failure: something else may have changed.
      if (ref.mounted) state++;
    }
  }

  Future<String> create(
    String groupId,
    String title, {
    String? era,
    List<MemoryScene> scenes = const [],
  }) => _run(
    (repo, viewer) =>
        repo.createAlbum(viewer, groupId, title, era: era, scenes: scenes),
  );
  Future<void> addSharedPhotos(String albumId, List<String> ids) =>
      _run((repo, viewer) => repo.addSharedPhotos(viewer, albumId, ids));
  Future<void> addPhotos(String albumId, List<MemoryScene> scenes) =>
      _run((repo, viewer) => repo.addPhotos(viewer, albumId, scenes));
  Future<void> removePhoto(String albumId, String photoId) =>
      _run((repo, viewer) => repo.removePhoto(viewer, albumId, photoId));
  Future<void> restorePhoto(String albumId, String photoId) =>
      _run((repo, viewer) => repo.restorePhoto(viewer, albumId, photoId));
  Future<void> rename(String albumId, String title, {String? era}) => _run(
    (repo, viewer) => repo.renameAlbum(viewer, albumId, title, era: era),
  );
  Future<void> setCover(String albumId, String photoId) =>
      _run((repo, viewer) => repo.setCover(viewer, albumId, photoId));
  Future<void> setCaption(String albumId, String photoId, String? caption) =>
      _run(
        (repo, viewer) => repo.setCaption(viewer, albumId, photoId, caption),
      );
  Future<void> delete(String albumId) =>
      _run((repo, viewer) => repo.deleteAlbum(viewer, albumId));
  Future<String> addEventPhotos(String eventId, List<MemoryScene> scenes) =>
      _run((repo, viewer) => repo.addEventPhotos(viewer, eventId, scenes));
}
