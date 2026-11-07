import '../../../core/rule_result.dart';

export '../../../core/rule_result.dart';

/// A Memory Capsule: a time-locked memory that stays sealed until its
/// unlock date. Contributors add photos and messages before sealing;
/// once sealed, nobody can see or change the contents until the date
/// arrives. When it unlocks, every contributor is notified and the
/// capsule becomes a shared Memory in the group.
class Capsule {
  const Capsule({
    required this.id,
    required this.groupId,
    required this.creatorId,
    required this.creator,
    required this.title,
    this.message = '',
    required this.unlockAt,
    required this.createdAt,
    this.sealedAt,
    this.contributors = const [],
    this.photoCount = 0,
    this.messageCount = 0,
  });

  final String id, groupId, creatorId, creator, title, message;

  /// When this capsule becomes visible to everyone.
  final DateTime unlockAt;
  final DateTime createdAt;

  /// Null while still accepting contributions; set when the creator seals it.
  final DateTime? sealedAt;

  /// People who added something to this capsule.
  final List<CapsuleContributor> contributors;
  final int photoCount, messageCount;

  bool get isSealed => sealedAt != null;
  bool get isUnlocked => DateTime.now().isAfter(unlockAt);
  bool get isOpen => !isSealed && !isUnlocked;

  /// How long until unlock, as a human-readable label.
  String get countdownLabel {
    final now = DateTime.now();
    if (now.isAfter(unlockAt)) return 'Unlocked';
    final diff = unlockAt.difference(now);
    if (diff.inDays > 365) {
      final years = (diff.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} to go';
    }
    if (diff.inDays > 30) {
      final months = (diff.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} to go';
    }
    if (diff.inDays > 0) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} to go';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} to go';
    }
    return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} to go';
  }

  /// Progress toward unlock as a fraction 0..1.
  double get progress {
    final total = unlockAt.difference(createdAt).inSeconds;
    if (total <= 0) return 1.0;
    final elapsed = DateTime.now().difference(createdAt).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}

class CapsuleContributor {
  const CapsuleContributor({
    required this.id,
    required this.name,
    this.addedPhotos = 0,
    this.addedMessages = 0,
  });
  final String id, name;
  final int addedPhotos, addedMessages;
}

/// A single contribution inside a capsule (visible only after unlock).
class CapsuleEntry {
  const CapsuleEntry({
    required this.id,
    required this.authorId,
    required this.author,
    required this.text,
    this.photoIds = const [],
    required this.addedAt,
  });
  final String id, authorId, author, text;
  final List<String> photoIds;
  final DateTime addedAt;
}

/// Pure capsule rules: title, timing and contributor checks.
abstract final class CapsuleRules {
  static const maxTitle = 60;
  static const maxMessage = 500;
  static const maxContributors = 50;
  static const maxPhotosPerEntry = 5;
  static const maxEntriesPerCapsule = 100;

  /// Minimum unlock delay: 1 day from now.
  static const minDaysAhead = 1;

  /// Maximum unlock delay: 10 years.
  static const maxDaysAhead = 3650;

  static RuleResult checkTitle(String title) {
    final value = title.trim();
    if (value.isEmpty) {
      return const RuleResult.denied('Give your capsule a title.');
    }
    if (value.runes.length > maxTitle) {
      return const RuleResult.denied('Keep the title to 60 characters.');
    }
    return const RuleResult.allowed();
  }

  static RuleResult checkMessage(String message) {
    if (message.trim().runes.length > maxMessage) {
      return const RuleResult.denied('Keep the message to 500 characters.');
    }
    return const RuleResult.allowed();
  }

  static RuleResult checkUnlockDate(DateTime unlockAt, DateTime now) {
    final earliest = now.add(const Duration(days: minDaysAhead));
    if (unlockAt.isBefore(earliest)) {
      return const RuleResult.denied(
        'The unlock date must be at least 1 day from now.',
      );
    }
    final latest = now.add(const Duration(days: maxDaysAhead));
    if (unlockAt.isAfter(latest)) {
      return const RuleResult.denied(
        'The unlock date can be at most 10 years from now.',
      );
    }
    return const RuleResult.allowed();
  }

  /// Only the creator can seal or delete the capsule.
  static RuleResult canManage(String creatorId, String actor) =>
      creatorId == actor
      ? const RuleResult.allowed()
      : const RuleResult.denied(
          'Only the person who created this capsule can manage it.',
        );
}
