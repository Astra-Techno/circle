/// Albums (README §3.5, G1–G3). Pure Dart; no Flutter imports.
library;

import '../../../core/rule_result.dart';
import '../../events/domain/circle_event.dart';
import '../../memories/domain/memory_photo.dart';

export '../../../core/rule_result.dart';
export '../../memories/domain/memory_photo.dart';

/// One photo in an album: a fictional illustrated scene, who added it and
/// when.
class AlbumPhoto {
  const AlbumPhoto({
    required this.photo,
    required this.addedBy,
    required this.addedAt,
  });
  final MemoryPhoto photo;
  final String addedBy;
  final DateTime addedAt;
  String get id => photo.id;
}

/// A group's album as one viewer sees it (exact-group members only).
class Album {
  Album({
    required this.id,
    required this.groupId,
    required this.title,
    required this.createdBy,
    required this.createdAt,
    List<AlbumPhoto> photos = const [],
    this.era,
    this.coverPhotoId,
    this.eventId,
  }) : photos = List.unmodifiable(photos);

  final String id, groupId, title, createdBy;

  /// Optional "2005–2009" or "Summer 2019".
  final String? era;
  final DateTime createdAt;
  final List<AlbumPhoto> photos;

  /// The chosen cover; the first photo when unset or removed.
  final String? coverPhotoId;

  /// Set for an event's automatic album ("Photos from …").
  final String? eventId;

  bool get isEventAlbum => eventId != null;

  AlbumPhoto? get cover =>
      photos.where((photo) => photo.id == coverPhotoId).firstOrNull ??
      photos.firstOrNull;

  /// "4 photos · 2005–2009".
  String get details => [
    photos.length == 1 ? '1 photo' : '${photos.length} photos',
    ?era,
  ].join(' · ');
}

const _ok = RuleResult.allowed();

/// Pure album rules shared by the repository and the UI. Membership is
/// always the exact group; nothing is inherited from parents.
abstract final class AlbumRules {
  static const maxTitle = 80, maxEra = 20, maxPhotos = 50;

  /// How many scenes one pick may add (the scene picker's limit).
  static const maxPerAdd = 10;

  static RuleResult checkTitle(String title) {
    final value = title.trim();
    return value.isEmpty || value.runes.length > maxTitle
        ? const RuleResult.denied('Use an album name with 1–80 characters.')
        : _ok;
  }

  static RuleResult checkEra(String? era) =>
      (era?.trim().runes.length ?? 0) > maxEra
      ? const RuleResult.denied('Keep the year or era to 20 characters.')
      : _ok;

  /// Blank eras are stored as null.
  static String? cleanEra(String? era) {
    final value = era?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  /// An album holds up to 50 photos.
  static RuleResult canAdd({required int current, required int adding}) {
    if (adding < 1) {
      return const RuleResult.denied('Choose at least one photo.');
    }
    if (current + adding > maxPhotos) {
      final left = maxPhotos - current;
      return RuleResult.denied(
        left <= 0
            ? 'This album is full (50 photos).'
            : 'An album holds 50 photos. You can add $left more.',
      );
    }
    return _ok;
  }

  /// How many more photos fit, for the picker (never more than a pick).
  static int room(Album album) =>
      (maxPhotos - album.photos.length).clamp(0, maxPerAdd);

  /// Any member of the exact group may look at and add to its albums.
  static RuleResult canView({required bool isMember}) => isMember
      ? _ok
      : const RuleResult.denied('This album is not shared with you.');

  /// The album's creator or the group's admins rename or delete it.
  static RuleResult canEdit(
    Album album,
    String actor, {
    required bool isMember,
    required bool isAdmin,
  }) {
    if (!isMember) {
      return const RuleResult.denied('This album is not shared with you.');
    }
    return album.createdBy == actor || isAdmin
        ? _ok
        : const RuleResult.denied(
            'Only the person who made this album or an admin can change it.',
          );
  }

  /// Captions are optional and up to 140 characters.
  static const maxCaption = PhotoCaptionRules.maxLength;

  /// The album's creator or the group's admins choose its cover.
  static RuleResult canSetCover(
    Album album,
    String actor, {
    required bool isMember,
    required bool isAdmin,
  }) {
    if (!isMember) {
      return const RuleResult.denied('This album is not shared with you.');
    }
    return album.createdBy == actor || isAdmin
        ? _ok
        : const RuleResult.denied(
            'Only the person who made this album or an admin can choose '
            'its cover.',
          );
  }

  /// Whether [photoId] is [album]'s cover now (chosen, or the first photo
  /// when none is chosen).
  static bool isCover(Album album, String photoId) =>
      album.cover?.id == photoId;

  /// The person who added a photo, or the group's admins, write its
  /// caption.
  static RuleResult canEditCaption(
    AlbumPhoto photo,
    String actor, {
    required bool isMember,
    required bool isAdmin,
  }) {
    if (!isMember) {
      return const RuleResult.denied('This album is not shared with you.');
    }
    return photo.addedBy == actor || isAdmin
        ? _ok
        : const RuleResult.denied(
            'Only the person who added this photo or an admin can caption it.',
          );
  }

  static RuleResult checkCaption(String? caption) =>
      PhotoCaptionRules.check(caption);

  /// People remove photos they added; admins may remove any.
  static RuleResult canRemovePhoto(
    AlbumPhoto photo,
    String actor, {
    required bool isMember,
    required bool isAdmin,
  }) {
    if (!isMember) {
      return const RuleResult.denied('This album is not shared with you.');
    }
    return photo.addedBy == actor || isAdmin
        ? _ok
        : const RuleResult.denied('You can only remove photos you added.');
  }

  /// Past events (not cancelled) collect photos in their own album.
  static RuleResult canHaveEventAlbum(CircleEvent event, DateTime now) {
    if (event.cancelled) {
      return const RuleResult.denied('Cancelled events have no album.');
    }
    return !now.isBefore(event.endsOrStarts)
        ? _ok
        : const RuleResult.denied(
            'Photos can be added once the event is over.',
          );
  }

  static String eventAlbumTitle(CircleEvent event) {
    final title = 'Photos from ${event.title}';
    return title.runes.length <= maxTitle
        ? title
        : '${String.fromCharCodes(title.runes.take(maxTitle - 1))}…';
  }
}
