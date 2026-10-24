import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/workspace/data/mock_circle_repository.dart';
import 'package:mobile/features/workspace/domain/circle_repository.dart';

final fails = throwsA(isA<CircleFailure>());
Matcher failsWith(String text) => throwsA(
  isA<CircleFailure>().having((f) => f.message, 'message', contains(text)),
);

MockCircleRepository showcase([DateTime Function()? now]) =>
    MockCircleRepository(showcase: true, now: now);

void main() {
  group('workspace basics', () {
    test('new Memories sort first even with a fixed clock', () async {
      final repository = showcase(() => DateTime.utc(2026, 1, 1));
      await repository.createMemory('you', 'family', 'First new Memory');
      await repository.createMemory('you', 'family', 'Second new Memory');
      final memories = (await repository.load('you')).memories;
      expect(memories.take(2).map((memory) => memory.text), [
        'Second new Memory',
        'First new Memory',
      ]);
    });

    test('registration starts empty; showcase is an explicit choice', () async {
      final repository = MockCircleRepository();
      final empty = await repository.load('you');
      expect(empty.groups, isEmpty);
      expect(empty.invitations, isEmpty);
      expect(empty.pending, isEmpty);
      await repository.reset(showcase: true);
      final workspace = await repository.load('you');
      expect(workspace.groups.map((group) => group.id), [
        'family',
        'college',
        'cse',
        'section',
        'friends',
        'work',
        'club',
        'riders',
      ]);
      expect(workspace.groups.any((group) => group.depth == 4), true);
      expect(workspace.memories.map((memory) => memory.id), [
        'table',
        'reunion-poll',
        'ride',
        'old-days',
        'route-poll',
      ]);
      expect(workspace.invitations.map((i) => i.groupName), [
        'Cousins’ corner',
        'Board games',
      ]);
      expect(workspace.pending.single.name, 'Meetup helpers');
      expect(workspace.joinRequests.map((r) => r.person), ['arjun', 'lena']);
      expect(workspace.nameOf('mira'), 'Mira');
      expect(workspace.nameOf('you'), 'You');
    });

    test('parent owner gains no access to a private child', () async {
      final repository = showcase();
      expect(
        (await repository.readGroup('you', 'family')).roles['you'],
        CircleRole.owner,
      );
      expect(repository.readGroup('you', 'private-plans'), fails);
      expect(repository.createMemory('you', 'private-plans', 'x'), fails);
      expect(repository.loveMemory('you', 'private-memory'), fails);
      expect(repository.saveMemory('you', 'private-memory'), fails);
      expect(repository.comment('you', 'private-memory', 'x'), fails);
      expect(
        repository.createGroup(
          'you',
          'A child',
          CircleType.family,
          parentId: 'private-plans',
        ),
        fails,
      );
    });

    test(
      'any direct-parent member may create a subgroup and owns it',
      () async {
        final repository = showcase();
        final child = await repository.createGroup(
          'you',
          'A smaller group',
          CircleType.friends,
          parentId: 'cse',
          hidden: true,
        );
        expect(child.depth, 3);
        expect(child.roles, {'you': CircleRole.owner});
        expect(child.hidden, isTrue);
        expect(
          () => child.roles['other'] = CircleRole.admin,
          throwsUnsupportedError,
        );
        final root = await repository.createGroup(
          'you',
          'Root',
          CircleType.other,
          hidden: true,
        );
        expect(root.hidden, isFalse, reason: 'root groups are never listed');
      },
    );

    test('level ten is allowed and level eleven is denied', () async {
      final repository = MockCircleRepository();
      var group = await repository.createGroup('you', 'Root', CircleType.other);
      for (var depth = 2; depth <= 10; depth++) {
        group = await repository.createGroup(
          'you',
          'Level $depth',
          CircleType.other,
          parentId: group.id,
        );
        expect(group.depth, depth);
      }
      expect(
        repository.createGroup(
          'you',
          'Too deep',
          CircleType.other,
          parentId: group.id,
        ),
        failsWith('10-level'),
      );
      expect(
        repository.createGroup(
          'outsider',
          'Back door',
          CircleType.other,
          parentId: group.id,
        ),
        fails,
      );
    });

    test('name and content boundaries reject empty/oversized input', () {
      final repository = showcase();
      for (final name in ['  ', 'x' * 61]) {
        expect(repository.createGroup('you', name, CircleType.other), fails);
      }
      for (final text in ['  ', 'x' * 2001]) {
        expect(repository.createMemory('you', 'family', text), fails);
        expect(repository.comment('you', 'table', text), fails);
      }
    });

    test('mutations persist locally and reset cleanly', () async {
      final repository = showcase();
      await repository.loveMemory('you', 'table');
      await repository.saveMemory('you', 'table');
      await repository.comment('you', 'table', ' A wonderful Sunday ');
      var workspace = await repository.load('you');
      expect(workspace.memories.first.loved, true);
      expect(workspace.memories.first.saved, true);
      final comment = workspace.memories.first.comments.last;
      expect(comment.text, 'A wonderful Sunday');
      expect((comment.authorId, comment.authorName), ('you', 'You'));
      await repository.createMemory('you', 'work', 'A small win');
      workspace = await repository.load('you');
      expect(workspace.memories.first.groupId, 'work');
      expect(repository.createMemory('stranger', 'work', 'test'), fails);
      await repository.reset(showcase: false);
      workspace = await repository.load('you');
      expect(workspace.groups, isEmpty);
      expect(workspace.memories, isEmpty);
    });

    test(
      'RSVP requires membership, keeps a choice and can be cleared',
      () async {
        final repository = showcase();
        const going = Rsvp(Attendance.going);
        expect(repository.rsvp('stranger', 'lunch', going), fails);
        await repository.rsvp('you', 'lunch', const Rsvp(Attendance.maybe));
        expect(
          (await repository.load('you')).event('lunch')!.rsvpOf('you')?.status,
          Attendance.maybe,
        );
        await repository.rsvp('you', 'lunch', null);
        expect(
          (await repository.load('you')).event('lunch')!.rsvpOf('you'),
          isNull,
        );
        expect(repository.rsvp('you', 'missing', going), fails);
      },
    );
  });

  group('roles and removal', () {
    test('promote, demote and owner protections', () async {
      final repository = showcase();
      await repository.setRole('you', 'family', 'dev', CircleRole.admin);
      expect(
        (await repository.readGroup('you', 'family')).roles['dev'],
        CircleRole.admin,
      );
      await repository.setRole('you', 'family', 'dev', CircleRole.member);
      expect(
        repository.setRole('you', 'college', 'mira', CircleRole.member),
        failsWith('owner'),
      );
      expect(
        repository.setRole('you', 'cse', 'sam', CircleRole.admin),
        failsWith('Only admins'),
      );
      expect(
        repository.setRole('you', 'college', 'dev', CircleRole.owner),
        failsWith('Transfer ownership'),
      );
    });

    test('removal cascades to every descendant and reports impact', () async {
      final repository = showcase();
      final impact = await repository.removalImpact('you', 'college', 'sam');
      expect(impact, ['Computer science', 'Electronics']);
      await repository.removeMember('you', 'college', 'sam');
      final rejoin = await repository.previewInvite(
        'sam',
        'northbank-2009-preview',
      );
      expect(rejoin.status, InviteLinkStatus.valid);
      final workspace = await repository.load('sam');
      expect(
        workspace.groups.map((group) => group.id),
        isNot(contains(anyOf('college', 'cse', 'ece'))),
      );
      expect(workspace.groups.map((group) => group.id), ['book', 'trip']);
    });

    test(
      'a removed person can only rejoin with a link made after removal',
      () async {
        var now = DateTime.utc(2026, 10, 23, 9);
        final repository = showcase(() => now);
        await repository.removeMember('you', 'college', 'sam');
        await expectLater(
          repository.joinWithLink('sam', 'northbank-2009-preview'),
          failsWith('removed'),
        );
        now = now.add(const Duration(minutes: 5));
        final fresh = await repository.resetInviteLink('you', 'college');
        // Joins or asks to join, depending on the group's approval setting.
        await expectLater(
          repository.joinWithLink('sam', fresh.token),
          completes,
        );
      },
    );

    test('owner and admins are protected from removal by admins', () {
      final repository = showcase();
      expect(
        repository.removeMember('you', 'college', 'mira'),
        failsWith('owner can’t be removed'),
      );
      expect(
        repository.removeMember('dev', 'college', 'you'),
        failsWith('Only admins'),
      );
    });

    test('removal is blocked while the person owns a descendant', () {
      final repository = showcase();
      expect(
        repository.removeMember('you', 'college', 'dev'),
        failsWith('Computer science'),
      );
    });

    test('owner transfers ownership and becomes an admin', () async {
      final repository = showcase();
      expect(
        repository.transferOwnership('mira', 'family', 'dev'),
        failsWith('Only the owner'),
      );
      await repository.transferOwnership('you', 'family', 'dev');
      final family = await repository.readGroup('you', 'family');
      expect(family.ownerId, 'dev');
      expect(family.roles['you'], CircleRole.admin);
      expect(family.roles.values.where((r) => r == CircleRole.owner).length, 1);
    });

    test('leaving cascades; owner and last admin are blocked', () async {
      final repository = showcase();
      expect(repository.leaveGroup('you', 'family'), failsWith('Transfer'));
      expect(repository.leaveGroup('you', 'club'), failsWith('Transfer'));
      await repository.leaveGroup('you', 'college');
      final ids = (await repository.load('you')).groups.map((g) => g.id);
      expect(
        ids,
        isNot(contains(anyOf('college', 'cse', 'section', 'friends'))),
      );
      expect(ids, containsAll(['family', 'work', 'club']));
      // The pending request to a college subgroup is closed too.
      expect((await repository.load('you')).pending, isEmpty);
    });

    test('a member who owns a descendant cannot leave the parent', () {
      final repository = showcase();
      expect(
        repository.leaveGroup('dev', 'college'),
        failsWith('You own Computer science'),
      );
    });
  });

  group('joining', () {
    test('hidden subgroups are never listed; listed ones are', () async {
      final workspace = await showcase().load('you');
      final ids = workspace.discoverable.map((preview) => preview.id).toSet();
      expect(ids, containsAll(['ece', 'meetup', 'social', 'recipes']));
      expect(
        ids,
        isNot(contains(anyOf('private-plans', 'committee', 'board'))),
      );
      expect(ids, isNot(contains('quiz')), reason: 'you are not in its parent');
    });

    test('request to join: approval required vs join directly', () async {
      final repository = showcase();
      expect(
        await repository.requestToJoin('you', 'ece'),
        JoinOutcome.requested,
      );
      expect(repository.requestToJoin('you', 'ece'), failsWith('waiting'));
      expect(repository.requestToJoin('you', 'committee'), fails);
      expect(
        repository.requestToJoin('you', 'quiz'),
        failsWith('Join Studio social first'),
      );
      expect(
        await repository.requestToJoin('you', 'social'),
        JoinOutcome.joined,
      );
      final workspace = await repository.load('you');
      expect(workspace.groups.any((group) => group.id == 'social'), true);
      expect(workspace.pending.map((p) => p.name), [
        'Meetup helpers',
        'Electronics',
      ]);
    });

    test('pending requests reveal only the group name; cancel works', () async {
      final repository = showcase();
      final workspace = await repository.load('you');
      expect(workspace.groups.any((group) => group.id == 'meetup'), false);
      expect(workspace.memories.any((m) => m.groupId == 'meetup'), false);
      await repository.cancelRequest('you', workspace.pending.single.requestId);
      expect((await repository.load('you')).pending, isEmpty);
      expect(repository.cancelRequest('mira', 'request-arjun-family'), fails);
    });

    test('approval re-checks direct-parent membership', () async {
      final repository = showcase();
      await repository.requestToJoin('sam', 'meetup');
      final request = (await repository.load(
        'mira',
      )).joinRequests.firstWhere((r) => r.person == 'sam');
      // Sam leaves the parent before approval; the request closes.
      await repository.leaveGroup('sam', 'college');
      expect(
        repository.approveRequest('mira', request.id),
        failsWith('already been handled'),
      );
      await repository.requestToJoin('noor', 'cse');
      final cseRequest = (await repository.load(
        'dev',
      )).joinRequests.firstWhere((r) => r.person == 'noor');
      await repository.approveRequest('dev', cseRequest.id);
      expect(
        (await repository.readGroup('noor', 'cse')).roles['noor'],
        CircleRole.member,
      );
    });

    test('admins approve and decline; members cannot', () async {
      final repository = showcase();
      expect(repository.approveRequest('dev', 'request-arjun-family'), fails);
      await repository.approveRequest('you', 'request-arjun-family');
      expect(
        (await repository.readGroup('arjun', 'family')).roles['arjun'],
        CircleRole.member,
      );
      await repository.declineRequest('you', 'request-lena-club');
      expect((await repository.load('you')).joinRequests, isEmpty);
      expect(
        repository.approveRequest('you', 'request-lena-club'),
        failsWith('already been handled'),
      );
    });
  });

  group('invite links', () {
    test('preview shows group, inviter and approval; join or ask', () async {
      final repository = showcase();
      final book = await repository.previewInvite(
        'you',
        'circle://invite/chapter-verse-preview',
      );
      expect(book.status, InviteLinkStatus.valid);
      expect(book.group!.name, 'Chapter & verse');
      expect(book.group!.memberCount, 2);
      expect(book.inviterName, 'Noor');
      expect(book.group!.approvalRequired, isTrue);
      expect(
        await repository.joinWithLink('you', 'chapter-verse-preview'),
        JoinOutcome.requested,
      );
      expect(
        (await repository.previewInvite('you', 'chapter-verse-preview')).status,
        InviteLinkStatus.alreadyRequested,
      );
      expect(
        await repository.joinWithLink('you', 'GARDEN-PLOT-PREVIEW'),
        JoinOutcome.joined,
      );
      expect(
        (await repository.previewInvite('you', 'garden-plot-preview')).status,
        InviteLinkStatus.alreadyMember,
      );
    });

    test('subgroup link needs direct-parent membership', () async {
      final repository = showcase();
      final quiz = await repository.previewInvite('you', 'quiz-night-preview');
      expect(quiz.status, InviteLinkStatus.needsParent);
      expect(quiz.group!.parentName, 'Studio social');
      expect(
        repository.joinWithLink('you', 'quiz-night-preview'),
        failsWith('Join Studio social first'),
      );
      await repository.requestToJoin('you', 'social');
      expect(
        await repository.joinWithLink('you', 'quiz-night-preview'),
        JoinOutcome.requested,
      );
    });

    test('expired, reset, unknown and exhausted links fail clearly', () async {
      final repository = showcase();
      expect(
        (await repository.previewInvite('you', 'hill-trip-preview')).status,
        InviteLinkStatus.expired,
      );
      expect(
        (await repository.previewInvite('you', 'sunday-table-old')).status,
        InviteLinkStatus.reset,
      );
      expect(
        (await repository.previewInvite('you', 'no-such-link')).status,
        InviteLinkStatus.unknown,
      );
      expect(
        repository.joinWithLink('you', 'hill-trip-preview'),
        failsWith('expired'),
      );
      await repository.configureInviteLink(
        'you',
        'club',
        expiry: const Duration(days: 1),
        maxUses: 1,
      );
      final club = await repository.readGroup('you', 'club');
      expect(club.inviteLink!.maxUses, 1);
      expect(club.inviteLink!.exhausted, isTrue);
      expect(
        repository.joinWithLink('sam', 'sunday-miles-preview'),
        failsWith('limit'),
      );
    });

    test(
      'expiry defaults to seven days and is enforced by the clock',
      () async {
        var now = DateTime.utc(2026, 10, 1);
        final repository = MockCircleRepository(now: () => now);
        final group = await repository.createGroup(
          'you',
          'Book swap',
          CircleType.club,
        );
        final link = await repository.createInviteLink('you', group.id);
        expect(link.expiresAt.difference(link.createdAt), defaultInviteExpiry);
        now = now.add(const Duration(days: 6, hours: 23));
        expect(
          (await repository.previewInvite('sam', link.token)).status,
          InviteLinkStatus.valid,
        );
        now = now.add(const Duration(hours: 1));
        expect(
          (await repository.previewInvite('sam', link.token)).status,
          InviteLinkStatus.expired,
        );
      },
    );

    test('removed people cannot rejoin with a link that was reset', () async {
      final repository = showcase();
      await repository.removeMember('you', 'club', 'tomas');
      final old = (await repository.readGroup('you', 'club')).inviteLink!.token;
      final fresh = await repository.resetInviteLink('you', 'club');
      expect(fresh.token, isNot(old));
      expect(repository.joinWithLink('tomas', old), failsWith('was reset'));
      await repository.revokeInviteLink('you', 'club');
      expect(
        (await repository.previewInvite('tomas', fresh.token)).status,
        InviteLinkStatus.reset,
      );
    });

    test('only admins manage links; members share when allowed', () async {
      final repository = showcase();
      expect(repository.resetInviteLink('you', 'work'), failsWith('admins'));
      expect(repository.createInviteLink('you', 'work'), failsWith('admins'));
      final work = (await repository.load(
        'you',
      )).groups.firstWhere((group) => group.id == 'work');
      expect(work.inviteLink, isNull, reason: 'members cannot see the link');
      final cse = await repository.createInviteLink('you', 'cse');
      expect(cse.token, isNotEmpty);
      expect(repository.resetInviteLink('you', 'cse'), failsWith('admins'));
    });
  });

  group('direct invitations', () {
    test('adding someone needs their consent', () async {
      final repository = showcase();
      await repository
          .inviteMember('you', 'riders', 'tomas')
          .catchError((_) {});
      expect(
        repository.inviteMember('you', 'riders', 'tomas'),
        failsWith('already have an invitation'),
      );
      final tomas = await repository.load('tomas');
      expect(tomas.groups.any((group) => group.id == 'riders'), isFalse);
      final invitation = tomas.invitations.single;
      expect(invitation.groupName, 'Early riders');
      expect(invitation.inviterName, 'You');
      expect(
        await repository.respondToInvitation(
          'tomas',
          invitation.invitation.id,
          accept: true,
        ),
        JoinOutcome.joined,
      );
      expect(
        (await repository.readGroup('tomas', 'riders')).roles['tomas'],
        CircleRole.member,
      );
    });

    test('subgroup invitations only reach direct-parent members', () async {
      final repository = showcase();
      expect(
        repository.inviteMember('you', 'riders', 'sam'),
        failsWith('isn’t in Sunday miles'),
      );
      expect(
        repository.inviteMember('you', 'riders', 'mira'),
        failsWith('already in'),
      );
    });

    test('decline removes the invitation without joining', () async {
      final repository = showcase();
      expect(
        await repository.respondToInvitation(
          'you',
          'invite-cousins',
          accept: false,
        ),
        isNull,
      );
      final workspace = await repository.load('you');
      expect(workspace.invitations.single.groupName, 'Board games');
      expect(workspace.groups.any((group) => group.id == 'cousins'), false);
      expect(
        repository.respondToInvitation('mira', 'invite-board', accept: true),
        fails,
      );
    });

    test('accepting a hidden subgroup invitation joins it', () async {
      final repository = showcase();
      await repository.respondToInvitation('you', 'invite-board', accept: true);
      expect(
        (await repository.readGroup('you', 'board')).roles['you'],
        CircleRole.member,
      );
    });

    test('invitation from a member still respects approval', () async {
      final repository = showcase();
      await repository.inviteMember('you', 'cse', 'noor');
      final invitation = (await repository.load('noor')).invitations.single;
      expect(
        await repository.respondToInvitation(
          'noor',
          invitation.invitation.id,
          accept: true,
        ),
        JoinOutcome.requested,
      );
      expect((await repository.load('dev')).joinRequests.single.person, 'noor');
    });

    test('leaving the parent closes subgroup invitations', () async {
      final repository = showcase();
      await repository
          .inviteMember('you', 'riders', 'tomas')
          .catchError((_) {});
      await repository.leaveGroup('tomas', 'club');
      expect((await repository.load('tomas')).invitations, isEmpty);
    });
  });

  group('settings', () {
    test('admins change name, approval, invite policy and listing', () async {
      final repository = showcase();
      await repository.updateSettings(
        'you',
        'riders',
        name: ' Dawn riders ',
        approvalRequired: false,
        invitePolicy: InvitePolicy.allMembers,
        hidden: true,
      );
      final riders = await repository.readGroup('you', 'riders');
      expect(riders.name, 'Dawn riders');
      expect(riders.approvalRequired, isFalse);
      expect(riders.settings.invitePolicy, InvitePolicy.allMembers);
      expect(riders.hidden, isTrue);
      expect(
        (await repository.load('tomas')).discoverable,
        isEmpty,
        reason: 'hidden subgroups are never listed',
      );
      expect(
        repository.updateSettings('you', 'club', hidden: true),
        failsWith('Only subgroups'),
      );
      expect(
        repository.updateSettings('you', 'work', name: 'Mine now'),
        failsWith('Only admins'),
      );
    });
  });

  group('memories (UI-3)', () {
    Future<CircleMemory> memoryOf(
      MockCircleRepository repository,
      String id, [
      String viewer = 'you',
    ]) async =>
        (await repository.load(viewer)).memories.firstWhere((m) => m.id == id);

    test('text, photos, poll, year and place in any mix', () async {
      final repository = showcase(() => DateTime.utc(2026, 10, 23));
      final id = await repository.createMemory(
        'you',
        'family',
        '  ',
        photos: [MemoryScene.beachWalk, MemoryScene.hillTrip],
        poll: const PollDraft(
          question: 'Tea or coffee?',
          options: ['Tea', 'Coffee'],
        ),
        takenYear: 2007,
        place: ' Kodaikanal ',
      );
      final memory = await memoryOf(repository, id);
      expect(memory.text, isEmpty);
      expect(memory.photos.map((p) => p.scene), [
        MemoryScene.beachWalk,
        MemoryScene.hillTrip,
      ]);
      expect(memory.poll!.question, 'Tea or coffee?');
      expect(memory.poll!.canClose, isTrue, reason: 'creator');
      expect(memory.takenLabel, 'Taken in 2007 · Kodaikanal');
      expect(memory.authorId, 'you');
      final photoOnly = await repository.createMemory(
        'you',
        'family',
        '',
        photos: [MemoryScene.cricketMatch],
      );
      expect((await memoryOf(repository, photoOnly)).photos, hasLength(1));
    });

    test('content, poll, year and place are validated', () async {
      final repository = showcase(() => DateTime.utc(2026, 10, 23));
      expect(repository.createMemory('you', 'family', ''), fails);
      expect(
        repository.createMemory(
          'you',
          'family',
          '',
          photos: List.filled(11, MemoryScene.beachWalk),
        ),
        fails,
      );
      expect(
        repository.createMemory(
          'you',
          'family',
          '',
          poll: const PollDraft(question: 'Only one?', options: ['Yes']),
        ),
        fails,
      );
      expect(
        repository.createMemory('you', 'family', 'Old', takenYear: 1949),
        fails,
      );
      expect(
        repository.createMemory('you', 'family', 'Old', takenYear: 2027),
        fails,
      );
      expect(
        repository.createMemory('you', 'family', 'Far', place: 'x' * 81),
        fails,
      );
    });

    test('reactions: allowlist, one per viewer, toggle', () async {
      final repository = showcase();
      var memory = await memoryOf(repository, 'table');
      expect(memory.reactions.mine, isNull);
      expect(memory.reactions.countOf('❤️'), 12);
      await repository.react('you', 'table', '😂');
      memory = await memoryOf(repository, 'table');
      expect(memory.reactions.mine, '😂');
      expect(memory.reactions.countOf('😂'), 4);
      expect(memory.loved, isFalse);
      await repository.loveMemory('you', 'table');
      memory = await memoryOf(repository, 'table');
      expect(memory.reactions.mine, '❤️');
      expect(memory.reactions.countOf('😂'), 3, reason: 'replaced, not added');
      await repository.react('you', 'table', '❤️');
      expect((await memoryOf(repository, 'table')).reactions.mine, isNull);
      expect(repository.react('you', 'table', '💩'), fails);
      // Another member sees the viewer's reaction only as a count.
      await repository.react('you', 'table', '🎉');
      final mira = await memoryOf(repository, 'table', 'mira');
      expect(mira.reactions.mine, isNull);
      expect(mira.reactions.countOf('🎉'), 1);
    });

    test(
      'comments: replies to top-level only; delete own with restore',
      () async {
        final repository = showcase();
        final top = await repository.comment('you', 'table', 'Lovely day');
        final reply = await repository.comment(
          'mira',
          'table',
          'It was!',
          replyTo: top,
        );
        expect(
          repository.comment('you', 'table', 'Deeper', replyTo: reply),
          failsWith('Reply to the first comment'),
        );
        expect(
          repository.comment('you', 'ride', 'Wrong Memory', replyTo: top),
          fails,
          reason: 'parent must be in the same Memory',
        );
        var memory = await memoryOf(repository, 'table');
        expect(memory.comments.firstWhere((c) => c.id == reply).parentId, top);
        expect(
          repository.deleteComment('you', 'table', reply),
          failsWith('your own comments'),
        );
        await repository.deleteComment('you', 'table', top);
        memory = await memoryOf(repository, 'table');
        expect(memory.comments.map((c) => c.id), isNot(contains(top)));
        expect(
          memory.comments.map((c) => c.id),
          isNot(contains(reply)),
          reason: 'replies are hidden with their parent',
        );
        expect(repository.comment('mira', 'table', 'x', replyTo: top), fails);
        await repository.restoreComment('you', 'table', top);
        memory = await memoryOf(repository, 'table');
        expect(memory.comments.map((c) => c.id), containsAll([top, reply]));
      },
    );

    test('edit and delete are author-only; delete is undoable', () async {
      final repository = showcase();
      final id = await repository.createMemory('you', 'family', 'Draft words');
      expect(repository.editMemory('mira', id, 'Hijack'), fails);
      expect(repository.deleteMemory('mira', id), fails);
      expect(repository.editMemory('you', 'table', 'Not mine'), fails);
      expect(repository.editMemory('you', id, '  '), fails);
      await repository.editMemory('you', id, ' Better words ');
      var memory = await memoryOf(repository, id);
      expect(memory.text, 'Better words');
      expect(memory.edited, isTrue);
      await repository.deleteMemory('you', id);
      var ids = (await repository.load('you')).memories.map((m) => m.id);
      expect(ids, isNot(contains(id)));
      expect(repository.react('you', id, '❤️'), fails);
      expect(repository.restoreMemory('mira', id), fails);
      await repository.restoreMemory('you', id);
      ids = (await repository.load('you')).memories.map((m) => m.id);
      expect(ids, contains(id));
    });

    test('polls: vote, change, results visibility, close', () async {
      final repository = showcase();
      var poll = (await memoryOf(repository, 'reunion-poll')).poll!;
      expect(poll.resultsVisible, isFalse, reason: 'after voting');
      expect(poll.options.every((o) => o.count == null), isTrue);
      expect(poll.totalVoters, 3);
      expect(poll.canClose, isTrue, reason: 'you are an admin of the group');
      final canteen = poll.options.first.id, cafe = poll.options[1].id;
      expect(repository.vote('you', 'reunion-poll', {canteen, cafe}), fails);
      await repository.vote('you', 'reunion-poll', {cafe});
      poll = (await memoryOf(repository, 'reunion-poll')).poll!;
      expect(poll.resultsVisible, isTrue);
      expect(poll.myChoices, {cafe});
      expect(poll.options.map((o) => o.count), [2, 2, 0]);
      expect(poll.options.first.voters, ['Mira', 'Sam']);
      await repository.vote('you', 'reunion-poll', {canteen});
      poll = (await memoryOf(repository, 'reunion-poll')).poll!;
      expect(poll.options.map((o) => o.count), [3, 1, 0]);
      await repository.retractVote('you', 'reunion-poll');
      expect((await memoryOf(repository, 'reunion-poll')).poll!.voted, isFalse);
      // A plain member who didn't ask can't close it; an admin can.
      expect(repository.closePoll('sam', 'reunion-poll'), fails);
      await repository.closePoll('you', 'reunion-poll');
      poll = (await memoryOf(repository, 'reunion-poll')).poll!;
      expect(poll.closed, isTrue);
      expect(poll.resultsVisible, isTrue);
      expect(repository.vote('you', 'reunion-poll', {canteen}), fails);
      expect(repository.closePoll('you', 'reunion-poll'), fails);
    });

    test('closed anonymous poll shows counts but never names', () async {
      final poll = (await memoryOf(showcase(), 'route-poll')).poll!;
      expect(poll.closed, isTrue);
      expect(poll.anonymous, isTrue);
      expect(poll.options.map((o) => o.count), [2, 1]);
      expect(poll.options.every((o) => o.voters.isEmpty), isTrue);
      expect(poll.myChoices, hasLength(1));
    });

    test('vote limits: no change when disallowed; closes on time', () async {
      var clock = DateTime.utc(2026, 10, 23);
      final repository = showcase(() => clock);
      final id = await repository.createMemory(
        'you',
        'family',
        '',
        poll: const PollDraft(
          question: 'Lunch time?',
          options: ['Noon', 'One'],
          allowChangeVote: false,
          duration: PollDuration.oneDay,
          resultsVisibility: PollResultsVisibility.afterClosing,
        ),
      );
      var poll = (await memoryOf(repository, id)).poll!;
      await repository.vote('mira', id, {poll.options.first.id});
      await repository.vote('you', id, {poll.options.first.id});
      expect(repository.vote('you', id, {poll.options.last.id}), fails);
      expect(repository.retractVote('you', id), fails);
      poll = (await memoryOf(repository, id)).poll!;
      expect(poll.resultsVisible, isFalse, reason: 'after closing');
      clock = clock.add(const Duration(days: 1));
      poll = (await memoryOf(repository, id)).poll!;
      expect(poll.closed, isTrue);
      expect(poll.options.first.count, 2);
      expect(repository.vote('dev', id, {poll.options.first.id}), fails);
    });

    test('exact-group denial for every Memory mutation', () async {
      final repository = showcase();
      // "you" owns the parent group but is not in this hidden child.
      const hidden = 'private-memory';
      expect(repository.react('you', hidden, '❤️'), fails);
      expect(repository.comment('you', hidden, 'x'), fails);
      expect(repository.editMemory('you', hidden, 'x'), fails);
      expect(repository.deleteMemory('you', hidden), fails);
      // Strangers can't touch polls, reactions or comments anywhere.
      expect(
        repository.vote('stranger', 'reunion-poll', {'reunion-cafe'}),
        fails,
      );
      expect(repository.retractVote('stranger', 'reunion-poll'), fails);
      expect(repository.closePoll('stranger', 'reunion-poll'), fails);
      expect(repository.react('stranger', 'table', '❤️'), fails);
      expect(repository.comment('stranger', 'table', 'Hi'), fails);
      expect(
        repository.deleteComment('stranger', 'table', 'table-comment-1'),
        fails,
      );
      expect(
        repository.createMemory(
          'you',
          'private-plans',
          '',
          photos: [MemoryScene.beachWalk],
        ),
        fails,
      );
      // Members of the parent college group can't vote in a subgroup
      // they aren't in: Noor is in Northbank 2009 but not in Section A.
      final friendsPoll = await repository.createMemory(
        'you',
        'friends',
        '',
        poll: const PollDraft(question: 'Which year?', options: ['1', '2']),
      );
      expect(repository.vote('noor', friendsPoll, {'x'}), fails);
      expect(
        (await repository.load('noor')).memories.map((m) => m.id),
        isNot(contains(friendsPoll)),
      );
    });

    test('reset clears new Memories, reactions, votes and comments', () async {
      final repository = showcase();
      await repository.react('you', 'table', '🔥');
      await repository.vote('you', 'reunion-poll', {'reunion-cafe'});
      await repository.comment('you', 'table', 'Temporary');
      final id = await repository.createMemory('you', 'family', 'Gone soon');
      await repository.deleteMemory('you', id);
      await repository.reset(showcase: true);
      final workspace = await repository.load('you');
      final table = workspace.memories.firstWhere((m) => m.id == 'table');
      expect(table.reactions.mine, isNull);
      expect(table.comments, hasLength(2));
      expect(
        workspace.memories
            .firstWhere((m) => m.id == 'reunion-poll')
            .poll!
            .voted,
        isFalse,
      );
      expect(workspace.memories.map((m) => m.id), isNot(contains(id)));
    });
  });

  group('events (UI-4)', () {
    // 10:00 AM IST on Friday 23 October 2026.
    final start = DateTime.utc(2026, 10, 23, 4, 30);
    const ist = Duration(hours: 5, minutes: 30);
    late DateTime clock;
    MockCircleRepository events() {
      clock = start;
      return showcase(() => clock);
    }

    EventDraft draft(
      String groupId, {
      String title = 'Picnic by the lake',
      EventType type = EventType.other,
      String? venue = 'Lakeside · Fictional venue',
      String? link,
      List<String> coHosts = const [],
      DatePollDraft? datePoll,
      int? capacity,
    }) => EventDraft(
      groupId: groupId,
      title: title,
      type: type,
      startsAt: start.add(const Duration(days: 3)),
      endsAt: start.add(const Duration(days: 3, hours: 2)),
      timeZoneLabel: 'IST',
      utcOffset: ist,
      venue: venue,
      onlineLink: link,
      coHosts: coHosts,
      datePoll: datePoll,
      capacity: capacity,
    );

    test(
      'seeded events are typed, in several groups, and exact-group only',
      () async {
        final workspace = await events().load('you');
        expect(workspace.events.map((event) => event.id), [
          'picnic',
          'lunch',
          'catch-up',
          'cycling',
          'workshop',
          'reunion',
        ]);
        expect(workspace.event('surprise'), isNull);
        final lunch = workspace.event('lunch')!;
        expect(lunch.type, EventType.familyFunction);
        expect(lunch.startsAt, DateTime.utc(2026, 10, 25, 7));
        expect(lunch.timeZoneLabel, 'IST');
        expect(EventRules.attendance(lunch.rsvps).expected, 9);
        final call = workspace.event('catch-up')!;
        expect(
          (call.type, call.venue, call.onlineLink),
          (EventType.online, null, 'meet.example.invalid/cse-catch-up'),
        );
        expect(workspace.event('reunion')!.datePoll!.options, hasLength(3));
        expect(EventRules.hasEnded(workspace.event('picnic')!, start), isTrue);
        expect(
          (await events().load('mira')).event('surprise')!.groupId,
          'private-plans',
        );
      },
    );

    test('create needs exact-group membership and the group setting', () async {
      final repository = events();
      final id = await repository.createEvent('you', draft('family'));
      final created = (await repository.load('you')).event(id)!;
      expect(created.hosts, ['you']);
      expect(created.createdBy, 'you');
      expect((await repository.load('mira')).event(id), isNotNull);
      expect((await repository.load('sam')).event(id), isNull);
      // Not a member of the hidden subgroup, even as owner of its parent.
      expect(
        repository.createEvent('you', draft('private-plans')),
        failsWith('not shared'),
      );
      expect(repository.createEvent('stranger', draft('family')), fails);
      // Studio North limits events to admins.
      expect(
        repository.createEvent('you', draft('work')),
        failsWith('Only admins can create events in Studio North.'),
      );
      await repository.createEvent('dev', draft('work'));
      expect(
        repository.createEvent('you', draft('family', title: ' ')),
        failsWith('title'),
      );
      expect(
        repository.createEvent(
          'you',
          draft('family', type: EventType.online, venue: null),
        ),
        failsWith('link'),
      );
      expect(
        repository.createEvent('you', draft('family', coHosts: ['sam'])),
        failsWith('Co-hosts need to be members'),
      );
      final hosted = await repository.createEvent(
        'you',
        draft('family', coHosts: ['mira', 'you', 'mira']),
      );
      expect((await repository.load('you')).event(hosted)!.hosts, [
        'you',
        'mira',
      ]);
    });

    test('admins switch event creation; members cannot', () async {
      final repository = events();
      await repository.updateSettings(
        'you',
        'family',
        eventCreation: EventCreationPolicy.admins,
      );
      expect(repository.createEvent('dev', draft('family')), fails);
      await repository.createEvent('mira', draft('family'));
      expect(
        repository.updateSettings(
          'dev',
          'family',
          eventCreation: EventCreationPolicy.members,
        ),
        fails,
      );
    });

    test('a date poll is created with the event and voted on', () async {
      final repository = events();
      final slots = [
        start.add(const Duration(days: 5)),
        start.add(const Duration(days: 4)),
      ];
      final id = await repository.createEvent(
        'you',
        draft('club', datePoll: DatePollDraft(slots: slots)),
      );
      var poll = (await repository.load('you')).event(id)!.datePoll!;
      expect(poll.question, 'Which date works for you?');
      expect(poll.options.map((option) => option.label), [
        'Tue 27 Oct · 10:00 AM IST',
        'Wed 28 Oct · 10:00 AM IST',
      ]);
      expect(poll.multipleChoice, isTrue);
      expect(poll.resultsVisible, isTrue);
      await repository.voteEventPoll('mira', id, {poll.options.first.id});
      await repository.voteEventPoll('you', id, {
        for (final option in poll.options) option.id,
      });
      poll = (await repository.load('you')).event(id)!.datePoll!;
      expect(poll.options.first.count, 2);
      await repository.retractEventPollVote('you', id);
      expect(
        (await repository.load('you')).event(id)!.datePoll!.totalVoters,
        1,
      );
      expect(repository.voteEventPoll('sam', id, {}), fails);
      await repository.closeEventPoll('you', id);
      expect((await repository.load('you')).event(id)!.datePoll!.closed, true);
      for (final bad in [
        [slots.first],
        [slots.first, slots.first],
        [slots.first, start.subtract(const Duration(hours: 1))],
      ]) {
        expect(
          repository.createEvent(
            'you',
            draft('club', datePoll: DatePollDraft(slots: bad)),
          ),
          fails,
          reason: '$bad',
        );
      }
      expect(repository.voteEventPoll('you', 'lunch', {'x'}), fails);
    });

    test('hosts and admins edit and cancel; members cannot', () async {
      final repository = events();
      final edit = draft('work', title: 'Pottery evening');
      // A plain member of Studio North who isn't a host.
      expect(
        repository.editEvent('you', 'workshop', edit),
        failsWith('Only the hosts or a group admin'),
      );
      expect(repository.cancelEvent('you', 'workshop'), fails);
      // A co-host.
      await repository.editEvent('lena', 'workshop', edit);
      var workshop = (await repository.load('dev')).event('workshop')!;
      expect(workshop.title, 'Pottery evening');
      expect(workshop.edited, isTrue);
      expect(workshop.capacity, isNull, reason: 'blank fields clear');
      // An admin of Northbank 2009 who didn't create the reunion.
      await repository.editEvent(
        'you',
        'reunion',
        draft('college', title: 'Reunion dinner'),
      );
      expect(
        repository.editEvent('you', 'reunion', draft('family')),
        failsWith('another group'),
      );
      await repository.cancelEvent('you', 'cycling');
      final cycling = (await repository.load('you')).event('cycling')!;
      expect(cycling.cancelled, isTrue);
      expect(
        repository.rsvp('you', 'cycling', const Rsvp(Attendance.going)),
        failsWith('cancelled'),
      );
      expect(repository.editEvent('you', 'cycling', draft('club')), fails);
      expect(repository.cancelEvent('you', 'cycling'), fails);
      expect(repository.cancelEvent('you', 'picnic'), failsWith('ended'));
      expect(repository.cancelEvent('you', 'surprise'), fails);
      workshop = (await repository.load('you')).event('workshop')!;
      expect(workshop.title, 'Pottery evening');
    });

    test('RSVP rules: capacity, guests, past, deadline and clearing', () async {
      final repository = events();
      expect(
        repository.rsvp('you', 'workshop', const Rsvp(Attendance.going)),
        failsWith('This event is full'),
      );
      await repository.rsvp(
        'you',
        'workshop',
        const Rsvp(Attendance.maybe, guests: 2),
      );
      await repository.rsvp(
        'you',
        'lunch',
        const Rsvp(Attendance.going, guests: 3, note: '  After the temple  '),
      );
      var lunch = (await repository.load('you')).event('lunch')!;
      expect(
        lunch.rsvpOf('you'),
        const Rsvp(Attendance.going, guests: 3, note: 'After the temple'),
      );
      expect(EventRules.attendance(lunch.rsvps).expected, 13);
      expect(
        repository.rsvp(
          'you',
          'lunch',
          const Rsvp(Attendance.going, guests: 21),
        ),
        fails,
      );
      expect(
        repository.rsvp(
          'you',
          'lunch',
          const Rsvp(Attendance.notGoing, guests: 1),
        ),
        fails,
      );
      expect(
        repository.rsvp('you', 'picnic', const Rsvp(Attendance.maybe)),
        failsWith('ended'),
      );
      expect(
        repository.rsvp('you', 'surprise', const Rsvp(Attendance.going)),
        fails,
      );
      // After the deadline (8 PM IST the day before), nothing changes.
      clock = DateTime.utc(2026, 10, 24, 14, 30);
      expect(repository.rsvp('you', 'lunch', null), failsWith('deadline'));
      clock = start;
      await repository.rsvp('you', 'lunch', null);
      lunch = (await repository.load('you')).event('lunch')!;
      expect(lunch.rsvpOf('you'), isNull);
      expect(repository.rsvp('you', 'lunch', null), fails);
    });

    test(
      'people who leave drop out of attendees; reset clears events',
      () async {
        final repository = events();
        await repository.removeMember('you', 'family', 'dev');
        final lunch = (await repository.load('you')).event('lunch')!;
        expect(lunch.rsvps.keys, isNot(contains('dev')));
        final id = await repository.createEvent(
          'you',
          draft(
            'club',
            datePoll: DatePollDraft(
              slots: [
                start.add(const Duration(days: 4)),
                start.add(const Duration(days: 5)),
              ],
            ),
          ),
        );
        await repository.reset(showcase: true);
        final workspace = await repository.load('you');
        expect(workspace.event(id), isNull);
        expect(workspace.event('lunch')!.rsvps.keys, contains('dev'));
        await repository.reset(showcase: false);
        expect((await repository.load('you')).events, isEmpty);
      },
    );
  });
}
