import '../../../core/rule_result.dart';

/// The only reactions a Memory accepts, in display order. Matches the
/// backend allowlist; anything else is rejected.
const memoryReactions = ['❤️', '😂', '😮', '😢', '🙏', '👍', '🎉', '🔥'];

/// The one-tap reaction behind the Love button.
const loveReaction = '❤️';

/// Plain words for each reaction, used by screen readers.
const memoryReactionNames = {
  '❤️': 'Love',
  '😂': 'Laugh',
  '😮': 'Wow',
  '😢': 'Sad',
  '🙏': 'Thanks',
  '👍': 'Like',
  '🎉': 'Celebrate',
  '🔥': 'Fire',
};

/// What one viewer sees: their own reaction (at most one) and how many
/// other people chose each emoji. Names are not part of the preview.
class MemoryReactions {
  MemoryReactions({
    this.mine,
    Map<String, int> others = const {},
    int unsorted = 0,
  }) : others = Map.unmodifiable({
         for (final entry in others.entries)
           if (entry.value > 0) entry.key: entry.value,
       }),
       unsorted = unsorted < 0 ? 0 : unsorted;

  /// The viewer's reaction, or null.
  final String? mine;

  /// Counts of other people's reactions per emoji.
  final Map<String, int> others;

  /// Other people's reactions known only as a count (a server list gives
  /// totals; the breakdown arrives when the Memory is opened).
  final int unsorted;

  int countOf(String emoji) => (others[emoji] ?? 0) + (mine == emoji ? 1 : 0);

  int get total =>
      others.values.fold(0, (sum, count) => sum + count) +
      unsorted +
      (mine == null ? 0 : 1);

  /// Emoji with at least one reaction, most used first; ties keep the
  /// allowlist order.
  List<({String emoji, int count})> get ranked {
    final list = [
      for (final emoji in memoryReactions)
        if (countOf(emoji) > 0) (emoji: emoji, count: countOf(emoji)),
    ];
    list.sort((a, b) {
      final order = b.count.compareTo(a.count);
      return order != 0
          ? order
          : memoryReactions
                .indexOf(a.emoji)
                .compareTo(memoryReactions.indexOf(b.emoji));
    });
    return list;
  }

  /// Summary for screen readers: "15 reactions: 12 Love, 3 Laugh".
  String describe() {
    if (total == 0) return 'No reactions yet';
    if (ranked.isEmpty) {
      return '$total ${total == 1 ? 'reaction' : 'reactions'}';
    }
    final parts = [
      for (final item in ranked)
        '${item.count} ${memoryReactionNames[item.emoji]}',
      if (unsorted > 0) '$unsorted more',
    ];
    return '$total ${total == 1 ? 'reaction' : 'reactions'}: '
        '${parts.join(', ')}';
  }
}

/// Pure reaction rules: allowlist, one reaction per person, toggle.
abstract final class ReactionRules {
  static bool isAllowed(String emoji) => memoryReactions.contains(emoji);

  static RuleResult check(String emoji) => isAllowed(emoji)
      ? const RuleResult.allowed()
      : const RuleResult.denied('That reaction isn’t available.');

  /// Applies [emoji] for [person]: choosing the same reaction again removes
  /// it; choosing another replaces it. Returns a new map.
  static Map<String, String> toggle(
    Map<String, String> byPerson,
    String person,
    String emoji,
  ) {
    final next = Map<String, String>.of(byPerson);
    if (next[person] == emoji) {
      next.remove(person);
    } else {
      next[person] = emoji;
    }
    return next;
  }

  /// The viewer's projection of everyone's reactions.
  static MemoryReactions viewFor(Map<String, String> byPerson, String viewer) {
    final others = <String, int>{};
    for (final entry in byPerson.entries) {
      if (entry.key == viewer) continue;
      others[entry.value] = (others[entry.value] ?? 0) + 1;
    }
    return MemoryReactions(mine: byPerson[viewer], others: others);
  }
}
