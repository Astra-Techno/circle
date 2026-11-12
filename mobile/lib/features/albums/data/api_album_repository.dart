import '../../../core/api/api_json.dart';
import '../../../core/api/scoped_api.dart';
import '../domain/album_repository.dart';

/// Albums collect photos already shared in the same exact Circle.
class ApiAlbumRepository implements AlbumRepository {
  ApiAlbumRepository(this.scope);
  final ScopedApi scope;
  final Map<String, AlbumPhoto> _removed = {};
  void _viewer(String viewer) {
    scope.check();
    if (viewer != scope.account) throw const CircleFailure('Sign in again.');
  }

  DateTime _date(Object? value) =>
      DateTime.parse('${ApiJson.string(value).replaceAll(' ', 'T')}Z');
  Album _decode(Map<String, Object?> row, List<AlbumPhoto> photos) => Album(
    id: ApiJson.id(row['id']),
    groupId: ApiJson.id(row['group_id']),
    title: ApiJson.string(row['title']),
    createdBy: ApiJson.id(row['created_by']),
    createdAt: _date(row['created_at']),
    era: ApiJson.optionalString(row['description']),
    eventId: ApiJson.optionalId(row['event_id']),
    photos: photos,
    photoCount: ApiJson.integer(row['photo_count']),
    coverPhotoId: photos
        .where((p) => p.photo.mediaId == row['cover_media_id'])
        .firstOrNull
        ?.id,
  );

  @override
  Future<List<Album>> albums(String viewer, String groupId) async {
    _viewer(viewer);
    final result = <Album>[];
    for (var offset = 0; ; offset += 100) {
      final page = await scope.get(
        '/groups/$groupId/albums',
        query: {'limit': 100, 'offset': offset},
      );
      for (final value in ApiJson.list(page['items'])) {
        final row = ApiJson.map(value);
        final cover = ApiJson.optionalId(row['cover_media_id']);
        result.add(
          _decode(row, [
            if (cover != null)
              AlbumPhoto(
                photo: MemoryPhoto(id: cover, mediaId: cover),
                addedBy: ApiJson.id(row['created_by']),
                addedAt: _date(row['created_at']),
              ),
          ]),
        );
      }
      if (!ApiJson.boolean(page['has_more'])) break;
    }
    return result;
  }

  @override
  Future<Album> album(String viewer, String albumId) async {
    _viewer(viewer);
    final photos = <AlbumPhoto>[];
    Map<String, Object?>? row;
    for (var offset = 0; ; offset += 200) {
      row = await scope.get(
        '/albums/$albumId',
        query: {'limit': 200, 'offset': offset},
      );
      final page = ApiJson.map(row['photos']);
      for (final value in ApiJson.list(page['items'])) {
        final photo = ApiJson.map(value);
        photos.add(
          AlbumPhoto(
            photo: MemoryPhoto(
              id: ApiJson.id(photo['id']),
              mediaId: ApiJson.id(photo['media_id']),
              caption: ApiJson.optionalString(photo['caption']),
            ),
            addedBy: ApiJson.id(photo['added_by']),
            addedAt: _date(photo['added_at']),
          ),
        );
      }
      if (!ApiJson.boolean(page['has_more'])) break;
    }
    return _decode(row, photos);
  }

  @override
  Future<String> createAlbum(
    String viewer,
    String groupId,
    String title, {
    String? era,
    List<MemoryScene> scenes = const [],
  }) async {
    _viewer(viewer);
    if (scenes.isNotEmpty) {
      throw const CircleFailure('Choose photos shared in this Circle.');
    }
    final row = await scope.change('POST', '/groups/$groupId/albums', {
      'title': title.trim(),
      'description': era ?? '',
    });
    return ApiJson.id(row['id']);
  }

  @override
  Future<void> addSharedPhotos(
    String viewer,
    String albumId,
    List<String> mediaIds,
  ) async {
    _viewer(viewer);
    for (final media in mediaIds.toSet()) {
      await scope.change('POST', '/albums/$albumId/photos', {
        'media_id': media,
      });
    }
  }

  @override
  Future<void> addPhotos(
    String viewer,
    String albumId,
    List<MemoryScene> scenes,
  ) async {
    throw const CircleFailure('Choose photos already shared in this Circle.');
  }

  @override
  Future<void> removePhoto(
    String viewer,
    String albumId,
    String photoId,
  ) async {
    final current = await album(viewer, albumId);
    final photo = current.photos.where((p) => p.id == photoId).firstOrNull;
    if (photo == null) {
      throw const CircleFailure('This photo is no longer available.');
    }
    await scope.remove('/albums/$albumId/photos/$photoId');
    _removed['$albumId/$photoId'] = photo;
  }

  @override
  Future<void> restorePhoto(
    String viewer,
    String albumId,
    String photoId,
  ) async {
    _viewer(viewer);
    final photo = _removed['$albumId/$photoId'];
    if (photo == null) {
      throw const CircleFailure('This photo cannot be restored.');
    }
    await scope.change('POST', '/albums/$albumId/photos', {
      'media_id': photo.photo.mediaId,
      'caption': photo.photo.caption ?? '',
    });
    _removed.remove('$albumId/$photoId');
  }

  @override
  Future<void> renameAlbum(
    String viewer,
    String albumId,
    String title, {
    String? era,
  }) async {
    _viewer(viewer);
    await scope.change('PATCH', '/albums/$albumId', {
      'title': title.trim(),
      'description': era ?? '',
    });
  }

  @override
  Future<void> setCover(String viewer, String albumId, String photoId) async {
    final current = await album(viewer, albumId);
    final photo = current.photos.where((p) => p.id == photoId).firstOrNull;
    await scope.change('PATCH', '/albums/$albumId', {
      'cover_media_id': photo?.photo.mediaId ?? '',
    });
  }

  @override
  Future<void> setCaption(
    String viewer,
    String albumId,
    String photoId,
    String? caption,
  ) async {
    _viewer(viewer);
    await scope.change('PATCH', '/albums/$albumId/photos/$photoId', {
      'caption': caption ?? '',
    });
  }

  @override
  Future<void> deleteAlbum(String viewer, String albumId) async {
    _viewer(viewer);
    await scope.remove('/albums/$albumId');
  }

  @override
  Future<Album?> eventAlbum(String viewer, String eventId) async {
    _viewer(viewer);
    final event = await scope.get('/events/$eventId');
    return (await albums(
      viewer,
      ApiJson.id(event['group_id']),
    )).where((a) => a.eventId == eventId).firstOrNull;
  }

  @override
  Future<String> addEventPhotos(
    String viewer,
    String eventId,
    List<MemoryScene> scenes,
  ) async {
    throw const CircleFailure('Add shared photos from the Circle album.');
  }

  @override
  Future<void> reset({required bool showcase}) async {
    _removed.clear();
  }
}
