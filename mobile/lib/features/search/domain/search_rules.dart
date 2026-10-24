/// Search (I2), scoped to the viewer's own circles. Pure Dart.
library;

import '../../chat/domain/chat_models.dart';
import '../../workspace/domain/circle_workspace.dart';

/// Everything search may look at, as the viewer can already see it.
class SearchCorpus {
  SearchCorpus({
    required this.workspace,
    List<ReadableMessage> messages = const [],
    Set<String> blocked = const {},
  }) : messages = List.unmodifiable(messages),
       blocked = Set.unmodifiable(blocked);
  final CircleWorkspace workspace;

  /// Messages from conversations the viewer can read (including the frozen
  /// history of groups they left).
  final List<ReadableMessage> messages;

  /// People the viewer blocked: never offered in People.
  final Set<String> blocked;
}

class GroupHit {
  const GroupHit({
    required this.id,
    required this.name,
    required this.where,
    required this.member,
    required this.memberCount,
    required this.type,
  });
  final String id, name;
  final CircleType type;

  /// "in Northbank 2009", or empty for a top-level group.
  final String where;

  /// False for listed subgroups the viewer could ask to join.
  final bool member;
  final int memberCount;
}

class PersonHit {
  const PersonHit({required this.id, required this.name, required this.groups});
  final String id, name;

  /// Names of groups you share.
  final List<String> groups;
}

class SearchResults {
  SearchResults({
    List<GroupHit> groups = const [],
    List<PersonHit> people = const [],
    List<CircleMemory> memories = const [],
    List<CircleEvent> events = const [],
    List<ReadableMessage> messages = const [],
  }) : groups = List.unmodifiable(groups),
       people = List.unmodifiable(people),
       memories = List.unmodifiable(memories),
       events = List.unmodifiable(events),
       messages = List.unmodifiable(messages);
  final List<GroupHit> groups;
  final List<PersonHit> people;
  final List<CircleMemory> memories;
  final List<CircleEvent> events;
  final List<ReadableMessage> messages;

  int get total =>
      groups.length +
      people.length +
      memories.length +
      events.length +
      messages.length;
  bool get isEmpty => total == 0;
}

/// Pure search rules. Scoping is strict and repeated here even though the
/// workspace is already filtered: exact-group membership only, hidden
/// subgroups only for their members, nobody you blocked, and only messages
/// you can read.
abstract final class SearchRules {
  static const minLength = 2, maxPerSection = 20;

  static bool ready(String query) => query.trim().runes.length >= minLength;

  static bool _has(String? value, String query) =>
      value != null && value.toLowerCase().contains(query);

  static SearchResults search(String input, SearchCorpus corpus) {
    if (!ready(input)) return SearchResults();
    final query = input.trim().toLowerCase();
    final workspace = corpus.workspace;
    final viewer = workspace.viewer;
    final mine = {
      for (final group in workspace.groups)
        if (group.isMember(viewer)) group.id: group,
    };
    String where(String? parentId) {
      final parent = parentId == null ? null : mine[parentId];
      return parent == null ? '' : 'in ${parent.name}';
    }

    final groups = <GroupHit>[
      for (final group in mine.values)
        if (_has(group.name, query))
          GroupHit(
            id: group.id,
            name: group.name,
            where: where(group.parentId),
            member: true,
            memberCount: group.roles.length,
            type: group.type,
          ),
      // Listed subgroups of the viewer's groups (never hidden ones).
      for (final preview in workspace.discoverable)
        if (mine.containsKey(preview.parentId) &&
            !mine.containsKey(preview.id) &&
            _has(preview.name, query))
          GroupHit(
            id: preview.id,
            name: preview.name,
            where: where(preview.parentId),
            member: false,
            memberCount: preview.memberCount,
            type: preview.type,
          ),
    ];

    final shared = <String, List<String>>{};
    for (final group in mine.values) {
      for (final person in group.roles.keys) {
        if (person == viewer || corpus.blocked.contains(person)) continue;
        shared.putIfAbsent(person, () => []).add(group.name);
      }
    }
    final people = [
      for (final entry in shared.entries)
        if (_has(workspace.nameOf(entry.key), query))
          PersonHit(
            id: entry.key,
            name: workspace.nameOf(entry.key),
            groups: entry.value,
          ),
    ]..sort((a, b) => a.name.compareTo(b.name));

    final memories = [
      for (final memory in workspace.memories)
        if (mine.containsKey(memory.groupId) &&
            !workspace.isHidden(ReportKind.memory, memory.id) &&
            (_has(memory.text, query) ||
                _has(memory.author, query) ||
                _has(memory.place, query) ||
                _has(memory.poll?.question, query)))
          memory,
    ];
    final events = [
      for (final event in workspace.events)
        if (mine.containsKey(event.groupId) &&
            !workspace.isHidden(ReportKind.event, event.id) &&
            (_has(event.title, query) ||
                _has(event.venue, query) ||
                _has(event.description, query)))
          event,
    ];
    final messages = [
      for (final message in corpus.messages)
        if (_has(message.text, query)) message,
    ]..sort((a, b) => b.at.compareTo(a.at));

    List<T> cap<T>(List<T> list) => list.take(maxPerSection).toList();
    return SearchResults(
      groups: cap(groups),
      people: cap(people),
      memories: cap(memories),
      events: cap(events),
      messages: cap(messages),
    );
  }
}
