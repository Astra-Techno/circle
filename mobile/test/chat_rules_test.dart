import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/chat_rules.dart';

CircleGroup circle(String id, Iterable<String> members) => CircleGroup(
  id: id,
  name: id,
  type: CircleType.friends,
  depth: 1,
  roles: {
    for (final (index, person) in members.indexed)
      person: index == 0 ? CircleRole.owner : CircleRole.member,
  },
);

/// A group of [size] people that includes a and b.
CircleGroup sized(String id, int size) =>
    circle(id, ['a', 'b', for (var i = 2; i < size; i++) '$id-$i']);

ChatMessage message({
  String author = 'a',
  String text = 'Hello',
  DateTime? at,
  DateTime? unsentAt,
  String clientId = 'c1',
}) => ChatMessage(
  id: 'm-$clientId',
  conversationId: 'd-a-b',
  authorId: author,
  clientMessageId: clientId,
  createdAt: at ?? DateTime.utc(2026, 10, 23, 12),
  text: text,
  unsentAt: unsentAt,
);

void main() {
  group('1:1 eligibility', () {
    final shared = [sized('small', 4)];
    DirectEligibility check({
      WhoCanMessage who = WhoCanMessage.everyoneInMyGroups,
      bool chatted = false,
      List<CircleGroup>? groups,
      Set<String> senderBlocked = const {},
      Set<String> recipientBlocked = const {},
      String recipient = 'b',
    }) => ChatRules.directEligibility(
      sender: 'a',
      recipient: recipient,
      shared: groups ?? shared,
      senderPrivacy: ChatPrivacy(blocked: senderBlocked),
      recipientPrivacy: ChatPrivacy(
        whoCanMessage: who,
        blocked: recipientBlocked,
      ),
      haveChatted: chatted,
    );

    test('the full setting × history matrix', () {
      const expected = {
        (WhoCanMessage.everyoneInMyGroups, false): DirectEligibility.allowed,
        (WhoCanMessage.everyoneInMyGroups, true): DirectEligibility.allowed,
        (WhoCanMessage.onlyPeopleIChattedWith, false):
            DirectEligibility.onlyChattedWith,
        (WhoCanMessage.onlyPeopleIChattedWith, true): DirectEligibility.allowed,
        (WhoCanMessage.nobody, false): DirectEligibility.notAccepting,
        (WhoCanMessage.nobody, true): DirectEligibility.notAccepting,
      };
      for (final entry in expected.entries) {
        expect(
          check(who: entry.key.$1, chatted: entry.key.$2),
          entry.value,
          reason: '${entry.key}',
        );
      }
    });

    test('needs at least one shared group', () {
      expect(check(groups: const []), DirectEligibility.noSharedGroup);
      expect(
        ChatRules.sharedGroups(
          [
            circle('x', ['a', 'c']),
            circle('y', ['a', 'b']),
          ],
          'a',
          'b',
        ).map((g) => g.id),
        ['y'],
      );
    });

    test('blocks work both ways and are never revealed', () {
      expect(check(senderBlocked: {'b'}), DirectEligibility.blockedByYou);
      expect(check(recipientBlocked: {'a'}), DirectEligibility.notAccepting);
      // A block beats any history or setting.
      expect(
        check(recipientBlocked: {'a'}, chatted: true),
        DirectEligibility.notAccepting,
      );
      expect(
        ChatRules.eligibilityReason(DirectEligibility.notAccepting),
        'Isn’t accepting messages',
      );
      expect(
        ChatRules.eligibilityReason(DirectEligibility.onlyChattedWith),
        'Only accepts messages from people they’ve chatted with',
      );
      expect(check(recipient: 'a'), DirectEligibility.self);
    });
  });

  group('message requests and close groups', () {
    test('groups of up to 50 people are close by default', () {
      expect(ChatRules.isCloseGroup(sized('g', 50), ChatPrivacy()), isTrue);
      expect(ChatRules.isCloseGroup(sized('g', 51), ChatPrivacy()), isFalse);
    });

    test('first contact outside close groups waits in Requests', () {
      final small = sized('small', 5), large = sized('large', 60);
      final privacy = ChatPrivacy();
      expect(
        ChatRules.needsRequest(
          shared: [large],
          recipientPrivacy: privacy,
          haveChatted: false,
        ),
        isTrue,
      );
      expect(
        ChatRules.needsRequest(
          shared: [large, small],
          recipientPrivacy: privacy,
          haveChatted: false,
        ),
        isFalse,
        reason: 'one close group is enough',
      );
      expect(
        ChatRules.needsRequest(
          shared: [large],
          recipientPrivacy: privacy,
          haveChatted: true,
        ),
        isFalse,
        reason: 'people who chatted before skip Requests',
      );
    });

    test('custom close groups override the size default both ways', () {
      final small = sized('small', 5), large = sized('large', 60);
      final custom = ChatPrivacy(closeGroups: {'large': true, 'small': false});
      expect(ChatRules.isCloseGroup(large, custom), isTrue);
      expect(ChatRules.isCloseGroup(small, custom), isFalse);
      expect(
        ChatRules.needsRequest(
          shared: [large],
          recipientPrivacy: custom,
          haveChatted: false,
        ),
        isFalse,
      );
      expect(
        ChatRules.needsRequest(
          shared: [small],
          recipientPrivacy: custom,
          haveChatted: false,
        ),
        isTrue,
      );
    });

    test('group chats need active membership of the exact group', () {
      final g = circle('g', ['a', 'b']);
      expect(ChatRules.canPostInGroup(g, 'a').allowed, isTrue);
      expect(
        ChatRules.canPostInGroup(g, 'c').reason,
        'You left this group, so you can’t send messages here.',
      );
      expect(ChatRules.canPostInGroup(null, 'a').allowed, isFalse);
    });
  });

  group('message changes', () {
    final sent = DateTime.utc(2026, 10, 23, 12);

    test('edit only by the author within 15 minutes', () {
      final m = message(at: sent);
      expect(
        ChatRules.canEdit(
          m,
          'a',
          sent.add(const Duration(minutes: 15)),
        ).allowed,
        isTrue,
      );
      expect(
        ChatRules.canEdit(
          m,
          'a',
          sent.add(const Duration(minutes: 15, seconds: 1)),
        ).reason,
        'Messages can be edited for 15 minutes after sending.',
      );
      expect(ChatRules.canEdit(m, 'b', sent).allowed, isFalse);
      expect(
        ChatRules.canEdit(message(at: sent, unsentAt: sent), 'a', sent).allowed,
        isFalse,
      );
    });

    test('unsend by the author any time; restore undoes it', () {
      final m = message(at: sent);
      expect(ChatRules.canUnsend(m, 'a').allowed, isTrue);
      expect(ChatRules.canUnsend(m, 'b').allowed, isFalse);
      expect(ChatRules.canRestore(m, 'a').allowed, isFalse);
      final unsent = m.copyWith(unsentAt: sent.add(const Duration(days: 30)));
      expect(unsent.unsent, isTrue);
      expect(ChatRules.canUnsend(unsent, 'a').allowed, isFalse);
      expect(ChatRules.canRestore(unsent, 'a').allowed, isTrue);
      expect(ChatRules.canRestore(unsent, 'b').allowed, isFalse);
      expect(unsent.copyWith(restore: true).unsent, isFalse);
    });

    test('reactions use the 8-emoji allowlist, one per person, toggling', () {
      final m = message();
      for (final emoji in memoryReactions) {
        expect(ChatRules.canReact(m, emoji).allowed, isTrue, reason: emoji);
      }
      expect(ChatRules.canReact(m, '👋').allowed, isFalse);
      expect(
        ChatRules.canReact(message(unsentAt: sent), '❤️').allowed,
        isFalse,
      );
      var reactions = ReactionRules.toggle(const {}, 'b', '❤️');
      reactions = ReactionRules.toggle(reactions, 'b', '😂');
      expect(reactions, {'b': '😂'});
      expect(ReactionRules.toggle(reactions, 'b', '😂'), isEmpty);
    });

    test('a repeated client message id is a duplicate of the same author', () {
      final first = message(clientId: 'same');
      expect(ChatRules.duplicateOf([first], 'a', 'same'), same(first));
      expect(ChatRules.duplicateOf([first], 'b', 'same'), isNull);
      expect(ChatRules.duplicateOf([first], 'a', 'other'), isNull);
    });

    test('text is 1–4000 characters unless a card or poll is attached', () {
      expect(ChatRules.checkText('  ').allowed, isFalse);
      expect(ChatRules.checkText('', hasAttachment: true).allowed, isTrue);
      expect(ChatRules.checkText('a' * 4000).allowed, isTrue);
      expect(
        ChatRules.checkText('a' * 4001).reason,
        'Write up to 4000 characters.',
      );
    });
  });

  group('shared content and status', () {
    test('sharing never grants access', () {
      const memory = SharedContent.memory('m');
      const event = SharedContent.event('e');
      expect(ChatRules.canSeeShared(memory, visible: true).allowed, isTrue);
      expect(
        ChatRules.canSeeShared(memory, visible: false).reason,
        'This Memory isn’t shared with you',
      );
      expect(
        ChatRules.canSeeShared(event, visible: false).reason,
        'This event isn’t shared with you',
      );
    });

    test('1:1 "Seen" only after the request is accepted', () {
      final sent = DateTime.utc(2026, 10, 23, 12);
      final later = sent.add(const Duration(minutes: 1));
      expect(
        ChatRules.directStatus(
          sentAt: sent,
          otherReadAt: later,
          accepted: true,
        ),
        'Seen',
      );
      expect(
        ChatRules.directStatus(
          sentAt: sent,
          otherReadAt: later,
          accepted: false,
        ),
        'Sent',
      );
      expect(
        ChatRules.directStatus(
          sentAt: later,
          otherReadAt: sent,
          accepted: true,
        ),
        'Sent',
      );
    });

    test('group "Seen by" names two people, then counts', () {
      expect(ChatRules.groupStatus([]), 'Sent');
      expect(ChatRules.groupStatus(['Mira']), 'Seen by Mira');
      expect(ChatRules.groupStatus(['Mira', 'Dev']), 'Seen by Mira, Dev');
      expect(
        ChatRules.groupStatus(['Mira', 'Dev', 'Sam', 'Noor', 'Lena']),
        'Seen by Mira, Dev +3',
      );
      expect(
        ChatRules.groupStatusSemantics(['Mira', 'Dev', 'Sam']),
        'Seen by 3 people: Mira, Dev and 1 more',
      );
      expect(
        ChatRules.groupStatusSemantics(['Mira', 'Dev']),
        'Seen by 2 people: Mira and Dev',
      );
    });

    test('inbox lines and quiet big groups', () {
      final now = DateTime.utc(2026, 10, 23, 12);
      expect(
        ChatRules.ownLastLine(
          'Sent',
          now.subtract(const Duration(hours: 2)),
          now,
        ),
        'Sent 2h',
      );
      expect(ChatRules.ownLastLine('Seen', now, now), 'Seen');
      expect(ChatRules.shortAge(now, now), 'now');
      expect(
        ChatRules.shortAge(now.subtract(const Duration(days: 15)), now),
        '2w',
      );
      expect(ChatRules.quietByDefault(50), isFalse);
      expect(ChatRules.quietByDefault(57), isTrue);
      expect(ChatRules.directId('you', 'mira'), 'd-mira-you');
      expect(ChatRules.directId('mira', 'you'), 'd-mira-you');
    });
  });
}
