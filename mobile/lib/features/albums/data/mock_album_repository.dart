import '../../workspace/domain/circle_repository.dart';
import '../domain/album_repository.dart';

/// Session-local, fictional albums. Photos are illustrated scenes; nothing
/// is uploaded or stored. Membership always comes from [WorkspaceReader],
/// so every read and change re-checks the exact group.
class MockAlbumRepository implements AlbumRepository {
  MockAlbumRepository({
    required WorkspaceReader groups,
    bool showcase = false,
    DateTime Function()? now,
  }) : _workspace = groups,
       _now = now ?? DateTime.now {
    _seed(showcase: showcase);
  }

  final WorkspaceReader _workspace;
  final DateTime Function() _now;
  final Map<String, _StoredAlbum> _albums = {};
  int _sequence = 0;

  @override
  Future<void> reset({required bool showcase}) async =>
      _seed(showcase: showcase);

  DateTime get _time => _now().toUtc();

  void _check(RuleResult result) {
    if (!result.allowed) throw CircleFailure(result.reason!);
  }

  static const _notShared = CircleFailure('This album is not shared with you.');

  /// The viewer's exact group, or a calm failure.
  Future<({CircleWorkspace workspace, CircleGroup group})> _group(
    String viewer,
    String groupId,
  ) async {
    final workspace = await _workspace.load(viewer);
    final group = workspace.group(groupId);
    if (group == null) throw _notShared;
    return (workspace: workspace, group: group);
  }

  Future<({_StoredAlbum album, CircleGroup group})> _stored(
    String viewer,
    String albumId,
  ) async {
    final album = _albums[albumId];
    if (album == null || album.deleted) {
      throw const CircleFailure('This album is no longer here.');
    }
    final found = await _group(viewer, album.groupId);
    return (album: album, group: found.group);
  }

  bool _admin(CircleGroup group, String viewer) =>
      group.roles[viewer]?.isAdmin ?? false;

  Album _view(_StoredAlbum album) => Album(
    id: album.id,
    groupId: album.groupId,
    title: album.title,
    era: album.era,
    createdBy: album.createdBy,
    createdAt: album.createdAt,
    coverPhotoId: album.coverPhotoId,
    eventId: album.eventId,
    photos: album.photos,
  );

  List<AlbumPhoto> _photos(
    String albumId,
    String viewer,
    List<MemoryScene> scenes,
  ) {
    final now = _time;
    return [
      for (final scene in scenes)
        AlbumPhoto(
          photo: MemoryPhoto(id: '$albumId-photo-${++_sequence}', scene: scene),
          addedBy: viewer,
          addedAt: now,
        ),
    ];
  }

  // ------------------------------------------------------------------ reads

  @override
  Future<List<Album>> albums(String viewer, String groupId) async {
    await _group(viewer, groupId);
    final list =
        [
          for (final album in _albums.values)
            if (album.groupId == groupId && !album.deleted) album,
        ]..sort((a, b) {
          final order = b.createdAt.compareTo(a.createdAt);
          return order != 0 ? order : b.order.compareTo(a.order);
        });
    return [for (final album in list) _view(album)];
  }

  @override
  Future<Album> album(String viewer, String albumId) async =>
      _view((await _stored(viewer, albumId)).album);

  @override
  Future<Album?> eventAlbum(String viewer, String eventId) async {
    final workspace = await _workspace.load(viewer);
    final event = workspace.event(eventId);
    if (event == null) {
      throw const CircleFailure('This event is unavailable.');
    }
    final album = _albums.values
        .where((album) => album.eventId == eventId && !album.deleted)
        .firstOrNull;
    return album == null ? null : _view(album);
  }

  // ---------------------------------------------------------------- changes

  @override
  Future<String> createAlbum(
    String viewer,
    String groupId,
    String title, {
    String? era,
    List<MemoryScene> scenes = const [],
  }) async {
    await _group(viewer, groupId);
    _check(AlbumRules.checkTitle(title));
    _check(AlbumRules.checkEra(era));
    if (scenes.isNotEmpty) {
      _check(AlbumRules.canAdd(current: 0, adding: scenes.length));
    }
    final id = 'local-album-${(++_sequence).toString().padLeft(6, '0')}';
    _albums[id] = _StoredAlbum(
      id: id,
      groupId: groupId,
      title: title.trim(),
      era: AlbumRules.cleanEra(era),
      createdBy: viewer,
      createdAt: _time,
      order: _sequence,
    )..photos.addAll(_photos(id, viewer, scenes));
    return id;
  }

