import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/albums/data/mock_album_repository.dart';
import 'package:mobile/features/albums/domain/album_repository.dart';
import 'package:mobile/features/workspace/data/mock_circle_repository.dart';

final fixed = DateTime.utc(2026, 10, 23, 12);
Matcher failsWith(String text) => throwsA(
  isA<CircleFailure>().having((f) => f.message, 'message', contains(text)),
);

({MockCircleRepository groups, MockAlbumRepository albums}) setup() {
  final groups = MockCircleRepository(showcase: true, now: () => fixed);
  return (
    groups: groups,
    albums: MockAlbumRepository(
      groups: groups,
      showcase: true,
      now: () => fixed,
    ),
  );
}

AlbumPhoto photo(String by) => AlbumPhoto(
  photo: const MemoryPhoto(id: 'p', scene: MemoryScene.hillTrip),
  addedBy: by,
  addedAt: fixed,
);

Album album({String createdBy = 'mira', int photos = 0}) => Album(
  id: 'a',
  groupId: 'g',
  title: 'Album',
  createdBy: createdBy,
  createdAt: fixed,
  photos: [for (var i = 0; i < photos; i++) photo('mira')],
);

void main() {
  group('AlbumRules', () {
    test('titles are 1–80 characters; eras up to 20 and optional', () {
      expect(AlbumRules.checkTitle('  ').allowed, isFalse);
      expect(AlbumRules.checkTitle('a' * 80).allowed, isTrue);
      expect(AlbumRules.checkTitle('a' * 81).allowed, isFalse);
      expect(AlbumRules.checkEra(null).allowed, isTrue);
      expect(AlbumRules.checkEra('2005–2009').allowed, isTrue);
      expect(AlbumRules.checkEra('a' * 21).allowed, isFalse);
      expect(AlbumRules.cleanEra('  '), isNull);
    });

    test('an album holds at most 50 photos', () {
      expect(AlbumRules.canAdd(current: 40, adding: 10).allowed, isTrue);
      final over = AlbumRules.canAdd(current: 45, adding: 6);
      expect(over.allowed, isFalse);
      expect(over.reason, contains('5 more'));
      expect(
        AlbumRules.canAdd(current: 50, adding: 1).reason,
        contains('full'),
      );
      expect(AlbumRules.canAdd(current: 0, adding: 0).allowed, isFalse);
      expect(AlbumRules.room(album(photos: 45)), 5);
      expect(AlbumRules.room(album(photos: 2)), AlbumRules.maxPerAdd);
    });

    test('creator or admins edit; members only remove their own photos', () {
      final mine = album(createdBy: 'you');
      final theirs = album();
      bool edit(Album a, {bool admin = false, bool member = true}) =>
          AlbumRules.canEdit(
            a,
            'you',
            isMember: member,
            isAdmin: admin,
          ).allowed;
      expect(edit(mine), isTrue);
      expect(edit(theirs), isFalse);
      expect(edit(theirs, admin: true), isTrue);
      expect(edit(mine, member: false), isFalse, reason: 'exact group only');
      expect(
        AlbumRules.canRemovePhoto(
          photo('you'),
          'you',
          isMember: true,
          isAdmin: false,
        ).allowed,
        isTrue,
      );
      expect(
        AlbumRules.canRemovePhoto(
          photo('mira'),
          'you',
          isMember: true,
          isAdmin: false,
        ).allowed,
        isFalse,
      );
      expect(
        AlbumRules.canRemovePhoto(
          photo('mira'),
          'you',
          isMember: true,
          isAdmin: true,
        ).allowed,
        isTrue,
      );
    });
  });

  group('MockAlbumRepository', () {
    test('lists only albums of the exact group; others are denied', () async {
      final s = setup();
      final family = await s.albums.albums('you', 'family');
      expect(family.single.title, 'Sunday lunches');
      expect(family.single.details, '3 photos · 2019–2026');
      // A hidden subgroup the viewer isn't in, even though they're in its
      // parent: no inherited access.
      await expectLater(
        s.albums.albums('you', 'private-plans'),
        failsWith('not shared with you'),
      );
      await expectLater(
        s.albums.album('you', 'party-ideas'),
        failsWith('not shared with you'),
      );
      expect(
        (await s.albums.album('mira', 'party-ideas')).title,
        'Party ideas',
      );
    });

    test('create, add, remove with undo in place, rename and delete', () async {
      final s = setup();
      final id = await s.albums.createAlbum(
        'you',
        'club',
        '  Winter rides  ',
        era: ' 2026 ',
        scenes: [MemoryScene.hillTrip, MemoryScene.beachWalk],
      );
      var created = await s.albums.album('you', id);
      expect(created.title, 'Winter rides');
      expect(created.era, '2026');
      expect(created.photos.length, 2);
      await s.albums.addPhotos('you', id, [MemoryScene.cricketMatch]);
      created = await s.albums.album('you', id);
      final first = created.photos.first.id;
      await s.albums.removePhoto('you', id, first);
      expect((await s.albums.album('you', id)).photos.length, 2);
      await s.albums.restorePhoto('you', id, first);
      expect((await s.albums.album('you', id)).photos.first.id, first);
      await s.albums.renameAlbum('you', id, 'Cold rides', era: '');
      created = await s.albums.album('you', id);
      expect(created.title, 'Cold rides');
      expect(created.era, isNull);
      await s.albums.deleteAlbum('you', id);
      await expectLater(s.albums.album('you', id), failsWith('no longer here'));
    });

    test('only the creator or admins rename and delete', () async {
      final s = setup();
      // The viewer made "Ride days"; Mira (a plain member) can't rename it.
      await expectLater(
        s.albums.renameAlbum('mira', 'ride-days', 'Mine now'),
        failsWith('Only the person who made this album'),
      );
      // The viewer owns The Sunday table, so admins may edit Mira's album.
      await s.albums.renameAlbum('you', 'sunday-lunches', 'Sunday tables');
      expect(
        (await s.albums.album('you', 'sunday-lunches')).title,
        'Sunday tables',
      );
      // Dev is a member of Northbank 2009 but not its admin.
      await expectLater(
        s.albums.deleteAlbum('dev', 'hostel-years'),
        failsWith('Only the person who made this album'),
      );
      // Members remove only their own photos.
      await expectLater(
        s.albums.removePhoto('dev', 'hostel-years', 'hostel-years-photo-1'),
        failsWith('only remove photos you added'),
      );
      await s.albums.removePhoto('dev', 'hostel-years', 'hostel-years-photo-4');
    });

    test('limits: 50 photos per album; empty titles refused', () async {
      final s = setup();
      await expectLater(
        s.albums.createAlbum('you', 'club', ' '),
        failsWith('1–80 characters'),
      );
      final id = await s.albums.createAlbum('you', 'club', 'Big album');
      for (var i = 0; i < 5; i++) {
        await s.albums.addPhotos('you', id, [
          for (var j = 0; j < 10; j++) MemoryScene.values[j],
        ]);
      }
      expect((await s.albums.album('you', id)).photos.length, 50);
      await expectLater(
        s.albums.addPhotos('you', id, [MemoryScene.hillTrip]),
        failsWith('full'),
      );
    });

    test('event albums: past events only, created on first add', () async {
      final s = setup();
      expect(await s.albums.eventAlbum('you', 'picnic'), isNull);
      await expectLater(
        s.albums.addEventPhotos('you', 'lunch', [MemoryScene.sundayLunch]),
        failsWith('once the event is over'),
      );
      final id = await s.albums.addEventPhotos('you', 'picnic', [
        MemoryScene.beachWalk,
      ]);
      final created = (await s.albums.eventAlbum('you', 'picnic'))!;
      expect(created.id, id);
      expect(created.title, 'Photos from Autumn picnic');
      expect(created.groupId, 'club');
      expect(created.isEventAlbum, isTrue);
      final again = await s.albums.addEventPhotos('you', 'picnic', [
        MemoryScene.hillTrip,
      ]);
      expect(again, id, reason: 'one album per event');
      expect((await s.albums.album('you', id)).photos.length, 2);
      // Someone outside the event's group can't see it.
      await expectLater(
        s.albums.eventAlbum('noor', 'picnic'),
        failsWith('unavailable'),
      );
    });

    test('leaving a group removes access; reset clears changes', () async {
      final s = setup();
      await s.groups.leaveGroup('you', 'college');
      await expectLater(
        s.albums.albums('you', 'college'),
        failsWith('not shared with you'),
      );
      await s.albums.createAlbum('you', 'club', 'Temporary');
      await s.albums.reset(showcase: true);
      expect((await s.albums.albums('you', 'club')).map((a) => a.title), [
        'Ride days',
      ]);
      await s.albums.reset(showcase: false);
      await s.groups.reset(showcase: true);
      expect(await s.albums.albums('you', 'club'), isEmpty);
    });
  });
}
