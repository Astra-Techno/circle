import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/albums/data/mock_album_repository.dart';
import 'package:mobile/features/chat/data/mock_chat_repository.dart';
import 'package:mobile/features/chat/domain/chat_repository.dart';
import 'package:mobile/features/notifications/data/mock_notification_repository.dart';
import 'package:mobile/features/notifications/domain/notification_repository.dart';
import 'package:mobile/features/workspace/data/mock_circle_repository.dart';

final fixed = DateTime.utc(2026, 10, 23, 12);

Matcher failsWith(String text) => throwsA(
  isA<CircleFailure>().having((f) => f.message, 'message', contains(text)),
);

int _id = 0;
String client() => 'deferred-${++_id}';

({
  MockCircleRepository groups,
  MockChatRepository chat,
  MockNotificationRepository notifications,
  MockAlbumRepository albums,
})
setup() {
  final groups = MockCircleRepository(showcase: true, now: () => fixed);
  final chat = MockChatRepository(
    groups: groups,
    showcase: true,
    now: () => fixed,
  );
  return (
    groups: groups,
    chat: chat,
    notifications: MockNotificationRepository(
      groups: groups,
      chat: chat,
      showcase: true,
      now: () => fixed,
    ),
    albums: MockAlbumRepository(
      groups: groups,
      showcase: true,
      now: () => fixed,
    ),
  );
}

Future<MessageView> lastMessage(
  MockChatRepository chat,
  String conversation, {
  String viewer = 'you',
}) async => (await chat.conversation(viewer, conversation)).messages.last;

Future<Set<String>> activityIds(
  MockNotificationRepository notifications,
  String viewer,
) async => {
  for (final entry in (await notifications.activity(viewer)).entries)
    entry.item.id,
};

