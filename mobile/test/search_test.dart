import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/data/mock_chat_repository.dart';
import 'package:mobile/features/search/domain/search_rules.dart';
import 'package:mobile/features/workspace/data/mock_circle_repository.dart';
import 'package:mobile/features/workspace/domain/circle_repository.dart';

final fixed = DateTime.utc(2026, 10, 23, 12);

({MockCircleRepository groups, MockChatRepository chat}) setup({
  DateTime Function()? clock,
}) {
  final now = clock ?? () => fixed;
  final groups = MockCircleRepository(showcase: true, now: now);
  return (
    groups: groups,
    chat: MockChatRepository(
      groups: groups,
      moderation: groups,
      showcase: true,
      now: now,
    ),
  );
}

Future<SearchCorpus> corpus(
  ({MockCircleRepository groups, MockChatRepository chat}) s, [
  String viewer = 'you',
]) async => SearchCorpus(
  workspace: await s.groups.load(viewer),
  messages: await s.chat.readableMessages(viewer),
  blocked: (await s.chat.privacy(viewer)).settings.blocked,
);

void main() {
  test('needs at least 2 characters; case-insensitive', () async {
    final c = await corpus(setup());
    expect(SearchRules.ready(' a '), isFalse);
    expect(SearchRules.search('a', c).isEmpty, isTrue);
    final results = SearchRules.search('SUNDAY', c);
    expect(
      results.groups.map((g) => g.name),
      containsAll(['The Sunday table', 'Sunday miles']),
    );
  });

  test('results are grouped by kind', () async {
    final results = SearchRules.search('reunion', await corpus(setup()));
    expect(results.memories.map((m) => m.id), contains('reunion-poll'));
    expect(results.events.map((e) => e.id), contains('reunion'));
    expect(results.groups, isEmpty);
    final people = SearchRules.search('mira', await corpus(setup()));
    expect(people.people.single.name, 'Mira');
    expect(people.people.single.groups, contains('The Sunday table'));
    final messages = SearchRules.search('spare lid', await corpus(setup()));
    expect(messages.messages.single.conversationTitle, 'The Sunday table');
  });

  test('hidden subgroups only for members; listed ones can be found', () async {
    final s = setup();
    final mine = SearchRules.search('plan', await corpus(s));
    expect(mine.groups.map((g) => g.id), isNot(contains('private-plans')));
    expect(mine.memories.map((m) => m.id), isNot(contains('private-memory')));
    expect(mine.events.map((e) => e.id), isNot(contains('surprise')));
    final listed = SearchRules.search('memes', await corpus(s));
    expect(listed.groups.single.member, isFalse);
    expect(listed.groups.single.where, 'in Northbank 2009');
    // Mira is in the hidden subgroup, so she finds it and its content.
    final mira = SearchRules.search('surprise', await corpus(s, 'mira'));
    expect(mira.groups.map((g) => g.id), contains('private-plans'));
    expect(mira.events.map((e) => e.id), contains('surprise'));
    // The committee is hidden and the viewer is not in it.
    final committee = SearchRules.search('committee', await corpus(s));
    expect(committee.isEmpty, isTrue);
  });

  test('blocked people are never offered', () async {
    final s = setup();
    expect(SearchRules.search('dev', await corpus(s)).people.map((p) => p.id), [
      'dev',
    ]);
    await s.chat.block('you', 'dev');
    expect(SearchRules.search('dev', await corpus(s)).people, isEmpty);
  });

  test('messages: only readable chats, frozen at leave time', () async {
    var now = fixed;
    final s = setup(clock: () => now);
    expect(
      SearchRules.search('second weekend', await corpus(s)).messages,
      hasLength(1),
    );
    // The viewer leaves Northbank 2009 (and its subgroups).
    now = fixed.add(const Duration(minutes: 1));
    await s.groups.leaveGroup('you', 'college');
    // The chat's history up to the leave stays readable and searchable.
    await s.chat.inbox('you');
    now = fixed.add(const Duration(minutes: 5));
    await s.chat.send(
      'mira',
      'g-college',
      clientMessageId: 'after-leave',
      text: 'A secret after you left',
    );
    final after = await corpus(s);
    expect(
      SearchRules.search('second weekend', after).messages,
      hasLength(1),
      reason: 'history up to leaving is kept',
    );
    expect(SearchRules.search('secret after', after).messages, isEmpty);
    // Memories of the group left are gone from search.
    expect(
      SearchRules.search('fifteen', after).memories.map((m) => m.id),
      isNot(contains('reunion-poll')),
    );
    // Other people's 1:1 chats are never searchable.
    final mira = await corpus(s, 'mira');
    expect(SearchRules.search('ha, ignored', mira).messages, isEmpty);
  });

  test('defensive scoping: items outside member groups are dropped', () async {
    final s = setup();
    final workspace = await s.groups.load('you');
    final leaked = CircleWorkspace(
      viewer: 'you',
      groups: workspace.groups,
      memories: [
        ...workspace.memories,
        CircleMemory(
          id: 'leak',
          groupId: 'private-plans',
          authorId: 'mira',
          author: 'Mira',
          text: 'Leaky plan',
          createdAt: fixed,
        ),
      ],
      events: workspace.events,
    );
    expect(
      SearchRules.search('leaky', SearchCorpus(workspace: leaked)).isEmpty,
      isTrue,
    );
  });
}
