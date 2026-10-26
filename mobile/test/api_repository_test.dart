import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/features/workspace/data/api/api_circle_repository.dart';
import 'package:mobile/features/workspace/domain/circle_repository.dart';
import 'support/fake_api.dart';

final config = ApiConfig.parse('http://circle.test/api/v1')!;

/// A repository signed in as [user] on [server].
Future<ApiCircleRepository> signedIn(
  FakeCircleServer server,
  int user, {
  Duration undoWindow = Duration.zero,
}) async {
  final api = ApiClient(
    config: config,
    tokens: MemoryTokenStore(),
    adapter: server.adapter,
  );
  final mobile = server.users[user]!['mobile'] as String;
  final login = await api.post(
    '/auth/login',
    auth: false,
    body: {'mobile': mobile, 'password': server.passwords[mobile]},
  );
  await api.saveTokens(api.tokensFrom(login));
  return ApiCircleRepository(
    api: api,
    viewer: '$user',
    viewerName: server.users[user]!['display_name'] as String,
    undoWindow: undoWindow,
  );
}

void main() {
  late FakeCircleServer server;
  late int asha, dev;

  setUp(() {
    server = FakeCircleServer(pageSize: 2);
    asha = server.addUser('+15550000001', 'a' * 20, 'Asha');
    dev = server.addUser('+15550000002', 'd' * 20, 'Dev');
  });

  test(
    'scoped saved, group and search pages find Memories beyond Home',
    () async {
      final target = server.addGroup('Fictional target', asha);
      final other = server.addGroup('Fictional recent', asha);
      final old = server.addMemory(target, asha, 'Old fictional reunion');
      server.saves[old] = {asha};
      for (var i = 0; i < 5; i++) {
        server.addMemory(other, asha, 'New fictional Memory $i');
      }
      final repo = await signedIn(server, asha);
      final home = await repo.load('$asha');
      expect(home.memories.any((m) => m.id == '$old'), isFalse);
      for (final query in [
        MemoryQuery(groupId: '$target'),
        const MemoryQuery(saved: true),
        const MemoryQuery(text: 'reunion'),
      ]) {
        final page = await repo.queryMemories('$asha', query);
        expect(page.items.map((m) => m.id), ['$old']);
        expect(page.hasMore, isFalse);
      }
      await repo.editMemory('$asha', '$old', 'Edited fictional reunion');
      await repo.react('$asha', '$old', '❤️');
      await repo.comment('$asha', '$old', 'Fictional reply');
      await repo.saveMemory('$asha', '$old');
      expect(
        (await repo.queryMemories(
          '$asha',
          const MemoryQuery(saved: true),
        )).items,
        isEmpty,
      );
      expect(await repo.refreshMemory('$asha', '$old'), isTrue);
      expect(
        (await repo.load(
          '$asha',
        )).memories.firstWhere((m) => m.id == '$old').text,
        'Edited fictional reunion',
      );
      final query = MemoryQuery(groupId: '$other');
      final first = await repo.queryMemories('$asha', query);
      final next = await repo.queryMemories(
        '$asha',
        query,
        cursor: first.cursor,
      );
      expect(first.hasMore, isTrue);
      expect(
        first.items
            .map((m) => m.id)
            .toSet()
            .intersection(next.items.map((m) => m.id).toSet()),
        isEmpty,
      );
      repo.dispose();
    },
  );

  test('a new account starts with an empty workspace', () async {
    final repo = await signedIn(server, asha);
    final workspace = await repo.load('$asha');
    expect(workspace.groups, isEmpty);
    expect(workspace.memories, isEmpty);
    expect(workspace.events, isEmpty, reason: 'events are not on the server');
    expect(workspace.hasMoreMemories, isFalse);
    expect(workspace.nameOf('$asha'), 'You');
  });

  test('groups load with every member’s role and the owner', () async {
    final family = server.addGroup('Sharma Family', asha);
    server.members[family]![dev] = 'member';
    final sub = server.addGroup('Cousins', asha, parent: family);
    final repo = await signedIn(server, dev);
    final workspace = await repo.load('$dev');
    expect(workspace.groups.map((g) => g.name), ['Sharma Family']);
    final group = workspace.group('$family')!;
    expect(group.ownerId, '$asha');
    expect(group.roles['$dev'], CircleRole.member);
    expect(workspace.isAdminOf('$family'), isFalse);
    expect(workspace.nameOf('$asha'), 'Asha');
    expect(workspace.group('$sub'), isNull, reason: 'exact membership only');
    // Admin-only lists aren't requested for a member.
    expect(server.adapter.count('GET', '/groups/$family/join-requests'), 0);
    // A second load comes from the cache: no new requests.
    final before = server.adapter.requests.length;
    await repo.load('$dev');
    expect(server.adapter.requests.length, before);
  });

  test('create a group and a subgroup; approval stays on by default', () async {
    final repo = await signedIn(server, asha);
    await repo.load('$asha');
    final group = await repo.createGroup(
      '$asha',
      '  Sunday Cyclists ',
      CircleType.club,
    );
    expect(group.name, 'Sunday Cyclists');
    expect(group.roles['$asha'], CircleRole.owner);
    expect(server.groups[int.parse(group.id)]!['approval_mode'], 'manual');
    final sub = await repo.createGroup(
      '$asha',
      'Climbers',
      CircleType.club,
      parentId: group.id,
      hidden: true,
    );
    expect(sub.parentId, group.id);
    expect(sub.hidden, isTrue);
    final workspace = await repo.load('$asha');
    expect(workspace.groups, hasLength(2));
    await expectLater(
      repo.createGroup('$asha', '   ', CircleType.club),
      throwsA(isA<CircleFailure>()),
    );
  });

  test('Memories: share, react (emoji known), comment, save, edit', () async {
    final group = server.addGroup('Family', asha);
    server.members[group]![dev] = 'member';
    final repo = await signedIn(server, asha);
    await repo.load('$asha');
    final id = await repo.createMemory(
      '$asha',
      '$group',
      '  First rain  ',
      takenYear: 2007,
      place: ' Home ',
    );
    var memory = (await repo.load('$asha')).memories.single;
    expect(memory.id, id);
    expect(memory.text, 'First rain');
    expect(memory.author, 'You');
    expect(memory.takenYear, 2007);
    expect(memory.place, 'Home');
    final sent = server.adapter.requests
        .lastWhere((r) => r.path == '/groups/$group/memories')
        .json;
    expect(sent['body'], 'First rain');
    expect(sent['memory_date'], '2007-01-01');

    await repo.react('$asha', id, '🎉');
    memory = (await repo.load('$asha')).memories.single;
    expect(memory.reactions.mine, '🎉');
    await repo.loveMemory('$asha', id);
    memory = (await repo.load('$asha')).memories.single;
    expect(memory.loved, isTrue);

    final commentId = await repo.comment('$asha', id, ' Lovely ');
    await repo.comment('$asha', id, 'Reply', replyTo: commentId);
    memory = (await repo.load('$asha')).memories.single;
    expect(memory.comments, hasLength(2));
    expect(memory.comments.last.parentId, commentId);

    await repo.saveMemory('$asha', id);
    expect((await repo.load('$asha')).memories.single.saved, isTrue);

    await repo.editMemory('$asha', id, 'First rain of 2007');
    memory = (await repo.load('$asha')).memories.single;
    expect(memory.text, 'First rain of 2007');
    expect(memory.edited, isTrue);
  });

  test('cursor pagination and reactions completed from details', () async {
    final group = server.addGroup('Family', asha);
    server.members[group]![dev] = 'member';
    for (var i = 0; i < 5; i++) {
      server.addMemory(
        group,
        dev,
        'Memory $i',
        created: '2026-10-2${i + 1} 10:00:00',
      );
    }
    // Asha reacted to the newest one: the list only says "reacted".
    server.reactions[server.memories.first['id'] as int] = {
      asha: '😂',
      dev: '🎉',
    };
    final repo = await signedIn(server, asha);
    var workspace = await repo.load('$asha');
    expect(workspace.memories.map((m) => m.text), ['Memory 4', 'Memory 3']);
    expect(workspace.hasMoreMemories, isTrue);
    expect(workspace.memories.first.reactions.mine, '😂');
    expect(workspace.memories.first.reactions.countOf('🎉'), 1);
    expect(await repo.loadMoreMemories('$asha'), isTrue);
    expect(await repo.loadMoreMemories('$asha'), isTrue);
    workspace = await repo.load('$asha');
    expect(workspace.memories, hasLength(5));
    expect(workspace.hasMoreMemories, isFalse);
    expect(await repo.loadMoreMemories('$asha'), isFalse);
    final cursors = [
      for (final r in server.adapter.requests)
        if (r.path == '/memories') r.query['cursor'],
    ];
    expect(cursors, [null, '2', '4']);
  });

  test('delete waits for Undo, then deletes on the server', () async {
    final group = server.addGroup('Family', asha);
    final repo = await signedIn(
      server,
      asha,
      undoWindow: const Duration(milliseconds: 30),
    );
    await repo.load('$asha');
    final id = await repo.createMemory('$asha', '$group', 'Oops');
    await repo.deleteMemory('$asha', id);
    expect((await repo.load('$asha')).memories, isEmpty);
    await repo.restoreMemory('$asha', id);
    expect((await repo.load('$asha')).memories, hasLength(1));
    expect(server.memories, hasLength(1));
    await repo.deleteMemory('$asha', id);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(server.memories, isEmpty);
    await expectLater(
      repo.restoreMemory('$asha', id),
      throwsA(isA<CircleFailure>()),
    );
  });

  test('invite link: create (token once), preview, join', () async {
    final group = server.addGroup('Sunday Cyclists', asha, type: 'club');
    server.groups[group]!['approval_mode'] = 'auto';
    final owner = await signedIn(server, asha);
    await owner.load('$asha');
    final link = await owner.createInviteLink('$asha', '$group');
    expect(link.token, contains('TokenCaseSensitive'));
    expect(
      (await owner.load('$asha')).group('$group')!.inviteLink?.token,
      link.token,
    );

    final guest = await signedIn(server, dev);
    expect((await guest.load('$dev')).groups, isEmpty);
    final preview = await guest.previewInvite(
      '$dev',
      inviteLinkFor(link.token),
    );
    expect(preview.status, InviteLinkStatus.valid);
    expect(preview.group?.name, 'Sunday Cyclists');
    expect(preview.group?.approvalRequired, isFalse);
    expect(await guest.joinWithLink('$dev', link.token), JoinOutcome.joined);
    expect((await guest.load('$dev')).groups.single.name, 'Sunday Cyclists');

    final unknown = await guest.previewInvite('$dev', 'NoSuchTokenAnywhere123');
    expect(unknown.status, InviteLinkStatus.unknown);
    server.links[link.token]!['revoked'] = true;
    expect(
      (await guest.previewInvite('$dev', link.token)).status,
      InviteLinkStatus.reset,
    );
  });

  test('join requests: admins see and approve them', () async {
    final group = server.addGroup('Family', asha);
    server.joinRequests[group] = [
      {
        'id': 99,
        'user_id': dev,
        'status': 'pending',
        'message': '',
        'created_at': '2026-10-23 09:00:00',
        'display_name': 'Dev',
        'avatar_path': null,
      },
    ];
    final repo = await signedIn(server, asha);
    final workspace = await repo.load('$asha');
    expect(workspace.joinRequests.single.person, '$dev');
    expect(workspace.nameOf('$dev'), 'Dev');
    server.adapter.handler = (request) {
      if (request.path == '/groups/$group/join-requests/99/approve') {
        server.members[group]![dev] = 'member';
        return FakeResponse.ok(null);
      }
      return server.handle(request);
    };
    await repo.approveRequest('$asha', '99');
    final after = await repo.load('$asha');
    expect(after.joinRequests, isEmpty);
    expect(after.group('$group')!.roles['$dev'], CircleRole.member);
  });

  test('not on the server yet: calm failures, no fake data', () async {
    final group = server.addGroup('Family', asha);
    final repo = await signedIn(server, asha);
    await repo.load('$asha');
    for (final call in <Future<Object?> Function()>[
      () => repo.createEvent(
        '$asha',
        EventDraft(
          groupId: '$group',
          title: 'x',
          venue: 'y',
          startsAt: DateTime.utc(2027),
          timeZoneLabel: 'UTC',
          utcOffset: Duration.zero,
        ),
      ),
      () => repo.report(
        '$asha',
        ReportDraft(
          target: ReportTarget.memory('1', groupId: '$group'),
          reason: ReportReason.spam,
        ),
      ),
      () => repo.inviteMember('$asha', '$group', '$dev'),
      () => repo.createMemory(
        '$asha',
        '$group',
        'Q',
        poll: const PollDraft(question: 'Q?', options: ['a', 'b']),
      ),
      () => repo.requestToJoin('$asha', '$group'),
    ]) {
      await expectLater(
        call(),
        throwsA(
          isA<CircleFailure>().having(
            (e) => e.message,
            'message',
            contains('on the server yet'),
          ),
        ),
      );
    }
  });

  test('leaving removes the group and its Memories locally', () async {
    final group = server.addGroup('Family', dev);
    server.members[group]![asha] = 'member';
    server.addMemory(group, dev, 'Hello');
    final repo = await signedIn(server, asha);
    expect((await repo.load('$asha')).memories, hasLength(1));
    await repo.leaveGroup('$asha', '$group');
    final workspace = await repo.load('$asha');
    expect(workspace.groups, isEmpty);
    expect(workspace.memories, isEmpty);
  });
}
