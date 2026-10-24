import '../../../core/rule_result.dart';

/// One comment on a Memory. A reply points at a top-level comment of the
/// same Memory through [parentId]; replies never nest deeper.
class MemoryComment {
  const MemoryComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.parentId,
    this.mentions = const {},
  });
  final String id, authorId, authorName, text;
  final DateTime createdAt;
  final String? parentId;

  /// People mentioned with "@Name" (person id → name as written). Only
  /// members of the Memory's exact group; empty on a server, which keeps
  /// comments as plain text for now.
  final Map<String, String> mentions;

  bool get isReply => parentId != null;

  MemoryComment copyWith({String? authorName}) => MemoryComment(
    id: id,
    authorId: authorId,
    authorName: authorName ?? this.authorName,
    text: text,
    createdAt: createdAt,
    parentId: parentId,
    mentions: mentions,
  );
}

/// A top-level comment with its replies, in the order they were written.
typedef CommentThread = ({MemoryComment comment, List<MemoryComment> replies});

/// Pure comment and reply rules.
abstract final class CommentRules {
  static const maxLength = 2000;

  /// Trimmed text, or a denial for empty or oversized comments.
  static RuleResult checkText(String text) {
    final value = text.trim();
    return value.isEmpty || value.runes.length > maxLength
        ? const RuleResult.denied('Write 1–2000 characters before sharing.')
        : const RuleResult.allowed();
  }

  /// Replies go only to an existing top-level comment of the same Memory.
  static RuleResult canReply(List<MemoryComment> comments, String parentId) {
    final parent = comments.where((c) => c.id == parentId).firstOrNull;
    if (parent == null) {
      return const RuleResult.denied('That comment is no longer here.');
    }
    if (parent.isReply) {
      return const RuleResult.denied('Reply to the first comment instead.');
    }
    return const RuleResult.allowed();
  }

  /// Only the author can delete their own comment.
  static RuleResult canDelete(MemoryComment comment, String actor) =>
      comment.authorId == actor
      ? const RuleResult.allowed()
      : const RuleResult.denied('You can only delete your own comments.');

  /// Top-level comments oldest first, each with its replies underneath.
  /// Replies whose parent is missing are not shown.
  static List<CommentThread> threads(List<MemoryComment> comments) {
    int byTime(MemoryComment a, MemoryComment b) {
      final order = a.createdAt.compareTo(b.createdAt);
      return order != 0 ? order : a.id.compareTo(b.id);
    }

    final top = comments.where((c) => !c.isReply).toList()..sort(byTime);
    return [
      for (final comment in top)
        (
          comment: comment,
          replies: comments.where((c) => c.parentId == comment.id).toList()
            ..sort(byTime),
        ),
    ];
  }

  /// The most recent visible comment or reply, for the card preview.
  static MemoryComment? latest(List<MemoryComment> comments) {
    final visible = [
      for (final thread in threads(comments)) ...[
        thread.comment,
        ...thread.replies,
      ],
    ];
    if (visible.isEmpty) return null;
    return visible.reduce((a, b) => b.createdAt.isBefore(a.createdAt) ? a : b);
  }
}
