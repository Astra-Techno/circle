import 'moderation.dart';

export '../../../core/circle_failure.dart';
export 'moderation.dart';

/// A report as the reporter sends it.
class ReportDraft {
  const ReportDraft({
    required this.target,
    required this.reason,
    this.note,
    this.summary,
  });
  final ReportTarget target;
  final ReportReason reason;
  final String? note;

  /// Only used for items the repository can't read itself (chat messages,
  /// which the chat service checks before passing them on).
  final String? summary;
}

/// Reports and the admin queue (README §3.8). Every call re-checks the
/// viewer's membership (and admin role) in the exact group; failures are
/// calm [CircleFailure]s.
abstract interface class ModerationRepository {
  /// Records a report. Reporters never see other people's reports.
  Future<void> report(String viewer, ReportDraft draft);

  /// Admins of [groupId] only.
  Future<ModerationQueue> queue(String viewer, String groupId);

  /// Hides reported content (reversible with [unhide]).
  Future<void> hide(String viewer, String groupId, String targetKey);
  Future<void> unhide(String viewer, String groupId, String targetKey);

  /// Closes the reports about an item without acting on it.
  Future<void> dismiss(String viewer, String groupId, String targetKey);

  /// Undo for [dismiss].
  Future<void> restoreReports(String viewer, String groupId, String targetKey);

  /// A parent group's admin removes a reported subgroup (and everything
  /// below it) without access to its content.
  Future<void> removeSubgroup(
    String viewer,
    String parentId,
    String subgroupId,
  );
}
