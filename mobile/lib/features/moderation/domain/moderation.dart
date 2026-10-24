/// Reporting and moderation (README §3.8, I3, C9). Pure Dart; no Flutter.
library;

import '../../../core/rule_result.dart';
import '../../groups/domain/circle_group.dart';

export '../../../core/rule_result.dart';

/// Why someone reports something. Plain words, no jargon (§4.0).
enum ReportReason {
  spam('Spam'),
  harassment('Harassment or bullying'),
  hate('Hate'),
  nudity('Nudity or sexual content'),
  violence('Violence'),
  privateInfo('Private information'),
  other('Something else');

  const ReportReason(this.label);
  final String label;
}

/// What can be reported.
enum ReportKind {
  memory('Memory'),
  comment('comment'),
  event('event'),
  message('message'),
  member('member'),
  subgroup('subgroup');

  const ReportKind(this.label);
  final String label;

  /// Content an admin can hide (and unhide). Members and subgroups can't.
  bool get hideable =>
      this == memory || this == comment || this == event || this == message;
}

/// One reportable thing. [groupId] is the group whose admins review it: the
/// item's own group, or the parent group for a subgroup. Direct (1:1)
/// messages have no group; they go to the platform, not to an admin queue.
class ReportTarget {
  const ReportTarget({
    required this.kind,
    required this.id,
    required this.groupId,
    this.personId,
    this.parentId,
  });

  const ReportTarget.memory(this.id, {required String this.groupId})
    : kind = ReportKind.memory,
      personId = null,
      parentId = null;

  const ReportTarget.comment(
    this.id, {
    required String memoryId,
    required String this.groupId,
  }) : kind = ReportKind.comment,
       personId = null,
       parentId = memoryId;

  const ReportTarget.event(this.id, {required String this.groupId})
    : kind = ReportKind.event,
      personId = null,
      parentId = null;

  const ReportTarget.message(
    this.id, {
    required String conversationId,
    required this.groupId,
    required String authorId,
  }) : kind = ReportKind.message,
       personId = authorId,
       parentId = conversationId;

  const ReportTarget.member(String person, {required String this.groupId})
    : kind = ReportKind.member,
      id = person,
      personId = person,
      parentId = null;

  const ReportTarget.subgroup(String subgroupId, {required String parentGroup})
    : kind = ReportKind.subgroup,
      id = subgroupId,
      groupId = parentGroup,
      personId = null,
      parentId = null;

  final ReportKind kind;
  final String id;
  final String? groupId;

  /// The person behind the item (author or reported member), when known.
  final String? personId;

  /// The Memory of a comment, or the conversation of a message.
  final String? parentId;

  /// Stable identity of the reported item, e.g. `memory:table`.
  String get key => contentKey(kind, id);

  static String contentKey(ReportKind kind, String id) => '${kind.name}:$id';

  ReportTarget withPerson(String? person) => ReportTarget(
    kind: kind,
    id: id,
    groupId: groupId,
    personId: person,
    parentId: parentId,
  );
}

/// One person's report as stored. Reporters are never shown to admins or to
/// other reporters.
class ContentReport {
  const ContentReport({
    required this.id,
    required this.target,
    required this.reporter,
    required this.reason,
    required this.createdAt,
    this.note,
    this.summary,
  });
  final String id, reporter;
  final ReportTarget target;
  final ReportReason reason;
  final DateTime createdAt;
  final String? note;

  /// A short snapshot of the reported content for the admin queue (never
  /// for subgroups: their admins-of-parent don't read them).
  final String? summary;
}

/// One reported item in an admin's queue: reasons and how often, never who.
class QueueItem {
  const QueueItem({
    required this.target,
    required this.reasons,
    required this.latestAt,
    required this.hidden,
    this.summary,
    this.personName,
    this.canRemovePerson = false,
    this.subgroupName,
    this.subgroupMemberCount,
    this.notes = const [],
  });
  final ReportTarget target;

  /// Reason → number of reports, most frequent first.
  final Map<ReportReason, int> reasons;
  final DateTime latestAt;
  final bool hidden;
  final String? summary, personName;

  /// Whether the admin may remove the author or reported member.
  final bool canRemovePerson;

  /// Subgroup reports: name and size only. Their content is never shown.
  final String? subgroupName;
  final int? subgroupMemberCount;
  final List<String> notes;

  int get count => reasons.values.fold(0, (sum, value) => sum + value);
}

/// "Mira hid a Memory · 2h ago".
class AuditEntry {
  const AuditEntry({
    required this.groupId,
    required this.actorId,
    required this.action,
    required this.at,
  });
  final String groupId, actorId;

  /// Past tense without the actor: "hid a Memory".
  final String action;
  final DateTime at;
}

class AuditView {
  const AuditView({
    required this.actorName,
    required this.action,
    required this.at,
  });
  final String actorName, action;
  final DateTime at;
  String get sentence => '$actorName $action';
}

