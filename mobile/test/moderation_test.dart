import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/data/mock_chat_repository.dart';
import 'package:mobile/features/workspace/data/mock_circle_repository.dart';
import 'package:mobile/features/workspace/domain/circle_repository.dart';

final fixed = DateTime.utc(2026, 10, 23, 12);
Matcher failsWith(String text) => throwsA(
  isA<CircleFailure>().having((f) => f.message, 'message', contains(text)),
);

MockCircleRepository showcase() =>
    MockCircleRepository(showcase: true, now: () => fixed);

CircleGroup makeGroup(
  String id,
  Map<String, CircleRole> roles, {
  String? parent,
}) => CircleGroup(
  id: id,
  name: id,
  type: CircleType.other,
  depth: parent == null ? 1 : 2,
  parentId: parent,
  roles: roles,
);

ContentReport report(
  String id,
  ReportTarget target,
  String reporter,
  ReportReason reason, {
  int minutes = 0,
  String? note,
}) => ContentReport(
  id: id,
  target: target,
  reporter: reporter,
  reason: reason,
  createdAt: fixed.subtract(Duration(minutes: minutes)),
  note: note,
);

void main() {
  group('ModerationRules', () {
    const memory = ReportTarget.memory('m', groupId: 'g');

    test('only admins of the exact group may moderate', () {
      final parent = makeGroup('p', {
        'owner': CircleRole.owner,
        'm': CircleRole.member,
      });
      final child = makeGroup('c', {'kid': CircleRole.owner}, parent: 'p');
      expect(ModerationRules.canModerate(parent, 'owner').allowed, isTrue);
      expect(ModerationRules.canModerate(parent, 'm').allowed, isFalse);
      expect(
        ModerationRules.canModerate(child, 'owner').allowed,
        isFalse,
        reason: 'a parent admin is not an admin of the subgroup',
      );
      expect(ModerationRules.canModerate(null, 'owner').allowed, isFalse);
    });

    test('parent admins remove a subgroup without being in it', () {
      final parent = makeGroup('p', {
        'owner': CircleRole.owner,
        'm': CircleRole.member,
      });
      final child = makeGroup('c', {'kid': CircleRole.owner}, parent: 'p');
      final other = makeGroup('o', {'kid': CircleRole.owner});
      expect(
        ModerationRules.canRemoveSubgroup(
          parent: parent,
          subgroup: child,
          actor: 'owner',
        ).allowed,
        isTrue,
      );
      expect(
        ModerationRules.canRemoveSubgroup(
          parent: parent,
          subgroup: child,
          actor: 'm',
        ).allowed,
        isFalse,
      );
      expect(
        ModerationRules.canRemoveSubgroup(
          parent: parent,
          subgroup: other,
          actor: 'owner',
        ).allowed,
        isFalse,
      );
    });

    test('report once, never your own; notes up to 500', () {
      final mine = memory.withPerson('you');
      expect(
        ModerationRules.canReport(
          reporter: 'you',
          target: mine,
          existing: const [],
        ).allowed,
        isFalse,
      );
      final existing = [report('r', memory, 'you', ReportReason.spam)];
      expect(
        ModerationRules.canReport(
          reporter: 'you',
          target: memory,
          existing: existing,
        ).allowed,
        isFalse,
      );
      expect(
        ModerationRules.canReport(
          reporter: 'mira',
          target: memory,
          existing: existing,
        ).allowed,
        isTrue,
      );
      expect(ModerationRules.checkNote('a' * 500).allowed, isTrue);
      expect(ModerationRules.checkNote('a' * 501).allowed, isFalse);
      expect(ModerationRules.cleanNote('  '), isNull);
    });

    test('hidden content: gone for members, a notice for admins', () {
      expect(
        ModerationRules.visibility(hidden: false, isAdmin: false),
        ContentVisibility.visible,
      );
      expect(
        ModerationRules.visibility(hidden: true, isAdmin: false),
        ContentVisibility.gone,
      );
      expect(
        ModerationRules.visibility(hidden: true, isAdmin: true),
        ContentVisibility.hiddenNotice,
      );
    });

    test('the queue groups reports by item and never names reporters', () {
      final items = ModerationRules.aggregate([
        report('1', memory, 'a', ReportReason.spam, minutes: 30),
        report('2', memory, 'b', ReportReason.spam, minutes: 20, note: 'ads'),
        report('3', memory, 'c', ReportReason.hate, minutes: 10),
        report(
          '4',
          const ReportTarget.memory('x', groupId: 'other'),
          'd',
          ReportReason.spam,
        ),
      ], 'g');
      expect(items.single.target.key, 'memory:m');
      expect(items.single.reasons, {
        ReportReason.spam: 2,
        ReportReason.hate: 1,
      });
      expect(items.single.notes, ['ads']);
      expect(
        ModerationRules.reasonsLabel(items.single.reasons),
        'Spam ×2 · Hate',
      );
    });
  });

  group('repository', () {
    test('the seeded queue: admins only, reasons and counts', () async {
      final repository = showcase();
      final queue = await repository.queue('you', 'college');
      expect(queue.items.map((i) => i.target.key), [
        'message:college-spam',
        'subgroup:memes',
      ]);
      final memes = queue.items.last;
      expect(memes.subgroupName, 'Late-night memes');
      expect(memes.subgroupMemberCount, 3);
      expect(memes.summary, isNull, reason: 'subgroups are never read');
      expect(memes.notes, isEmpty, reason: 'nor are notes about them shown');
      expect(memes.count, 3);
      expect(
        queue.audit.single.sentence,
        'Mira dismissed a report about a comment',
      );
      // Members, and admins of other groups, can't see this queue.
      await expectLater(
        repository.queue('dev', 'college'),
        failsWith('Only admins'),
      );
      await expectLater(
        repository.queue('lena', 'college'),
        failsWith('not shared'),
      );
      expect((await repository.load('you')).openReports['college'], 2);
      expect((await repository.load('dev')).openReports, isEmpty);
    });

    test('reporters see only their own reports', () async {
      final repository = showcase();
      await repository.report(
        'dev',
        const ReportDraft(
          target: ReportTarget.memory('reunion-poll', groupId: 'college'),
          reason: ReportReason.spam,
        ),
      );
      expect(
        (await repository.load('dev')).reportedByMe,
        contains('memory:reunion-poll'),
      );
      expect(
        (await repository.load('sam')).reportedByMe,
        isNot(contains('memory:reunion-poll')),
      );
      await expectLater(
        repository.report(
          'dev',
          const ReportDraft(
            target: ReportTarget.memory('reunion-poll', groupId: 'college'),
            reason: ReportReason.hate,
          ),
        ),
        failsWith('already reported'),
      );
      // Reporting needs exact membership; a made-up group is ignored.
      await expectLater(
        repository.report(
          'you',
          const ReportDraft(
            target: ReportTarget.memory('private-memory', groupId: 'family'),
            reason: ReportReason.spam,
          ),
        ),
        failsWith('not shared'),
      );
      await expectLater(
        repository.report(
          'mira',
          const ReportDraft(
            target: ReportTarget.memory('table', groupId: 'family'),
            reason: ReportReason.spam,
          ),
        ),
        failsWith('your own'),
      );
      final queue = await repository.queue('you', 'college');
      final item = queue.items.firstWhere(
        (i) => i.target.key == 'memory:reunion-poll',
      );
      expect(item.personName, 'Mira');
      expect(item.summary, contains('Fifteen years'));
    });

    test(
      'hide: gone for members, marked for admins; unhide reverses',
      () async {
        final repository = showcase();
        await repository.report(
          'dev',
          const ReportDraft(
            target: ReportTarget.memory('reunion-poll', groupId: 'college'),
            reason: ReportReason.spam,
          ),
        );
        await expectLater(
          repository.hide('dev', 'college', 'memory:reunion-poll'),
          failsWith('Only admins'),
        );
        await repository.hide('you', 'college', 'memory:reunion-poll');
        final member = await repository.load('dev');
        expect(
          member.memories.map((m) => m.id),
          isNot(contains('reunion-poll')),
        );
        await expectLater(
          repository.react('dev', 'reunion-poll', '❤️'),
          failsWith('unavailable'),
        );
        final admin = await repository.load('you');
        expect(admin.memories.map((m) => m.id), contains('reunion-poll'));
        expect(admin.isHidden(ReportKind.memory, 'reunion-poll'), isTrue);
        expect(
          (await repository.queue('you', 'college')).audit.first.sentence,
          'You hid a Memory',
        );
        await repository.unhide('you', 'college', 'memory:reunion-poll');
        expect(
          (await repository.load('dev')).memories.map((m) => m.id),
          contains('reunion-poll'),
        );
      },
    );

    test('hidden comments and events follow the same rule', () async {
      final repository = showcase();
      await repository.report(
        'you',
        const ReportDraft(
          target: ReportTarget.comment(
            'table-comment-1',
            memoryId: 'table',
            groupId: 'family',
          ),
          reason: ReportReason.harassment,
        ),
      );
      await repository.hide('you', 'family', 'comment:table-comment-1');
      final priya = await repository.load('priya');
      final table = priya.memories.firstWhere((m) => m.id == 'table');
      expect(
        table.comments.map((c) => c.id),
        isNot(contains('table-comment-1')),
      );
      final owner = await repository.load('you');
      expect(
        owner.memories
            .firstWhere((m) => m.id == 'table')
            .comments
            .map((c) => c.id),
        contains('table-comment-1'),
      );
      await repository.report(
        'priya',
        const ReportDraft(
          target: ReportTarget.event('lunch', groupId: 'family'),
          reason: ReportReason.other,
          note: '  ',
        ),
      );
      await repository.hide('you', 'family', 'event:lunch');
      expect((await repository.load('priya')).event('lunch'), isNull);
      expect((await repository.load('you')).event('lunch'), isNotNull);
      // Members and subgroups can't be hidden, only removed.
      await expectLater(
        repository.hide('you', 'college', 'subgroup:memes'),
        failsWith('Only posts and messages'),
      );
    });

    test('dismiss with undo; removing a reported member settles it', () async {
      final repository = showcase();
      await repository.dismiss('you', 'college', 'message:college-spam');
      expect(
        (await repository.queue(
          'you',
          'college',
        )).items.map((i) => i.target.key),
        ['subgroup:memes'],
      );
      await repository.restoreReports('you', 'college', 'message:college-spam');
      expect((await repository.queue('you', 'college')).items.length, 2);
      await repository.report(
        'you',
        const ReportDraft(
          target: ReportTarget.member('bilal', groupId: 'college'),
          reason: ReportReason.spam,
        ),
      );
      var queue = await repository.queue('you', 'college');
      final member = queue.items.firstWhere(
        (i) => i.target.key == 'member:bilal',
      );
      expect(member.canRemovePerson, isTrue);
      await repository.removeMember('you', 'college', 'bilal');
      queue = await repository.queue('you', 'college');
      expect(
        queue.items.map((i) => i.target.key),
        isNot(contains('member:bilal')),
      );
      expect(queue.audit.first.sentence, 'You removed Bilal');
    });

    test('a parent admin removes a reported subgroup unseen', () async {
      final repository = showcase();
      // The viewer administers Northbank 2009 but isn't in the subgroup.
      expect((await repository.load('you')).group('memes'), isNull);
      await expectLater(
        repository.removeSubgroup('dev', 'college', 'memes'),
        failsWith('Only admins'),
      );
      await expectLater(
        repository.removeSubgroup('you', 'family', 'memes'),
        failsWith('no longer here'),
      );
      await repository.removeSubgroup('you', 'college', 'memes');
      expect((await repository.load('kavya')).group('memes'), isNull);
      expect(
        (await repository.load('you')).discoverable.map((p) => p.id),
        isNot(contains('memes')),
      );
      final queue = await repository.queue('you', 'college');
      expect(queue.items.map((i) => i.target.key), ['message:college-spam']);
      expect(
        queue.audit.first.sentence,
        'You removed the subgroup Late-night memes',
      );
    });

    test(
      'hidden group-chat messages: gone for members, marked for admins',
      () async {
        final groups = showcase();
        final chat = MockChatRepository(
          groups: groups,
          moderation: groups,
          showcase: true,
          now: () => fixed,
        );
        await groups.hide('you', 'college', 'message:college-spam');
        final admin = await chat.conversation('you', 'g-college');
        final marked = admin.messages.firstWhere((m) => m.id == 'college-spam');
        expect(marked.hiddenByAdmins, isTrue);
        final member = await chat.conversation('sam', 'g-college');
        expect(
          member.messages.map((m) => m.id),
          isNot(contains('college-spam')),
        );
        // A chat report lands in the right queue with a snapshot.
        final kavya = member.messages.firstWhere((m) => m.authorId == 'kavya');
        await chat.report(
          'sam',
          'g-college',
          messageId: kavya.id,
          reason: ReportReason.other,
        );
        final queue = await groups.queue('you', 'college');
        final item = queue.items.firstWhere(
          (i) => i.target.key == 'message:${kavya.id}',
        );
        expect(item.summary, kavya.text);
        expect(item.personName, 'Kavya');
        // 1:1 reports go to the platform, never to a group's admins.
        await chat.report('you', 'd-dev-you', reason: ReportReason.spam);
        for (final id in ['family', 'college', 'club']) {
          final items = (await groups.queue('you', id)).items;
          expect(items.map((i) => i.target.key), isNot(contains('member:dev')));
        }
        final own = (await chat.conversation(
          'you',
          'd-mira-you',
        )).messages.firstWhere((m) => m.mine);
        await expectLater(
          chat.report(
            'you',
            'd-mira-you',
            messageId: own.id,
            reason: ReportReason.spam,
          ),
          failsWith('your own'),
        );
      },
    );

    test('reset clears reports, hidden content and the audit trail', () async {
      final repository = showcase();
      await repository.hide('you', 'college', 'message:college-spam');
      await repository.dismiss('you', 'college', 'subgroup:memes');
      await repository.reset(showcase: true);
      final queue = await repository.queue('you', 'college');
      expect(queue.items.length, 2);
      expect(queue.audit.length, 1);
      expect((await repository.load('you')).hiddenByAdmins, isEmpty);
      await repository.reset(showcase: false);
      expect((await repository.load('you')).openReports, isEmpty);
    });
  });
}
