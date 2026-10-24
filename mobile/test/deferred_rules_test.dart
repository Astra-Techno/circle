import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/albums/domain/album.dart';
import 'package:mobile/features/chat/domain/chat_rules.dart';
import 'package:mobile/features/workspace/data/mock_circle_repository.dart';

final fixed = DateTime.utc(2026, 10, 23, 12);

ChatMessage message({
  String text = 'Hello',
  SharedContent? shared,
  Poll? poll,
  List<MemoryPhoto> photos = const [],
  DateTime? unsentAt,
}) => ChatMessage(
  id: 'm',
  conversationId: 'c',
  authorId: 'mira',
  clientMessageId: 'x',
  createdAt: fixed,
  text: text,
  shared: shared,
  poll: poll,
  photos: photos,
  unsentAt: unsentAt,
);

const members = [
  MentionCandidate(id: 'you', name: 'You'),
  MentionCandidate(id: 'mira', name: 'Mira'),
  MentionCandidate(id: 'dev', name: 'Dev'),
  MentionCandidate(id: 'priya', name: 'Priya'),
  MentionCandidate(id: 'mona', name: 'Mona Rao'),
];

void main() {
  group('EventCalendar', () {
    List<DateTime> grid(int year, int month) =>
        EventCalendar.monthGrid(DateTime.utc(year, month));

    test('October 2026: Monday-first weeks with neighbouring days', () {
      final days = grid(2026, 10);
      expect(days, hasLength(35));
      expect(days.first, DateTime.utc(2026, 9, 28), reason: 'a Monday');
      expect(days.first.weekday, DateTime.monday);
      expect(days.last, DateTime.utc(2026, 11, 1));
      expect(days.last.weekday, DateTime.sunday);
      expect(days.where((d) => d.month == 10), hasLength(31));
      expect(EventCalendar.weeks(days), hasLength(5));
    });

    test('a month starting on Sunday needs six weeks', () {
      final days = grid(2026, 11); // 1 November 2026 is a Sunday.
      expect(DateTime.utc(2026, 11).weekday, DateTime.sunday);
      expect(days, hasLength(42));
      expect(days.first, DateTime.utc(2026, 10, 26));
      expect(days[6], DateTime.utc(2026, 11, 1));
    });

    test('leap years: February has 29 days; a Monday-start fits 4 weeks', () {
      expect(EventCalendar.isLeapYear(2024), isTrue);
      expect(EventCalendar.isLeapYear(2026), isFalse);
      expect(EventCalendar.isLeapYear(1900), isFalse);
      expect(EventCalendar.isLeapYear(2000), isTrue);
      expect(EventCalendar.daysInMonth(2024, 2), 29);
      expect(EventCalendar.daysInMonth(2026, 2), 28);
      expect(grid(2024, 2).where((d) => d.month == 2), hasLength(29));
      // 1 February 2021 was a Monday and the month has 28 days.
      final exact = grid(2021, 2);
      expect(exact, hasLength(28));
      expect(exact.first, DateTime.utc(2021, 2, 1));
      expect(exact.last, DateTime.utc(2021, 2, 28));
    });

    test('dates are UTC midnights one day apart (DST-safe)', () {
      // March and October hold daylight-saving changes in many zones.
      for (final month in [3, 10]) {
        final days = grid(2026, month);
        for (var i = 1; i < days.length; i++) {
          expect(days[i].isUtc, isTrue);
          expect(days[i].hour, 0);
          expect(days[i].difference(days[i - 1]), const Duration(days: 1));
        }
      }
      // A local time keeps its own calendar date.
      expect(
        EventCalendar.dateOnly(DateTime(2026, 3, 29, 1, 30)),
        DateTime.utc(2026, 3, 29),
      );
    });

    test('months move across years', () {
      expect(
        EventCalendar.addMonths(DateTime.utc(2026, 12), 1),
        DateTime.utc(2027, 1),
      );
      expect(
        EventCalendar.addMonths(DateTime.utc(2026, 1), -1),
        DateTime.utc(2025, 12),
      );
      expect(EventCalendar.monthOf(fixed), DateTime.utc(2026, 10));
      expect(EventCalendar.monthLabel(DateTime.utc(2026, 10)), 'October 2026');
    });

    test('events land on the date they start in their own zone', () async {
      final repository = MockCircleRepository(showcase: true, now: () => fixed);
      final events = (await repository.load('you')).events;
      final byDay = EventCalendar.byDay(events);
      // Family lunch: Sunday 25 October, 12:30 IST.
      expect(
        byDay[DateTime.utc(2026, 10, 25)]!.map((e) => e.id),
        contains('lunch'),
      );
      expect(byDay.values.expand((list) => list), hasLength(events.length));
    });

    test('spoken day labels', () {
      final sunday = DateTime.utc(2026, 10, 25);
      expect(EventCalendar.dayTitle(sunday), 'Sunday 25 October');
      expect(
        EventCalendar.daySemantics(sunday, events: 2),
        'Sunday 25 October, 2 events',
      );
      expect(
        EventCalendar.daySemantics(sunday, events: 1, today: true),
        'Sunday 25 October, today, 1 event',
      );
      expect(
        EventCalendar.daySemantics(sunday, events: 0),
        'Sunday 25 October, no events',
      );
    });
  });

  group('MentionRules', () {
    test('an "@" plus letters before the cursor is a query', () {
      expect(MentionRules.activeQuery('Hi @Mi', 6), (start: 3, query: 'Mi'));
      expect(MentionRules.activeQuery('@d', 2), (start: 0, query: 'd'));
      expect(MentionRules.activeQuery('Hi @', 4), isNull, reason: 'no letter');
      expect(MentionRules.activeQuery('mail@mira', 9), isNull);
      expect(MentionRules.activeQuery('Hi @Mira and', 12), isNull);
      expect(MentionRules.activeQuery('Hi @Mi', 99), isNull);
    });

    test('suggestions: the exact group only, never you or blocked', () {
      List<String> names(String query, {Set<String> blocked = const {}}) => [
        for (final person in MentionRules.suggestions(
          query: query,
          members: members,
          viewer: 'you',
          blocked: blocked,
        ))
          person.name,
      ];
      expect(names('m'), ['Mira', 'Mona Rao']);
      expect(names('MI'), ['Mira'], reason: 'ignores case');
      expect(names('rao'), ['Mona Rao'], reason: 'any word of the name');
      expect(names('yo'), isEmpty, reason: 'never yourself');
      expect(names('m', blocked: {'mira'}), ['Mona Rao']);
      // Lena isn't in this group, so she can never be suggested.
      expect(names('le'), isEmpty);
      expect(
        MentionRules.suggestions(
          query: 'm',
          members: [...members, ...members],
          viewer: 'you',
        ),
        hasLength(2),
        reason: 'duplicates collapse',
      );
    });

    test('picking writes "@Name " in place of the query', () {
      final result = MentionRules.insert(
        'Thanks @mi!',
        start: 7,
        cursor: 10,
        name: 'Mira',
      );
      expect(result.text, 'Thanks @Mira !');
      expect(result.cursor, 13);
      final spaced = MentionRules.insert(
        '@De see you',
        start: 0,
        cursor: 3,
        name: 'Dev',
      );
      expect(spaced.text, '@Dev see you');
      expect(spaced.cursor, 5);
    });

    test('kept mentions: still written, still members, once each', () {
      expect(
        MentionRules.resolve(
          text: '@Mira and @Mira again, and @Dev',
          picked: {'mira': 'Mira', 'dev': 'Dev', 'priya': 'Priya'},
          members: {'you', 'mira', 'priya'},
        ),
        {'mira': 'Mira'},
        reason: 'Dev left the group; Priya was deleted from the text',
      );
      expect(MentionRules.mentions('@Mirabel', 'Mira'), isFalse);
      expect(MentionRules.mentions('Hi @Mira!', 'Mira'), isTrue);
      expect(MentionRules.mentions('a@Mira', 'Mira'), isFalse);
    });

    test('self-mentions notify nobody', () {
      expect(MentionRules.recipients({'you': 'You', 'mira': 'Mira'}, 'you'), {
        'mira',
      });
      expect(MentionRules.recipients({'you': 'You'}, 'you'), isEmpty);
    });

    test('segments mark each mention, longest name first', () {
      expect(
        MentionRules.segments('Hi @Mona Rao and @Mona!', ['Mona', 'Mona Rao']),
        [
          (text: 'Hi ', mention: false),
          (text: '@Mona Rao', mention: true),
          (text: ' and ', mention: false),
          (text: '@Mona', mention: true),
          (text: '!', mention: false),
        ],
      );
      expect(MentionRules.segments('plain', const []), [
        (text: 'plain', mention: false),
      ]);
    });
  });

  group('ForwardRules', () {
    test('text and shared cards only', () {
      expect(ForwardRules.canForward(message()).allowed, isTrue);
      expect(
        ForwardRules.canForward(
          message(text: '', shared: const SharedContent.memory('table')),
        ).allowed,
        isTrue,
      );
      final poll = PollRules.create(
        const PollDraft(question: 'Lunch?', options: ['Yes', 'No']),
        id: 'p',
        createdBy: 'mira',
        now: fixed,
      );
      expect(
        ForwardRules.canForward(message(text: '', poll: poll)).reason,
        'Polls can’t be forwarded.',
      );
      expect(
        ForwardRules.canForward(
          message(
            text: '',
            photos: const [MemoryPhoto(id: 'p', scene: MemoryScene.hillTrip)],
          ),
        ).allowed,
        isFalse,
      );
      expect(
        ForwardRules.canForward(message(unsentAt: fixed)).reason,
        'This message was unsent.',
      );
    });

    test('one to five different chats', () {
      expect(ForwardRules.checkTargets(const []).allowed, isFalse);
      expect(ForwardRules.checkTargets(['a', 'a']).allowed, isTrue);
      expect(
        ForwardRules.checkTargets(['a', 'b', 'c', 'd', 'e']).allowed,
        isTrue,
      );
      expect(
        ForwardRules.checkTargets(['a', 'b', 'c', 'd', 'e', 'f']).reason,
        'Forward to up to 5 chats at once.',
      );
    });

    test('skips chats you can’t post in and cards not everyone can see', () {
      expect(
        ForwardRules.skipReason(
          canPost: false,
          shared: null,
          everyoneCanSee: true,
        ),
        'you can’t send messages there right now',
      );
      expect(
        ForwardRules.skipReason(
          canPost: true,
          shared: const SharedContent.memory('m'),
          everyoneCanSee: false,
        ),
        'not everyone there can see this Memory',
      );
      expect(
        ForwardRules.skipReason(
          canPost: true,
          shared: const SharedContent.event('e'),
          everyoneCanSee: false,
        ),
        'not everyone there can see this event',
      );
      expect(
        ForwardRules.skipReason(
          canPost: true,
          shared: null,
          everyoneCanSee: false,
        ),
        isNull,
        reason: 'plain text can go anywhere you can post',
      );
      expect(
        ForwardRules.summary(
          ForwardResult(
            sentTo: ['d-mira-you'],
            sentTitles: ['Mira'],
            skipped: const [
              ForwardSkip(
                conversationId: 'g-work',
                title: 'Studio North',
                reason: 'not everyone there can see this Memory',
              ),
            ],
          ),
        ),
        'Forwarded to Mira. Not sent to Studio North: not everyone there '
        'can see this Memory.',
      );
    });

    test('photos in chat: up to 10', () {
      expect(ChatPhotoRules.check(10).allowed, isTrue);
      expect(ChatPhotoRules.check(11).allowed, isFalse);
      expect(ChatRules.checkText('', hasAttachment: true).allowed, isTrue);
    });
  });

  group('album cover and captions', () {
    AlbumPhoto photo(String id, String by) => AlbumPhoto(
      photo: MemoryPhoto(id: id, scene: MemoryScene.hillTrip),
      addedBy: by,
      addedAt: fixed,
    );
    final album = Album(
      id: 'a',
      groupId: 'g',
      title: 'Album',
      createdBy: 'mira',
      createdAt: fixed,
      photos: [photo('p1', 'dev'), photo('p2', 'you')],
    );

    test('the creator or admins choose the cover; first photo by default', () {
      expect(album.cover!.id, 'p1');
      expect(AlbumRules.isCover(album, 'p1'), isTrue);
      bool can(String actor, {bool admin = false, bool member = true}) =>
          AlbumRules.canSetCover(
            album,
            actor,
            isMember: member,
            isAdmin: admin,
          ).allowed;
      expect(can('mira'), isTrue);
      expect(can('you', admin: true), isTrue);
      expect(can('you'), isFalse);
      expect(can('mira', member: false), isFalse);
      final chosen = Album(
        id: 'a',
        groupId: 'g',
        title: 'Album',
        createdBy: 'mira',
        createdAt: fixed,
        photos: album.photos,
        coverPhotoId: 'p2',
      );
      expect(chosen.cover!.id, 'p2');
    });

    test('captions: the adder or admins, up to 140 characters', () {
      bool can(String actor, {bool admin = false}) => AlbumRules.canEditCaption(
        album.photos.last,
        actor,
        isMember: true,
        isAdmin: admin,
      ).allowed;
      expect(can('you'), isTrue);
      expect(can('dev'), isFalse);
      expect(can('dev', admin: true), isTrue);
      expect(AlbumRules.checkCaption('x' * 140).allowed, isTrue);
      expect(
        AlbumRules.checkCaption('x' * 141).reason,
        'Keep captions to 140 characters.',
      );
      expect(PhotoCaptionRules.clean('  '), isNull);
      expect(PhotoCaptionRules.clean(' Lake '), 'Lake');
      expect(
        const MemoryPhoto(
          id: 'p',
          scene: MemoryScene.hillTrip,
          caption: 'Old',
        ).withCaption(null).caption,
        isNull,
      );
    });
  });
}