void main() {
  group('@mentions', () {
    test('only members of the exact group are kept, in group chats', () async {
      final s = setup();
      await s.chat.send(
        'you',
        'g-family',
        clientMessageId: client(),
        text: '@Mira and @Lena, lunch?',
        mentions: {'mira': 'Mira', 'lena': 'Lena'},
      );
      final sent = await lastMessage(s.chat, 'g-family');
      expect(sent.mentions, {'mira': 'Mira'}, reason: 'Lena isn’t in family');

      // 1:1 chats have no mentions.
      await s.chat.send(
        'you',
        'd-mira-you',
        clientMessageId: client(),
        text: '@Mira hi',
        mentions: {'mira': 'Mira'},
      );
      expect((await lastMessage(s.chat, 'd-mira-you')).mentions, isEmpty);
    });

    test('a removed member can’t be mentioned any more', () async {
      final s = setup();
      await s.groups.removeMember('you', 'family', 'dev');
      await s.chat.send(
        'you',
        'g-family',
        clientMessageId: client(),
        text: '@Dev are you coming?',
        mentions: {'dev': 'Dev'},
      );
      expect((await lastMessage(s.chat, 'g-family')).mentions, isEmpty);
    });

    test('a mention is an Activity item for that person only', () async {
      final s = setup();
      final id = await s.chat.send(
        'you',
        'g-family',
        clientMessageId: client(),
        text: '@Mira can you bring the pot? @You will help.',
        mentions: {'mira': 'Mira', 'you': 'You'},
      );
      final mira = await s.notifications.activity('mira');
      final item = mira.entries.firstWhere((e) => e.item.id == 'mention:$id');
      expect(item.item.kind, ActivityKind.mention);
      expect(item.item.text, startsWith('You mentioned you in The Sunday'));
      expect(item.badged, isTrue, reason: 'mentions are personal');
      // A self-mention notifies nobody.
      expect(await activityIds(s.notifications, 'you'), isNot(contains(id)));
      expect(
        (await activityIds(
          s.notifications,
          'you',
        )).any((i) => i == 'mention:$id'),
        isFalse,
      );
      // Dev is in the group but wasn't mentioned.
      expect(await activityIds(s.notifications, 'dev'), isNot(contains(id)));
    });

    test('someone who blocked the author gets no mention', () async {
      final s = setup();
      await s.chat.block('mira', 'you');
      final id = await s.chat.send(
        'you',
        'g-family',
        clientMessageId: client(),
        text: '@Mira hello',
        mentions: {'mira': 'Mira'},
      );
      expect(
        await activityIds(s.notifications, 'mira'),
        isNot(contains('mention:$id')),
      );
    });

    test(
      'the seeded mentions are real, personal and follow settings',
      () async {
        final s = setup();
        var feed = await s.notifications.activity('you');
        ActivityEntry entry(String id) =>
            feed.entries.firstWhere((e) => e.item.id == id);
        // Sam in Northbank 2009 (57 members, mentions only) and Tomas's
        // comment on a Sunday miles Memory.
        expect(
          entry('mention:college-mention').item.kind,
          ActivityKind.mention,
        );
        expect(entry('mention:college-mention').badged, isTrue);
        expect(entry('mention:ride-comment-1').badged, isTrue);
        expect(
          entry('mention:ride-comment-1').item.target.kind,
          ActivityTargetKind.memory,
        );
        // Turning off pushes for mentions keeps them in Activity, unbadged.
        await s.notifications.setPush(
          'you',
          NotificationType.mentionsAndReplies,
          false,
        );
        feed = await s.notifications.activity('you');
        expect(entry('mention:college-mention').badged, isFalse);
        expect(entry('mention:college-mention').delivery, Delivery.digest);
      },
    );

    test('comments keep exact-group mentions and notify once', () async {
      final s = setup();
      final id = await s.groups.comment(
        'you',
        'table',
        'Agreed @Mira, and @Lena too',
        mentions: {'mira': 'Mira', 'lena': 'Lena'},
      );
      final memory = (await s.groups.load(
        'you',
      )).memories.firstWhere((m) => m.id == 'table');
      final comment = memory.comments.firstWhere((c) => c.id == id);
      expect(comment.mentions, {'mira': 'Mira'});
      // It's Mira's Memory too: one mention item, no separate "commented".
      final ids = await activityIds(s.notifications, 'mira');
      expect(ids, contains('mention:$id'));
      expect(ids, isNot(contains('reply:$id')));
    });

    test('editing out a name drops the mention', () async {
      final s = setup();
      final id = await s.chat.send(
        'you',
        'g-family',
        clientMessageId: client(),
        text: '@Mira hello',
        mentions: {'mira': 'Mira'},
      );
      await s.chat.edit('you', 'g-family', id, 'Hello everyone');
      expect((await lastMessage(s.chat, 'g-family')).mentions, isEmpty);
    });
  });

  group('photos in chat', () {
    test('send up to 10 fictional photos; react, reply and unsend', () async {
      final s = setup();
      final id = await s.chat.send(
        'you',
        'g-family',
        clientMessageId: client(),
        photos: const [MemoryScene.sundayLunch, MemoryScene.birthdayCake],
      );
      var sent = await lastMessage(s.chat, 'g-family');
      expect(sent.photos.map((p) => p.scene), [
        MemoryScene.sundayLunch,
        MemoryScene.birthdayCake,
      ]);
      expect(sent.summary, 'Sent 2 photos');
      expect(sent.canForward, isFalse, reason: 'photos aren’t forwardable');
      expect((await s.chat.inbox('you')).chats.first.preview, isNotEmpty);
      await s.chat.react('mira', 'g-family', id, '❤️');
      await s.chat.send(
        'mira',
        'g-family',
        clientMessageId: client(),
        text: 'Lovely!',
        replyToId: id,
      );
      sent = (await s.chat.conversation(
        'you',
        'g-family',
      )).messages.firstWhere((m) => m.id == id);
      expect(sent.reactions.total, 1);
      final reply = await lastMessage(s.chat, 'g-family');
      expect(reply.replyTo!.text, 'Sent 2 photos');
      await s.chat.unsend('you', 'g-family', id);
      sent = (await s.chat.conversation(
        'mira',
        'g-family',
      )).messages.firstWhere((m) => m.id == id);
      expect(sent.photos, isEmpty, reason: 'unsent for everyone');
      await expectLater(
        s.chat.send(
          'you',
          'g-family',
          clientMessageId: client(),
          photos: List.filled(11, MemoryScene.hillTrip),
        ),
        failsWith('up to 10 photos'),
      );
    });
  });

  group('forwarding', () {
    Future<String> sharedMemoryMessage(MockChatRepository chat) async =>
        (await chat.conversation(
          'you',
          'g-family',
        )).messages.firstWhere((m) => m.shared != null).id;

    test('a shared Memory skips chats where not everyone can see it', () async {
      final s = setup();
      final id = await sharedMemoryMessage(s.chat);
      final result = await s.chat.forward(
        'you',
        'g-family',
        id,
        to: ['d-mira-you', 'g-work'],
        clientMessageId: 'fwd-1',
      );
      expect(result.sentTo, ['d-mira-you']);
      expect(result.skipped.single.title, 'Studio North');
      expect(
        result.skipped.single.reason,
        'not everyone there can see this Memory',
      );
      final copy = await lastMessage(s.chat, 'd-mira-you');
      expect(copy.forwarded, isTrue);
      expect(copy.shared!.content, const SharedContent.memory('table'));
      expect(copy.shared!.visible, isTrue);
      expect(copy.mentions, isEmpty);
      final work = await lastMessage(s.chat, 'g-work');
      expect(work.forwarded, isFalse, reason: 'nothing arrived there');

      // Retrying the same forward never sends twice.
      final count = (await s.chat.conversation(
        'you',
        'd-mira-you',
      )).messages.length;
      await s.chat.forward(
        'you',
        'g-family',
        id,
        to: ['d-mira-you'],
        clientMessageId: 'fwd-1',
      );
      expect(
        (await s.chat.conversation('you', 'd-mira-you')).messages,
        hasLength(count),
      );
    });

    test('text goes anywhere you can post; never where you can’t', () async {
      final s = setup();
      final id = await s.chat.send(
        'you',
        'g-family',
        clientMessageId: client(),
        text: 'Lunch at one?',
      );
      await s.chat.block('you', 'dev');
      await s.groups.leaveGroup('you', 'friends');
      final result = await s.chat.forward(
        'you',
        'g-family',
        id,
        to: ['g-work', 'd-dev-you', 'g-friends'],
        clientMessageId: 'fwd-2',
      );
      expect(result.sentTo, ['g-work']);
      expect(result.skipped.map((skip) => skip.conversationId), [
        'd-dev-you',
        'g-friends',
      ]);
      expect(
        result.skipped.first.reason,
        'you can’t send messages there right now',
      );
      expect((await lastMessage(s.chat, 'g-work')).text, 'Lunch at one?');
      expect(
        (await s.chat.inbox(
          'you',
        )).chats.firstWhere((c) => c.id == 'g-work').canPost,
        isTrue,
      );
    });

    test('polls, unsent messages and more than 5 chats are refused', () async {
      final s = setup();
      final poll = (await s.chat.conversation(
        'you',
        'g-work',
      )).messages.firstWhere((m) => m.poll != null);
      expect(poll.canForward, isFalse);
      await expectLater(
        s.chat.forward(
          'you',
          'g-work',
          poll.id,
          to: ['d-mira-you'],
          clientMessageId: client(),
        ),
        failsWith('Polls can’t be forwarded.'),
      );
      final id = await s.chat.send(
        'you',
        'g-family',
        clientMessageId: client(),
        text: 'Oops',
      );
      await expectLater(
        s.chat.forward(
          'you',
          'g-family',
          id,
          to: ['g-work', 'g-family', 'g-cse', 'g-club', 'g-section', 'g-trip'],
          clientMessageId: client(),
        ),
        failsWith('up to 5 chats'),
      );
      await s.chat.unsend('you', 'g-family', id);
      await expectLater(
        s.chat.forward(
          'you',
          'g-family',
          id,
          to: ['g-work'],
          clientMessageId: client(),
        ),
        failsWith('unsent'),
      );
    });
  });

  group('album cover and captions', () {
    test('the creator sets the cover; others can’t', () async {
      final s = setup();
      // "Ride days" was made by the viewer.
      await s.albums.setCover('you', 'ride-days', 'ride-days-photo-2');
      final album = await s.albums.album('you', 'ride-days');
      expect(album.cover!.id, 'ride-days-photo-2');
      expect(album.coverPhotoId, 'ride-days-photo-2');
      expect(
        (await s.albums.albums('you', 'club')).first.cover!.id,
        'ride-days-photo-2',
        reason: 'the grid uses the chosen cover',
      );
      // Mira's "Sunday lunches": the viewer owns the family group, so as
      // an admin they may; Dev (a plain member) may not.
      await expectLater(
        s.albums.setCover('dev', 'sunday-lunches', 'sunday-lunches-photo-2'),
        failsWith('choose its cover'),
      );
      await s.albums.setCover(
        'you',
        'sunday-lunches',
        'sunday-lunches-photo-2',
      );
      await expectLater(
        s.albums.setCover('you', 'ride-days', 'missing'),
        failsWith('no longer here'),
      );
    });

    test('captions: the photo’s adder or admins, up to 140', () async {
      final s = setup();
      // Breakfast by the water was added by Mira.
      await s.albums.setCaption(
        'mira',
        'ride-days',
        'ride-days-photo-2',
        '  Coffee first  ',
      );
      var photo = (await s.albums.album(
        'you',
        'ride-days',
      )).photos.firstWhere((p) => p.id == 'ride-days-photo-2');
      expect(photo.photo.caption, 'Coffee first');
      await expectLater(
        s.albums.setCaption('tomas', 'ride-days', 'ride-days-photo-2', 'Mine'),
        failsWith('caption it'),
      );
      await expectLater(
        s.albums.setCaption(
          'mira',
          'ride-days',
          'ride-days-photo-2',
          'x' * 141,
        ),
        failsWith('140 characters'),
      );
      // The owner (an admin) clears it.
      await s.albums.setCaption('you', 'ride-days', 'ride-days-photo-2', ' ');
      photo = (await s.albums.album(
        'you',
        'ride-days',
      )).photos.firstWhere((p) => p.id == 'ride-days-photo-2');
      expect(photo.photo.caption, isNull);
    });

    test('Memory photos can carry captions in the preview', () async {
      final s = setup();
      final id = await s.groups.createMemory(
        'you',
        'family',
        '',
        photos: const [MemoryScene.sundayLunch, MemoryScene.beachWalk],
        captions: const ['  Grandma’s table ', null],
      );
      final memory = (await s.groups.load(
        'you',
      )).memories.firstWhere((m) => m.id == id);
      expect(memory.photos.map((p) => p.caption), ['Grandma’s table', null]);
      await expectLater(
        s.groups.createMemory(
          'you',
          'family',
          '',
          photos: const [MemoryScene.sundayLunch],
          captions: ['x' * 141],
        ),
        failsWith('140 characters'),
      );
    });
  });
}