  @override
  Future<void> addPhotos(
    String viewer,
    String albumId,
    List<MemoryScene> scenes,
  ) async {
    final found = await _stored(viewer, albumId);
    final album = found.album;
    _check(
      AlbumRules.canAdd(current: album.photos.length, adding: scenes.length),
    );
    album.photos.addAll(_photos(albumId, viewer, scenes));
  }

  @override
  Future<void> removePhoto(
    String viewer,
    String albumId,
    String photoId,
  ) async {
    final found = await _stored(viewer, albumId);
    final album = found.album;
    final index = album.photos.indexWhere((photo) => photo.id == photoId);
    if (index < 0) throw const CircleFailure('That photo is no longer here.');
    _check(
      AlbumRules.canRemovePhoto(
        album.photos[index],
        viewer,
        isMember: true,
        isAdmin: _admin(found.group, viewer),
      ),
    );
    album.removed[photoId] = (
      index: index,
      photo: album.photos.removeAt(index),
    );
  }

  @override
  Future<void> restorePhoto(
    String viewer,
    String albumId,
    String photoId,
  ) async {
    final found = await _stored(viewer, albumId);
    final album = found.album;
    final removed = album.removed[photoId];
    if (removed == null) return;
    _check(
      AlbumRules.canRemovePhoto(
        removed.photo,
        viewer,
        isMember: true,
        isAdmin: _admin(found.group, viewer),
      ),
    );
    _check(AlbumRules.canAdd(current: album.photos.length, adding: 1));
    album.removed.remove(photoId);
    album.photos.insert(
      removed.index.clamp(0, album.photos.length),
      removed.photo,
    );
  }

  @override
  Future<void> renameAlbum(
    String viewer,
    String albumId,
    String title, {
    String? era,
  }) async {
    final found = await _stored(viewer, albumId);
    final album = found.album;
    _check(
      AlbumRules.canEdit(
        _view(album),
        viewer,
        isMember: true,
        isAdmin: _admin(found.group, viewer),
      ),
    );
    _check(AlbumRules.checkTitle(title));
    _check(AlbumRules.checkEra(era));
    album
      ..title = title.trim()
      ..era = AlbumRules.cleanEra(era);
  }

  @override
  Future<void> setCover(String viewer, String albumId, String photoId) async {
    final found = await _stored(viewer, albumId);
    final album = found.album;
    _check(
      AlbumRules.canSetCover(
        _view(album),
        viewer,
        isMember: true,
        isAdmin: _admin(found.group, viewer),
      ),
    );
    if (!album.photos.any((photo) => photo.id == photoId)) {
      throw const CircleFailure('That photo is no longer here.');
    }
    album.coverPhotoId = photoId;
  }

  @override
  Future<void> setCaption(
    String viewer,
    String albumId,
    String photoId,
    String? caption,
  ) async {
    final found = await _stored(viewer, albumId);
    final album = found.album;
    final index = album.photos.indexWhere((photo) => photo.id == photoId);
    if (index < 0) throw const CircleFailure('That photo is no longer here.');
    final photo = album.photos[index];
    _check(
      AlbumRules.canEditCaption(
        photo,
        viewer,
        isMember: true,
        isAdmin: _admin(found.group, viewer),
      ),
    );
    _check(AlbumRules.checkCaption(caption));
    album.photos[index] = AlbumPhoto(
      photo: photo.photo.withCaption(PhotoCaptionRules.clean(caption)),
      addedBy: photo.addedBy,
      addedAt: photo.addedAt,
    );
  }

  @override
  Future<void> deleteAlbum(String viewer, String albumId) async {
    final found = await _stored(viewer, albumId);
    _check(
      AlbumRules.canEdit(
        _view(found.album),
        viewer,
        isMember: true,
        isAdmin: _admin(found.group, viewer),
      ),
    );
    found.album.deleted = true;
  }

