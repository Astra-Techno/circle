import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/data/mock_chat_repository.dart';
import 'package:mobile/features/chat/domain/chat_repository.dart';
import 'support/mock_circle_repository.dart';

Matcher failsWith(String text) => throwsA(
  isA<CircleFailure>().having((f) => f.message, 'message', contains(text)),
);

/// A movable clock shared by both mock repositories.
class Clock {
  DateTime now = DateTime.utc(2026, 10, 23, 12);
  DateTime call() => now;
  void advance(Duration by) => now = now.add(by);
}

({MockCircleRepository groups, MockChatRepository chat, Clock clock}) setup({
  bool showcase = true,
}) {
  final clock = Clock();
  final groups = MockCircleRepository(showcase: showcase, now: clock.call);
  final chat = MockChatRepository(
    groups: groups,
    showcase: showcase,
    now: clock.call,
  );
  return (groups: groups, chat: chat, clock: clock);
}

int _id = 0;
String client() => 'test-${++_id}';

void main() {
  group('seeded inbox', () {
    test(
      'Chats, Requests and Archived with pin, unread and quiet groups',
      () async {
        final repo = setup().chat;
        final inbox = await repo.inbox('you');
        expect(inbox.chats.first.id, 'd-mira-you', reason: 'pinned first');
        expect(inbox.chats.first.pinned, isTrue);
        expect(inbox.requests.map((c) => c.id), ['d-kavya-you']);
        expect(inbox.requests.single.unread, isTrue);
        expect(inbox.archived.map((c) => c.id), ['d-lena-you']);
        final ids = inbox.chats.map((c) => c.id).toList();
        // A chat for every group the viewer is in, and nothing else's.
        for (final group in [
          'family',
          'college',
          'cse',
          'section',
          'friends',
        ]) {
          expect(ids, contains('g-$group'));
        }
        expect(ids, isNot(contains('g-private-plans')));
        final college = inbox.chats.firstWhere((c) => c.id == 'g-college');
        expect(college.memberCount, 57);
        expect(college.muted, isTrue, reason: 'big groups are quiet');
        expect(college.unread, isTrue);
        final family = inbox.chats.firstWhere((c) => c.id == 'g-family');
        expect(family.unread, isFalse);
        expect(family.preview, 'Seen by Mira, Dev');
        final mira = inbox.chats.firstWhere((c) => c.id == 'd-mira-you');
        expect(mira.preview, 'Seen');
        final dev = inbox.chats.firstWhere((c) => c.id == 'd-dev-you');
        expect(dev.unread, isTrue);
        expect(dev.preview, startsWith('Lunch next week?'));
      },
    );

    test(
      'conversation status and the request sender never sees Seen',
      () async {
        final repo = setup().chat;
        final family = await repo.conversation('you', 'g-family');
        expect(family.status, 'Seen by Mira, Dev');
        expect(family.statusSemantics, 'Seen by 2 people: Mira and Dev');
        expect(family.members.length, 4);
        // Kavya's request: read by you, but not accepted.
        await repo.markRead('you', 'd-kavya-you');
        expect(
          (await repo.conversation('kavya', 'd-kavya-you')).status,
          'Sent',
        );
        final request = await repo.conversation('you', 'd-kavya-you');
        expect(request.mode, ConversationMode.incomingRequest);
        expect(request.sharedGroups, ['Northbank 2009']);
        await expectLater(
          repo.send(
            'you',
            'd-kavya-you',
            clientMessageId: client(),
            text: 'Hi',
          ),
          failsWith('Accept the request'),
        );
        await repo.acceptRequest('you', 'd-kavya-you');
        await repo.markRead('you', 'd-kavya-you');
        expect(
          (await repo.conversation('kavya', 'd-kavya-you')).status,
          'Seen',
        );
        expect((await repo.inbox('you')).requests, isEmpty);
      },
    );

    test(
      'activity stays hidden both ways until a request is accepted',
      () async {
        final repo = setup().chat;
        // Both people use the app now, so both would read "Active now".
        await repo.inbox('kavya');
        await repo.inbox('you');
        expect(
          (await repo.conversation('you', 'd-kavya-you')).activity,
          isNull,
        );
        expect(
          (await repo.conversation('kavya', 'd-kavya-you')).activity,
          isNull,
        );
        await repo.acceptRequest('you', 'd-kavya-you');
        expect(
          (await repo.conversation('you', 'd-kavya-you')).activity,
          'Active now',
        );
        expect(
          (await repo.conversation('kavya', 'd-kavya-you')).activity,
          'Active now',
        );
      },
    );
  });

  group('requests and close groups', () {
    test('first DM from a big-group-only contact waits in Requests', () async {
      final repo = setup().chat;
      final id = await repo.openDirect('asha', 'you');
      await repo.send('asha', id, clientMessageId: client(), text: 'Hello!');
      final inbox = await repo.inbox('you');
      expect(inbox.requests.map((c) => c.id), contains('d-asha-you'));
      expect(inbox.chats.map((c) => c.id), isNot(contains('d-asha-you')));
    });

    test('someone from a close group lands in Chats', () async {
      final repo = setup().chat;
      final id = await repo.openDirect('priya', 'you');
      await repo.send('priya', id, clientMessageId: client(), text: 'Hi!');
      final inbox = await repo.inbox('you');
      expect(inbox.chats.map((c) => c.id), contains('d-priya-you'));
      expect(inbox.requests.map((c) => c.id), isNot(contains('d-priya-you')));
    });

    test('custom close groups change where first messages land', () async {
      final repo = setup().chat;
      await repo.setCloseGroup('you', 'college', true);
      await repo.setCloseGroup('you', 'family', false);
      final asha = await repo.openDirect('asha', 'you');
      await repo.send('asha', asha, clientMessageId: client(), text: 'Hi');
      final priya = await repo.openDirect('priya', 'you');
      await repo.send('priya', priya, clientMessageId: client(), text: 'Hi');
      final inbox = await repo.inbox('you');
      expect(inbox.chats.map((c) => c.id), contains('d-asha-you'));
      expect(inbox.requests.map((c) => c.id), contains('d-priya-you'));
      await expectLater(
        repo.setCloseGroup('you', 'private-plans', true),
        throwsA(isA<CircleFailure>()),
      );
    });

    test(
      'delete hides a request with Undo; a new message brings it back',
      () async {
        final setupResult = setup();
        final repo = setupResult.chat;
        await repo.deleteRequest('you', 'd-kavya-you');
        expect((await repo.inbox('you')).requests, isEmpty);
        await repo.restoreRequest('you', 'd-kavya-you');
        expect((await repo.inbox('you')).requests, hasLength(1));
        await repo.deleteRequest('you', 'd-kavya-you');
        setupResult.clock.advance(const Duration(minutes: 1));
        await repo.send(
          'kavya',
          'd-kavya-you',
          clientMessageId: client(),
          text: 'Sorry, one more thing!',
        );
        expect((await repo.inbox('you')).requests, hasLength(1));
      },
    );
  });

  group('who can message and blocks', () {
    test('settings decide who can start a chat', () async {
      final repo = setup().chat;
      await expectLater(
        repo.openDirect('you', 'noor'),
        failsWith('only accepts messages from people they’ve chatted with'),
      );
      await expectLater(
        repo.openDirect('you', 'tomas'),
        failsWith('isn’t accepting'),
      );
      // Once Noor writes first, you may reply.
      final id = await repo.openDirect('noor', 'you');
      await repo.send('noor', id, clientMessageId: client(), text: 'Hi!');
      await repo.acceptRequest('you', id);
      await repo.send('you', id, clientMessageId: client(), text: 'Hello!');
      final contacts = await repo.contacts('you');
      final college = contacts.firstWhere((g) => g.group.id == 'college');
      ChatContact contact(String id) =>
          college.contacts.firstWhere((c) => c.personId == id);
      expect(contact('noor').canMessage, isTrue);
      expect(contact('dev').canMessage, isTrue);
      expect(
        contacts
            .expand((g) => g.contacts)
            .any((c) => c.personId == 'tomas' && c.canMessage),
        isFalse,
      );
    });

    test('"Nobody" stops even people you chatted with', () async {
      final repo = setup().chat;
      await repo.setWhoCanMessage('you', WhoCanMessage.nobody);
      await expectLater(
        repo.send('mira', 'd-mira-you', clientMessageId: client(), text: 'Hi'),
        failsWith('isn’t accepting'),
      );
      expect(
        (await repo.conversation('mira', 'd-mira-you')).mode,
        ConversationMode.cannotReply,
      );
    });

    test('blocking works both ways; blocked requests vanish', () async {
      final repo = setup().chat;
      await repo.block('you', 'kavya');
      expect((await repo.inbox('you')).requests, isEmpty);
      await expectLater(
        repo.send('kavya', 'd-kavya-you', clientMessageId: client(), text: 'x'),
        failsWith('isn’t accepting'),
      );
      await expectLater(
        repo.openDirect('kavya', 'you'),
        failsWith('isn’t accepting'),
      );
      await expectLater(
        repo.openDirect('you', 'kavya'),
        failsWith('You blocked Kavya'),
      );
      expect((await repo.privacy('you')).blocked.single.name, 'Kavya');
      await repo.unblock('you', 'kavya');
      expect((await repo.inbox('you')).requests, hasLength(1));

      await repo.block('mira', 'you');
      await expectLater(
        repo.openDirect('you', 'mira'),
        failsWith('isn’t accepting'),
      );
      expect(
        (await repo.conversation('you', 'd-mira-you')).mode,
        ConversationMode.cannotReply,
      );
      await expectLater(
        repo.block('you', 'stranger'),
        throwsA(isA<CircleFailure>()),
      );
    });

    test('group chats hide messages from people you blocked', () async {
      final repo = setup().chat;
      await repo.block('you', 'kavya');
      final college = await repo.conversation('you', 'g-college');
      final hidden = college.messages.firstWhere((m) => m.authorId == 'kavya');
      expect(hidden.hidden, isTrue);
      expect(hidden.text, isEmpty);
    });
  });

  group('messages', () {
    test('send is idempotent by client message id', () async {
      final repo = setup().chat;
      final first = await repo.send(
        'you',
        'd-mira-you',
        clientMessageId: 'same',
        text: 'Once',
      );
      final again = await repo.send(
        'you',
        'd-mira-you',
        clientMessageId: 'same',
        text: 'Once',
      );
      expect(again, first);
      final view = await repo.conversation('you', 'd-mira-you');
      expect(view.messages.where((m) => m.text == 'Once'), hasLength(1));
      expect(view.status, 'Sent');
      await expectLater(
        repo.send('you', 'd-mira-you', clientMessageId: client(), text: '  '),
        failsWith('Write a message first'),
      );
    });

    test('edit within 15 minutes, not after', () async {
      final s = setup();
      final id = await s.chat.send(
        'you',
        'd-mira-you',
        clientMessageId: client(),
        text: 'Typo',
      );
      s.clock.advance(const Duration(minutes: 10));
      await s.chat.edit('you', 'd-mira-you', id, 'Fixed');
      var message = (await s.chat.conversation(
        'mira',
        'd-mira-you',
      )).messages.last;
      expect(message.text, 'Fixed');
      expect(message.edited, isTrue);
      final own = (await s.chat.conversation(
        'you',
        'd-mira-you',
      )).messages.last;
      expect(own.canEditAt(s.clock.now), isTrue);
      expect(
        own.canEditAt(s.clock.now.add(const Duration(minutes: 6))),
        isFalse,
      );
      await expectLater(
        s.chat.edit('mira', 'd-mira-you', id, 'Mine now'),
        failsWith('your own'),
      );
      s.clock.advance(const Duration(minutes: 6));
      await expectLater(
        s.chat.edit('you', 'd-mira-you', id, 'Late'),
        failsWith('15 minutes'),
      );
      message = (await s.chat.conversation('you', 'd-mira-you')).messages.last;
      expect(message.canEditAt(s.clock.now), isFalse);
      expect(message.editableUntil, isNull);
      expect(message.canUnsend, isTrue);
    });

    test(
      'unsend shows a placeholder for everyone; restore undoes it',
      () async {
        final repo = setup().chat;
        final id = await repo.send(
          'you',
          'd-mira-you',
          clientMessageId: client(),
          text: 'Oops',
        );
        await expectLater(
          repo.unsend('mira', 'd-mira-you', id),
          failsWith('your own'),
        );
        await repo.unsend('you', 'd-mira-you', id);
        final seen = (await repo.conversation(
          'mira',
          'd-mira-you',
        )).messages.last;
        expect(seen.unsent, isTrue);
        expect(seen.text, isEmpty);
        expect(seen.summary, 'Message unsent');
        await repo.restore('you', 'd-mira-you', id);
        expect(
          (await repo.conversation('mira', 'd-mira-you')).messages.last.text,
          'Oops',
        );
      },
    );

    test('reactions: allowlist, one per person, toggle', () async {
      final repo = setup().chat;
      final view = await repo.conversation('you', 'd-mira-you');
      final first = view.messages.first.id;
      await expectLater(
        repo.react('you', 'd-mira-you', first, '👋'),
        failsWith('reaction'),
      );
      await repo.react('you', 'd-mira-you', first, '❤️');
      await repo.react('you', 'd-mira-you', first, '😂');
      var reactions = (await repo.conversation(
        'you',
        'd-mira-you',
      )).messages.first.reactions;
      expect(reactions.mine, '😂');
      expect(reactions.total, 1);
      await repo.react('you', 'd-mira-you', first, '😂');
      reactions = (await repo.conversation(
        'you',
        'd-mira-you',
      )).messages.first.reactions;
      expect(reactions.total, 0);
    });

    test('replies quote the original message', () async {
      final repo = setup().chat;
      final view = await repo.conversation('you', 'd-mira-you');
      final walk = view.messages.firstWhere((m) => m.text.contains('walk'));
      final reply = view.messages.last;
      expect(reply.replyTo?.messageId, walk.id);
      expect(reply.replyTo?.authorName, 'Mira');
    });

    test('polls in chat use the Memories poll rules', () async {
      final repo = setup().chat;
      await expectLater(
        repo.send(
          'you',
          'd-mira-you',
          clientMessageId: client(),
          poll: const PollDraft(question: 'One?', options: ['Only']),
        ),
        failsWith('2–12 options'),
      );
      final id = await repo.send(
        'you',
        'd-mira-you',
        clientMessageId: client(),
        poll: const PollDraft(
          question: 'Tea or coffee?',
          options: ['Tea', 'Coffee'],
          resultsVisibility: PollResultsVisibility.always,
        ),
      );
      final poll = (await repo.conversation(
        'mira',
        'd-mira-you',
      )).messages.last.poll!;
      await repo.votePoll('mira', 'd-mira-you', id, {poll.options.last.id});
      final mine = (await repo.conversation(
        'you',
        'd-mira-you',
      )).messages.last.poll!;
      expect(mine.totalVoters, 1);
      expect(mine.options.last.voters, ['Mira']);
      await repo.closePoll('you', 'd-mira-you', id);
      await expectLater(
        repo.votePoll('you', 'd-mira-you', id, {poll.options.first.id}),
        failsWith('closed'),
      );
    });
  });

  group('membership', () {
    test(
      'exact membership: no chats of groups or 1:1s you are not in',
      () async {
        final repo = setup().chat;
        for (final id in [
          'g-private-plans',
          'g-recipes',
          'g-unknown',
          'd-dev-mira',
          'x',
        ]) {
          await expectLater(
            repo.conversation('you', id),
            failsWith('isn’t shared with you'),
            reason: id,
          );
          await expectLater(
            repo.send('you', id, clientMessageId: client(), text: 'Hi'),
            failsWith('isn’t shared with you'),
            reason: id,
          );
        }
        await expectLater(
          repo.markRead('you', 'g-private-plans'),
          throwsA(isA<CircleFailure>()),
        );
        await expectLater(
          repo.setPinned('you', 'd-dev-mira', true),
          throwsA(isA<CircleFailure>()),
        );
        // Mira can read the subgroup chat she is in; access isn't inherited
        // from the parent group.
        expect(
          (await repo.conversation('mira', 'g-private-plans')).isGroup,
          isTrue,
        );
        await expectLater(
          repo.conversation('priya', 'g-private-plans'),
          throwsA(isA<CircleFailure>()),
        );
        await expectLater(
          repo.openDirect('you', 'arjun'),
          failsWith('share a group'),
        );
      },
    );

    test(
      'leaving a group makes its chat read-only up to that moment',
      () async {
        final s = setup();
        await s.chat.send(
          'you',
          'g-work',
          clientMessageId: client(),
          text: 'Before',
        );
        s.clock.advance(const Duration(minutes: 1));
        await s.groups.leaveGroup('you', 'work');
        final view = await s.chat.conversation('you', 'g-work');
        expect(view.mode, ConversationMode.leftGroup);
        s.clock.advance(const Duration(minutes: 1));
        await s.chat.send(
          'dev',
          'g-work',
          clientMessageId: client(),
          text: 'After',
        );
        final after = await s.chat.conversation('you', 'g-work');
        expect(after.messages.map((m) => m.text), contains('Before'));
        expect(after.messages.map((m) => m.text), isNot(contains('After')));
        await expectLater(
          s.chat.send('you', 'g-work', clientMessageId: client(), text: 'x'),
          failsWith('You left this group'),
        );
        final summary = (await s.chat.inbox(
          'you',
        )).chats.firstWhere((c) => c.id == 'g-work');
        expect(summary.readOnly, isTrue);
        expect(summary.preview, 'You left this group');
      },
    );

    test('shared content is re-checked for each reader', () async {
      final repo = setup().chat;
      final mine = await repo.conversation('you', 'd-dev-you');
      final card = mine.messages.first.shared!;
      expect(card.visible, isFalse);
      expect(card.memory, isNull);
      final devs = await repo.conversation('dev', 'd-dev-you');
      expect(devs.messages.first.shared!.visible, isTrue);
      // Sharing something you can't see is refused.
      await expectLater(
        repo.send(
          'you',
          'd-mira-you',
          clientMessageId: client(),
          shared: const SharedContent.memory('private-memory'),
        ),
        failsWith('things you can see'),
      );
      final family = await repo.conversation('you', 'g-family');
      expect(family.sharedItems.single.memory?.id, 'table');
      final college = await repo.conversation('you', 'g-college');
      expect(college.sharedItems.single.event?.id, 'reunion');
      // Sam isn't in The Sunday table, so it can't be shared with him.
      final id = await repo.openDirect('you', 'sam');
      await expectLater(
        repo.send(
          'you',
          id,
          clientMessageId: client(),
          shared: const SharedContent.memory('table'),
        ),
        failsWith('everyone in this chat can see'),
      );
    });

    test('cards re-check access after membership changes', () async {
      final s = setup();
      final id = await s.chat.openDirect('you', 'priya');
      await s.chat.send(
        'you',
        id,
        clientMessageId: client(),
        shared: const SharedContent.memory('table'),
      );
      final before = await s.chat.conversation('priya', id);
      expect(before.messages.last.shared!.visible, isTrue);
      // Priya is removed from The Sunday table: the old card closes.
      // Priya hands Recipe swap (a subgroup) to Mira first.
      await s.groups.transferOwnership('priya', 'recipes', 'mira');
      await s.groups.removeMember('you', 'family', 'priya');
      final after = await s.chat.conversation('priya', id);
      expect(after.messages.last.shared!.visible, isFalse);
      expect(after.messages.last.shared!.memory, isNull);
    });

    test('only items everyone in the chat can see can be shared', () async {
      final repo = setup().chat;
      // Group chat: Mira, Dev and Priya aren't all in Sunday miles.
      await expectLater(
        repo.send(
          'you',
          'g-family',
          clientMessageId: client(),
          shared: const SharedContent.event('cycling'),
        ),
        failsWith('everyone in this chat can see'),
      );
      await repo.send(
        'you',
        'g-family',
        clientMessageId: client(),
        shared: const SharedContent.event('lunch'),
      );
      // 1:1: Mira isn't in The window-seat crew.
      await expectLater(
        repo.send(
          'you',
          'd-mira-you',
          clientMessageId: client(),
          shared: const SharedContent.memory('old-days'),
        ),
        failsWith('everyone in this chat can see'),
      );
      final family = await repo.conversation('you', 'g-family');
      expect(
        family.participants,
        unorderedEquals(['you', 'mira', 'dev', 'priya']),
      );
      final mira = await repo.conversation('you', 'd-mira-you');
      expect(mira.participants, unorderedEquals(['you', 'mira']));
    });

    test('reset clears every conversation and setting', () async {
      final repo = setup().chat;
      await repo.send(
        'you',
        'd-mira-you',
        clientMessageId: client(),
        text: 'Gone soon',
      );
      await repo.block('you', 'kavya');
      await repo.reset(showcase: false);
      expect((await repo.privacy('you')).blocked, isEmpty);
      await expectLater(
        repo.conversation('you', 'd-mira-you'),
        throwsA(isA<CircleFailure>()),
      );
      await repo.reset(showcase: true);
      final view = await repo.conversation('you', 'd-mira-you');
      expect(view.messages.map((m) => m.text), isNot(contains('Gone soon')));
      expect((await repo.inbox('you')).requests, hasLength(1));
    });

    test('a fresh account starts with no chats', () async {
      final s = setup(showcase: false);
      final inbox = await s.chat.inbox('you');
      expect(inbox.chats, isEmpty);
      expect(inbox.requests, isEmpty);
      expect(await s.chat.contacts('you'), isEmpty);
    });
  });

  group('activity status', () {
    test('1:1 inbox, conversation and contacts show seeded activity', () async {
      final repo = setup().chat;
      final inbox = await repo.inbox('you');
      ConversationSummary row(String id) => [
        ...inbox.chats,
        ...inbox.archived,
        ...inbox.requests,
      ].firstWhere((c) => c.id == id);
      expect(row('d-mira-you').activity, 'Active now');
      expect(row('d-mira-you').activeNow, isTrue);
      expect(row('d-dev-you').activity, 'Active 2h ago');
      expect(row('d-dev-you').activeNow, isFalse);
      expect(row('d-lena-you').activity, 'Active yesterday');
      // Kavya was active 4 days ago: older than 48 hours, nothing shown.
      expect(row('d-kavya-you').activity, isNull);
      // Never in group chats.
      expect(row('g-family').activity, isNull);
      expect(row('g-family').activeNow, isFalse);
      expect((await repo.conversation('you', 'g-family')).activity, isNull);
      expect(
        (await repo.conversation('you', 'd-dev-you')).activity,
        'Active 2h ago',
      );
      final contacts = await repo.contacts('you');
      ChatContact contact(String person) => contacts
          .expand((g) => g.contacts)
          .firstWhere((c) => c.personId == person);
      expect(contact('mira').activity, 'Active now');
      expect(contact('priya').activity, 'Active 35m ago');
      expect(contact('sam').activity, isNull, reason: 'unknown');
    });

    test(
      'labels follow the injected clock; nothing moves on its own',
      () async {
        final s = setup();
        expect(
          (await s.chat.conversation('you', 'd-mira-you')).activity,
          'Active now',
        );
        s.clock.advance(const Duration(minutes: 10));
        expect(
          (await s.chat.conversation('you', 'd-mira-you')).activity,
          'Active 12m ago',
        );
        s.clock.advance(const Duration(hours: 48));
        expect(
          (await s.chat.conversation('you', 'd-mira-you')).activity,
          isNull,
        );
      },
    );

    test('the viewer is active now while using the preview', () async {
      final repo = setup().chat;
      await repo.inbox('you');
      expect(
        (await repo.conversation('mira', 'd-mira-you')).activity,
        'Active now',
      );
    });

    test('turning it off hides it both ways; reset restores it', () async {
      final repo = setup().chat;
      await repo.setShowActivity('you', false);
      expect((await repo.privacy('you')).settings.showActivity, isFalse);
      expect((await repo.conversation('you', 'd-mira-you')).activity, isNull);
      expect((await repo.conversation('mira', 'd-mira-you')).activity, isNull);
      await repo.setShowActivity('you', true);
      await repo.setShowActivity('mira', false);
      expect((await repo.conversation('you', 'd-mira-you')).activity, isNull);
      await repo.reset(showcase: true);
      expect((await repo.privacy('you')).settings.showActivity, isTrue);
      expect(
        (await repo.conversation('you', 'd-mira-you')).activity,
        'Active now',
      );
    });

    test('a block in either direction hides it', () async {
      final repo = setup().chat;
      await repo.block('you', 'dev');
      expect((await repo.conversation('you', 'd-dev-you')).activity, isNull);
      await repo.unblock('you', 'dev');
      await repo.block('dev', 'you');
      expect((await repo.conversation('you', 'd-dev-you')).activity, isNull);
    });

    test('no shared group hides it', () async {
      final s = setup();
      final id = await s.chat.openDirect('you', 'priya');
      expect((await s.chat.conversation('you', id)).activity, isNotNull);
      // Priya hands Recipe swap (a subgroup) to Mira first.
      await s.groups.transferOwnership('priya', 'recipes', 'mira');
      await s.groups.removeMember('you', 'family', 'priya');
      expect((await s.chat.conversation('you', id)).activity, isNull);
    });
  });
}
