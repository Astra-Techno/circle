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

void main() {
  final now = DateTime.utc(2026, 10, 23, 12);

  group('activity visibility', () {
    final shared = [
      circle('g', ['v', 'p']),
    ];
    bool see({
      String viewer = 'v',
      String person = 'p',
      bool viewerShows = true,
      bool personShows = true,
      Set<String> viewerBlocked = const {},
      Set<String> personBlocked = const {},
      List<CircleGroup>? groups,
      bool pending = false,
    }) => ActivityRules.canSee(
      viewer: viewer,
      person: person,
      viewerPrivacy: ChatPrivacy(
        showActivity: viewerShows,
        blocked: viewerBlocked,
      ),
      personPrivacy: ChatPrivacy(
        showActivity: personShows,
        blocked: personBlocked,
      ),
      shared: groups ?? shared,
      pendingRequest: pending,
    );

    test('hidden both ways while the 1:1 is an unaccepted request', () {
      expect(see(pending: true), isFalse);
      expect(see(viewer: 'p', person: 'v', pending: true), isFalse);
    });

    test('visible when both share it, share a group and no block', () {
      expect(see(), isTrue);
    });

    test('reciprocal: off on either side hides it', () {
      expect(see(viewerShows: false), isFalse, reason: 'viewer off');
      expect(see(personShows: false), isFalse, reason: 'person off');
      expect(see(viewerShows: false, personShows: false), isFalse);
    });

    test('a block in either direction hides it', () {
      expect(see(viewerBlocked: {'p'}), isFalse);
      expect(see(personBlocked: {'v'}), isFalse);
      expect(see(viewerBlocked: {'someone-else'}), isTrue);
    });

    test('no shared group hides it', () {
      expect(see(groups: const []), isFalse);
    });

    test('never your own', () {
      expect(see(person: 'v'), isFalse);
    });

    test('ChatPrivacy shows activity by default', () {
      expect(ChatPrivacy().showActivity, isTrue);
      expect(ChatPrivacy().copyWith(showActivity: false).showActivity, isFalse);
      expect(
        ChatPrivacy(showActivity: false).copyWith(blocked: {'x'}).showActivity,
        isFalse,
      );
    });
  });

  group('activity labels with a fixed clock', () {
    String? at(Duration ago) => ActivityRules.label(now.subtract(ago), now);

    test('unknown shows nothing', () {
      expect(ActivityRules.label(null, now), isNull);
    });

    test('up to 5 minutes is Active now', () {
      expect(at(Duration.zero), 'Active now');
      expect(at(const Duration(minutes: 2)), 'Active now');
      expect(at(const Duration(minutes: 5)), 'Active now');
      // A clock slightly ahead still reads now.
      expect(at(const Duration(seconds: -30)), 'Active now');
    });

    test('minutes below one hour', () {
      expect(at(const Duration(minutes: 5, seconds: 1)), 'Active 5m ago');
      expect(at(const Duration(minutes: 6)), 'Active 6m ago');
      expect(at(const Duration(minutes: 59, seconds: 59)), 'Active 59m ago');
    });

    test('hours below one day', () {
      expect(at(const Duration(minutes: 60)), 'Active 1h ago');
      expect(at(const Duration(hours: 2)), 'Active 2h ago');
      expect(at(const Duration(hours: 23, minutes: 59)), 'Active 23h ago');
    });

    test('yesterday below 48 hours, then nothing', () {
      expect(at(const Duration(hours: 24)), 'Active yesterday');
      expect(at(const Duration(hours: 47, minutes: 59)), 'Active yesterday');
      expect(at(const Duration(hours: 48)), isNull);
      expect(at(const Duration(days: 4)), isNull);
    });

    test('visibleLabel combines the rule and the label', () {
      String? label({bool personShows = true}) => ActivityRules.visibleLabel(
        viewer: 'v',
        person: 'p',
        viewerPrivacy: ChatPrivacy(),
        personPrivacy: ChatPrivacy(showActivity: personShows),
        shared: [
          circle('g', ['v', 'p']),
        ],
        lastActiveAt: now.subtract(const Duration(hours: 2)),
        now: now,
      );
      expect(label(), 'Active 2h ago');
      expect(label(personShows: false), isNull);
    });

    test('spoken labels for screen readers', () {
      expect(ActivityRules.spoken('Mira', 'Active now'), 'Mira, active now');
      expect(
        ActivityRules.spoken('Dev', 'Active 2h ago'),
        'Dev, active 2h ago',
      );
      expect(ActivityRules.spoken('Sam', null), 'Sam');
    });
  });

  group('share eligibility', () {
    final family = circle('family', ['you', 'mira', 'dev']);
    final club = circle('club', ['you', 'mira']);
    final planners = circle('planners', ['mira', 'dev']);

    test('1:1: both people must be members of the item’s exact group', () {
      expect(ChatRules.everyoneCanSee(family, ['you', 'mira']), isTrue);
      expect(ChatRules.everyoneCanSee(club, ['you', 'mira']), isTrue);
      expect(ChatRules.everyoneCanSee(club, ['you', 'dev']), isFalse);
      expect(
        ChatRules.everyoneCanSee(planners, ['you', 'mira']),
        isFalse,
        reason: 'the viewer is not in it',
      );
    });

    test('group chat: every current member must be in the item’s group', () {
      final members = family.roles.keys;
      expect(ChatRules.everyoneCanSee(family, members), isTrue);
      expect(
        ChatRules.everyoneCanSee(club, members),
        isFalse,
        reason: 'Dev is not in the club',
      );
      final wider = circle('wider', ['you', 'mira', 'dev', 'priya']);
      expect(
        ChatRules.everyoneCanSee(wider, members),
        isTrue,
        reason: 'another group every member belongs to',
      );
    });

    test('unknown group or nobody in the chat is never eligible', () {
      expect(ChatRules.everyoneCanSee(null, ['you', 'mira']), isFalse);
      expect(ChatRules.everyoneCanSee(family, const []), isFalse);
    });

    test('canShareInto explains calmly', () {
      expect(ChatRules.canShareInto(family, ['you', 'mira']).allowed, isTrue);
      final denied = ChatRules.canShareInto(club, ['you', 'dev']);
      expect(denied.allowed, isFalse);
      expect(denied.reason, contains('everyone in this chat can see'));
    });
  });
}