  @override
  Future<String> addEventPhotos(
    String viewer,
    String eventId,
    List<MemoryScene> scenes,
  ) async {
    final workspace = await _workspace.load(viewer);
    final event = workspace.event(eventId);
    if (event == null) {
      throw const CircleFailure('This event is unavailable.');
    }
    _check(AlbumRules.canHaveEventAlbum(event, _time));
    final existing = _albums.values
        .where((album) => album.eventId == eventId && !album.deleted)
        .firstOrNull;
    if (existing != null) {
      await addPhotos(viewer, existing.id, scenes);
      return existing.id;
    }
    _check(AlbumRules.canAdd(current: 0, adding: scenes.length));
    final id = 'event-album-$eventId';
    _albums[id] = _StoredAlbum(
      id: id,
      groupId: event.groupId,
      title: AlbumRules.eventAlbumTitle(event),
      createdBy: viewer,
      createdAt: _time,
      order: ++_sequence,
      eventId: eventId,
    )..photos.addAll(_photos(id, viewer, scenes));
    return id;
  }

  // ------------------------------------------------------------------- seed

  void _seed({required bool showcase}) {
    _albums.clear();
    _sequence = 0;
    if (!showcase) return;
    final seedTime = _time;
    void album(
      String id,
      String groupId,
      String title,
      String createdBy,
      Duration age,
      List<(MemoryScene, String?, String)> photos, {
      String? era,
    }) {
      final createdAt = seedTime.subtract(age);
      _albums[id] =
          _StoredAlbum(
              id: id,
              groupId: groupId,
              title: title,
              era: era,
              createdBy: createdBy,
              createdAt: createdAt,
              order: ++_sequence,
            )
            ..photos.addAll([
              for (final (index, (scene, caption, by)) in photos.indexed)
                AlbumPhoto(
                  photo: MemoryPhoto(
                    id: '$id-photo-${index + 1}',
                    scene: scene,
                    caption: caption,
                  ),
                  addedBy: by,
                  addedAt: createdAt,
                ),
            ]);
    }

    album(
      'hostel-years',
      'college',
      'Hostel years',
      'mira',
      const Duration(days: 40),
      era: '2005–2009',
      [
        (MemoryScene.oldClassroom, 'Room 204, before the exams', 'mira'),
        (MemoryScene.cricketMatch, 'Hostel league final', 'sam'),
        (MemoryScene.graduationDay, null, 'mira'),
        (MemoryScene.hillTrip, 'The first-year trip', 'dev'),
      ],
    );
    album(
      'sunday-lunches',
      'family',
      'Sunday lunches',
      'mira',
      const Duration(days: 12),
      era: '2019–2026',
      [
        (MemoryScene.sundayLunch, 'Room for one more', 'mira'),
        (MemoryScene.birthdayCake, 'Priya’s cake', 'priya'),
        (MemoryScene.weddingStage, 'Last year’s big day', 'mira'),
      ],
    );
    album('ride-days', 'club', 'Ride days', 'you', const Duration(days: 3), [
      (MemoryScene.hillTrip, 'The scenic route', 'you'),
      (MemoryScene.beachWalk, 'Breakfast by the water', 'mira'),
    ]);
    // In a hidden subgroup the viewer is not in: never shown to them.
    album(
      'party-ideas',
      'private-plans',
      'Party ideas',
      'mira',
      const Duration(days: 1),
      [(MemoryScene.birthdayCake, null, 'mira')],
    );
  }
}

class _StoredAlbum {
  _StoredAlbum({
    required this.id,
    required this.groupId,
    required this.title,
    required this.createdBy,
    required this.createdAt,
    required this.order,
    this.era,
    this.eventId,
  });
  final String id, groupId, createdBy;
  final DateTime createdAt;
  final int order;
  final String? eventId;
  String title;
  String? era;
  String? coverPhotoId;
  bool deleted = false;
  final List<AlbumPhoto> photos = [];

  /// Removed photos and where they were, so Undo puts them back in place.
  final Map<String, ({int index, AlbumPhoto photo})> removed = {};
}
