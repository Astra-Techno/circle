import '../../../core/rule_result.dart';
import 'memory_comment.dart';
import 'memory_photo.dart';
import 'memory_poll.dart';
import 'memory_reaction.dart';

export '../../../core/rule_result.dart';
export 'memory_comment.dart';
export 'mention_rules.dart';
export 'memory_photo.dart';
export 'memory_poll.dart';
export 'memory_reaction.dart';

/// A Memory as one viewer sees it: already filtered by exact-group
/// membership, with reactions and poll results projected for that viewer.
class CircleMemory {
  CircleMemory({
    required this.id,
    required this.groupId,
    required this.authorId,
    required this.author,
    required this.text,
    required this.createdAt,
    this.editedAt,
    List<MemoryPhoto> photos = const [],
    this.poll,
    this.takenYear,
    this.place,
    List<MemoryComment> comments = const [],
    MemoryReactions? reactions,
    this.saved = false,
    this.commentCount,
  }) : photos = List.unmodifiable(photos),
       comments = List.unmodifiable(comments),
       reactions = reactions ?? MemoryReactions();

  final String id, groupId, authorId;

  /// The author's display name ("You" for the viewer).
  final String author;

  /// May be empty when the Memory has photos or a poll.
  final String text;
  final DateTime createdAt;
  final DateTime? editedAt;
  final List<MemoryPhoto> photos;
  final PollView? poll;

  /// Optional "Taken in 2007 · Kodaikanal" details for older moments.
  final int? takenYear;
  final String? place;

  /// Visible comments and replies (see [CommentRules.threads] for order).
  final List<MemoryComment> comments;
  final MemoryReactions reactions;
  final bool saved;

  /// The number of visible comments when only a count is known (a server
  /// list); [comments] fills in when the Memory is opened.
  final int? commentCount;

  /// Visible comments and replies, counted.
  int get commentTotal =>
      comments.isEmpty ? (commentCount ?? 0) : comments.length;

  bool get edited => editedAt != null;

  /// Whether the viewer's reaction is the ❤️ behind the Love button.
  bool get loved => reactions.mine == loveReaction;

  /// "Taken in 2007 · Kodaikanal", or null when neither is set.
  String? get takenLabel {
    final parts = [if (takenYear != null) 'Taken in $takenYear', ?place];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// A short title for lists (Saved Memories): the text, else the poll
  /// question, else the number of photos.
  String get summary {
    if (text.isNotEmpty) return text;
    if (poll != null) return 'Poll: ${poll!.question}';
    return photos.length == 1 ? '1 photo' : '${photos.length} photos';
  }
}

/// Pure Memory rules: content, optional details and author-only changes.
abstract final class MemoryRules {
  static const maxText = 2000, maxPhotos = 10, maxPlace = 80;
  static const firstYear = 1950;

  /// A Memory needs at least one of text, photos or a poll. Text is
  /// optional when photos or a poll carry the moment.
  static RuleResult checkContent({
    required String text,
    int photoCount = 0,
    bool hasPoll = false,
  }) {
    final value = text.trim();
    if (value.runes.length > maxText) {
      return const RuleResult.denied('Write up to 2000 characters.');
    }
    if (photoCount > maxPhotos) {
      return const RuleResult.denied('Add up to 10 photos.');
    }
    if (value.isEmpty && photoCount == 0 && !hasPoll) {
      return const RuleResult.denied(
        'Write 1–2000 characters, or add a photo or a poll, before sharing.',
      );
    }
    return const RuleResult.allowed();
  }

  static RuleResult checkYear(int? year, DateTime now) {
    if (year == null) return const RuleResult.allowed();
    return year < firstYear || year > now.year
        ? RuleResult.denied('Use a year from $firstYear to ${now.year}.')
        : const RuleResult.allowed();
  }

  /// Reads the optional year field: blank is fine, anything else must be a
  /// whole year in range.
  static ({int? year, RuleResult result}) parseYear(
    String input,
    DateTime now,
  ) {
    final value = input.trim();
    if (value.isEmpty) return (year: null, result: const RuleResult.allowed());
    final year = int.tryParse(value);
    if (year == null) {
      return (
        year: null,
        result: RuleResult.denied('Use a year from $firstYear to ${now.year}.'),
      );
    }
    return (year: year, result: checkYear(year, now));
  }

  static RuleResult checkPlace(String? place) =>
      (place?.trim().runes.length ?? 0) > maxPlace
      ? const RuleResult.denied('Keep the place to 80 characters.')
      : const RuleResult.allowed();

  /// Blank places are stored as null.
  static String? cleanPlace(String? place) {
    final value = place?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  /// Only the author edits or deletes their Memory. Admin hide/remove for
  /// reported content comes with moderation.
  static RuleResult canChange(String authorId, String actor) =>
      authorId == actor
      ? const RuleResult.allowed()
      : const RuleResult.denied(
          'Only the person who shared this can change it.',
        );
}
