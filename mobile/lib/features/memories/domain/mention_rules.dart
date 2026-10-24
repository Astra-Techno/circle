/// @mentions in group chats and Memory comments (README §3.2, §3.7).
/// Pure Dart; no Flutter imports.
///
/// A mention is recorded when the person picks a suggestion: the message
/// or comment stores `person id → name as written`. Only members of the
/// exact group can be suggested or kept; typing "@Name" by hand never
/// notifies anyone.
library;

/// Someone who can be mentioned.
class MentionCandidate {
  const MentionCandidate({required this.id, required this.name});
  final String id, name;
}

/// A piece of text: plain, or one "@Name" mention.
typedef MentionSegment = ({String text, bool mention});

abstract final class MentionRules {
  /// Suggestions shown at once.
  static const maxSuggestions = 5;

  /// Characters that can follow "@" while typing a name.
  static final _queryChar = RegExp(r"[\p{L}\p{N}_.'-]", unicode: true);
  static final _wordChar = RegExp(r'[\p{L}\p{N}_]', unicode: true);

  /// The "@query" being typed just before [cursor], or null. The "@" must
  /// start the text or follow a space, and at least one letter must
  /// follow it ("@" alone suggests nothing yet).
  static ({int start, String query})? activeQuery(String text, int cursor) {
    if (cursor < 0 || cursor > text.length) return null;
    var index = cursor - 1;
    while (index >= 0 && _queryChar.hasMatch(text[index])) {
      index--;
    }
    if (index < 0 || text[index] != '@') return null;
    if (index > 0 && !RegExp(r'\s').hasMatch(text[index - 1])) return null;
    final query = text.substring(index + 1, cursor);
    if (query.isEmpty) return null;
    return (start: index, query: query);
  }

  /// Members of the exact group whose name (or any word of it) starts
  /// with [query], ignoring case. Never the viewer, never anyone in
  /// [blocked], never anyone outside [members]. Sorted by name; at most
  /// [maxSuggestions].
  static List<MentionCandidate> suggestions({
    required String query,
    required Iterable<MentionCandidate> members,
    required String viewer,
    Set<String> blocked = const {},
  }) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final seen = <String>{};
    final found = [
      for (final member in members)
        if (member.id != viewer &&
            !blocked.contains(member.id) &&
            seen.add(member.id) &&
            (member.name.toLowerCase().startsWith(needle) ||
                member.name
                    .toLowerCase()
                    .split(RegExp(r'\s+'))
                    .any((word) => word.startsWith(needle))))
          member,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return found.take(maxSuggestions).toList();
  }

  /// Replaces the "@query" that starts at [start] (up to [cursor]) with
  /// "@Name ". Returns the new text and where the cursor goes.
  static ({String text, int cursor}) insert(
    String text, {
    required int start,
    required int cursor,
    required String name,
  }) {
    final mention = '@$name ';
    final after = text.substring(cursor);
    // Don't double the space if one already follows.
    final insert = after.startsWith(' ') ? '@$name' : mention;
    return (
      text: '${text.substring(0, start)}$insert$after',
      cursor: start + insert.length + (after.startsWith(' ') ? 1 : 0),
    );
  }

  /// Whether "@[name]" appears in [text] as a whole name (not followed by
  /// another letter or digit).
  static bool mentions(String text, String name) {
    final needle = '@$name';
    var from = 0;
    while (true) {
      final index = text.indexOf(needle, from);
      if (index < 0) return false;
      final end = index + needle.length;
      final boundaryBefore = index == 0 || !_wordChar.hasMatch(text[index - 1]);
      final boundaryAfter =
          end >= text.length || !_wordChar.hasMatch(text[end]);
      if (boundaryBefore && boundaryAfter) return true;
      from = index + 1;
    }
  }

  /// The mentions to store with [text]: picked people whose "@Name" is
  /// still in the text and who are still members of the exact group.
  /// Duplicates collapse to one entry per person.
  static Map<String, String> resolve({
    required String text,
    required Map<String, String> picked,
    required Set<String> members,
  }) => {
    for (final entry in picked.entries)
      if (members.contains(entry.key) && mentions(text, entry.value))
        entry.key: entry.value,
  };

  /// Who gets an Activity item for a message by [author]: everyone
  /// mentioned except the author (a self-mention notifies nobody).
  static Set<String> recipients(Map<String, String> mentions, String author) =>
      {...mentions.keys}..remove(author);

  /// [text] split into plain parts and "@Name" mentions for display.
  /// Longer names win ("@Mira Rao" before "@Mira").
  static List<MentionSegment> segments(String text, Iterable<String> names) {
    final ordered = {...names.where((name) => name.isNotEmpty)}.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (ordered.isEmpty) return [(text: text, mention: false)];
    final result = <MentionSegment>[];
    final plain = StringBuffer();
    var index = 0;
    while (index < text.length) {
      String? hit;
      if (text[index] == '@' &&
          (index == 0 || !_wordChar.hasMatch(text[index - 1]))) {
        for (final name in ordered) {
          final end = index + 1 + name.length;
          if (end <= text.length &&
              text.substring(index + 1, end) == name &&
              (end == text.length || !_wordChar.hasMatch(text[end]))) {
            hit = '@$name';
            break;
          }
        }
      }
      if (hit == null) {
        plain.write(text[index]);
        index++;
        continue;
      }
      if (plain.isNotEmpty) {
        result.add((text: plain.toString(), mention: false));
        plain.clear();
      }
      result.add((text: hit, mention: true));
      index += hit.length;
    }
    if (plain.isNotEmpty) result.add((text: plain.toString(), mention: false));
    return result;
  }
}
