import 'album.dart';

export '../../../core/circle_failure.dart';
export 'album.dart';

/// Group albums (README §3.5). Every call re-checks that the viewer is a
/// member of the album's exact group; failures are calm [CircleFailure]s.
/// Asynchronous so a real photo service can replace the local mock.
abstract interface class AlbumRepository {
  /// The group's albums, newest first.
  Future<List<Album>> albums(String viewer, String groupId);
  Future<Album> album(String viewer, String albumId);

  /// Returns the new album's id.
  Future<String> createAlbum(
    String viewer,
    String groupId,
    String title, {
    String? era,
    List<MemoryScene> scenes = const [],
  });
  Future<void> addPhotos(
    String viewer,
    String albumId,
    List<MemoryScene> scenes,
  );

  /// Reversible with [restorePhoto] (Undo).
  Future<void> removePhoto(String viewer, String albumId, String photoId);
  Future<void> restorePhoto(String viewer, String albumId, String photoId);

  /// Creator or admins only.
  Future<void> renameAlbum(
    String viewer,
    String albumId,
    String title, {
    String? era,
  });

  /// Creator or admins only. Makes [photoId] the album's cover (shown in
  /// the Albums grid). Undo sets the previous cover back.
  Future<void> setCover(String viewer, String albumId, String photoId);

  /// The photo's adder or admins. Up to 140 characters; blank removes it.
  Future<void> setCaption(
    String viewer,
    String albumId,
    String photoId,
    String? caption,
  );

  /// Creator or admins only. Confirmed in the UI; can't be undone.
  Future<void> deleteAlbum(String viewer, String albumId);

  /// The event's album, or null when nobody added photos yet.
  Future<Album?> eventAlbum(String viewer, String eventId);

  /// Adds photos to the event's album, creating "Photos from …" on the
  /// first add. Returns the album id.
  Future<String> addEventPhotos(
    String viewer,
    String eventId,
    List<MemoryScene> scenes,
  );

  /// Local preview only: discards every change.
  Future<void> reset({required bool showcase});
}