class ModerationQueue {
  ModerationQueue({
    required this.group,
    required List<QueueItem> items,
    required List<AuditView> audit,
  }) : items = List.unmodifiable(items),
       audit = List.unmodifiable(audit);
  final CircleGroup group;
  final List<QueueItem> items;

  /// Newest first.
  final List<AuditView> audit;
}

/// What a viewer sees of content admins have hidden.
enum ContentVisibility {
  /// Not hidden.
  visible,

  /// Hidden; admins of the group still see it with "Hidden by admins".
  hiddenNotice,

  /// Hidden; everyone else sees nothing at all.
  gone,
}

const _ok = RuleResult.allowed();

/// Pure moderation rules shared by repositories and UI. Always the exact
/// group: being an admin of a parent gives no access to a subgroup's
/// content.
abstract final class ModerationRules {
  static const maxNote = 500;

  static RuleResult checkNote(String? note) =>
      (note?.trim().runes.length ?? 0) > maxNote
      ? const RuleResult.denied('Keep the note to 500 characters.')
      : _ok;

  /// Blank notes are stored as null.
  static String? cleanNote(String? note) {
    final value = note?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  /// Anyone who can see an item may report it once, except their own.
  static RuleResult canReport({
    required String reporter,
    required ReportTarget target,
    required Iterable<ContentReport> existing,
  }) {
    if (target.personId == reporter) {
      return const RuleResult.denied('You can’t report your own posts.');
    }
    if (existing.any(
      (report) =>
          report.reporter == reporter && report.target.key == target.key,
    )) {
      return const RuleResult.denied('You already reported this. Thank you.');
    }
    return _ok;
  }

  /// Only admins of the exact group see its queue and act on it.
  static RuleResult canModerate(CircleGroup? group, String actor) {
    final role = group?.roles[actor];
    if (role == null) {
      return const RuleResult.denied('This group is not shared with you.');
    }
    return role.isAdmin
        ? _ok
        : const RuleResult.denied(
            'Only admins of this group can review reports.',
          );
  }

  /// A parent group's admins may remove a reported subgroup without being
  /// in it (and without reading it): only name, size and reasons are shown.
  static RuleResult canRemoveSubgroup({
    required CircleGroup? parent,
    required CircleGroup? subgroup,
    required String actor,
  }) {
    if (subgroup == null || parent == null || subgroup.parentId != parent.id) {
      return const RuleResult.denied('This subgroup is no longer here.');
    }
    return canModerate(parent, actor);
  }

  /// How hidden content appears to [isAdmin] (of its exact group).
  static ContentVisibility visibility({
    required bool hidden,
    required bool isAdmin,
  }) {
    if (!hidden) return ContentVisibility.visible;
    return isAdmin ? ContentVisibility.hiddenNotice : ContentVisibility.gone;
  }

  /// Open reports of [groupId], grouped by item, newest first. Reporters are
  /// dropped here, so they can never reach the UI.
  static List<
    ({
      ReportTarget target,
      Map<ReportReason, int> reasons,
      DateTime latestAt,
      String? summary,
      List<String> notes,
    })
  >
  aggregate(Iterable<ContentReport> reports, String groupId) {
    final byKey = <String, List<ContentReport>>{};
    for (final report in reports) {
      if (report.target.groupId != groupId) continue;
      byKey.putIfAbsent(report.target.key, () => []).add(report);
    }
    final result = [
      for (final list in byKey.values)
        (
          target: list.first.target,
          reasons: _ranked(list),
          latestAt: list
              .map((report) => report.createdAt)
              .reduce((a, b) => a.isAfter(b) ? a : b),
          summary: list.first.summary,
          notes: [
            for (final report in list)
              if (report.note != null) report.note!,
          ],
        ),
    ]..sort((a, b) => b.latestAt.compareTo(a.latestAt));
    return result;
  }

  static Map<ReportReason, int> _ranked(List<ContentReport> list) {
    final counts = <ReportReason, int>{};
    for (final report in list) {
      counts[report.reason] = (counts[report.reason] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final order = b.value.compareTo(a.value);
        return order != 0 ? order : a.key.index.compareTo(b.key.index);
      });
    return {for (final entry in entries) entry.key: entry.value};
  }

  /// "Spam ×2 · Hate".
  static String reasonsLabel(Map<ReportReason, int> reasons) => [
    for (final entry in reasons.entries)
      entry.value > 1 ? '${entry.key.label} ×${entry.value}' : entry.key.label,
  ].join(' · ');

  /// "a Memory", "a comment", …
  static String article(ReportKind kind) => switch (kind) {
    ReportKind.memory => 'a Memory',
    ReportKind.comment => 'a comment',
    ReportKind.event => 'an event',
    ReportKind.message => 'a message',
    ReportKind.member => 'a member',
    ReportKind.subgroup => 'a subgroup',
  };
}
