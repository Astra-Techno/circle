import '../../events/domain/circle_event.dart';
import '../../groups/domain/circle_group.dart';
import '../../memories/domain/circle_memory.dart';
import '../../moderation/domain/moderation.dart';

export '../../../core/circle_failure.dart';
export '../../events/domain/circle_event.dart';
export '../../groups/domain/circle_group.dart';
export '../../memories/domain/circle_memory.dart';
export '../../moderation/domain/moderation.dart';

/// Everything one viewer may see, already filtered by exact membership.
class CircleWorkspace {
  CircleWorkspace({
    required this.viewer,
    required List<CircleGroup> groups,
    required List<CircleMemory> memories,
    required List<CircleEvent> events,
    List<GroupPreview> discoverable = const [],
    List<PendingGroup> pending = const [],
    List<InvitationView> invitations = const [],
    List<JoinRequest> joinRequests = const [],
    List<DirectInvitation> sentInvitations = const [],
    Map<String, String> people = const {},
    Map<String, String> avatarVersions = const {},
    Set<String> hiddenByAdmins = const {},
    Set<String> reportedByMe = const {},
    Map<String, int> openReports = const {},
    this.hasMoreMemories = false,
  }) : groups = List.unmodifiable(groups),
       memories = List.unmodifiable(memories),
       events = List.unmodifiable(events),
       discoverable = List.unmodifiable(discoverable),
       pending = List.unmodifiable(pending),
       invitations = List.unmodifiable(invitations),
       joinRequests = List.unmodifiable(joinRequests),
       sentInvitations = List.unmodifiable(sentInvitations),
       avatarVersions = Map.unmodifiable(avatarVersions),
       people = Map.unmodifiable(people),
       hiddenByAdmins = Set.unmodifiable(hiddenByAdmins),
       reportedByMe = Set.unmodifiable(reportedByMe),
       openReports = Map.unmodifiable(openReports),
       groupsById = Map.unmodifiable({for (final g in groups) g.id: g});

  final String viewer;
  final Map<String, String> avatarVersions;

  /// Groups the viewer is an active member of.
  final List<CircleGroup> groups;
  final Map<String, CircleGroup> groupsById;
  final List<CircleMemory> memories;

  /// Older Memories can be loaded (server lists are paginated).
  final bool hasMoreMemories;

  /// Events of the viewer's groups, soonest first.
  final List<CircleEvent> events;

  /// Listed subgroups of the viewer's groups that the viewer is not in.
  final List<GroupPreview> discoverable;

  /// The viewer's own requests waiting for approval (name only).
  final List<PendingGroup> pending;

  /// Direct invitations waiting for the viewer's answer.
  final List<InvitationView> invitations;

  /// Requests to join groups where the viewer is an admin.
  final List<JoinRequest> joinRequests;

  /// Direct invitations sent from groups the viewer can invite to.
  final List<DirectInvitation> sentInvitations;

  /// Display names of people who share a group with the viewer.
  final Map<String, String> people;

  /// Content keys (see [ReportTarget.key]) that admins hid, within the
  /// viewer's groups. Hidden Memories, comments and events are already
  /// left out for non-admins; admins get them with this marker.
  final Set<String> hiddenByAdmins;

  /// Keys of items the viewer reported. Only ever the viewer's own.
  final Set<String> reportedByMe;

  /// Open reports per group, for groups the viewer administers.
  final Map<String, int> openReports;

  bool isHidden(ReportKind kind, String id) =>
      hiddenByAdmins.contains(ReportTarget.contentKey(kind, id));

  bool reported(ReportKind kind, String id) =>
      reportedByMe.contains(ReportTarget.contentKey(kind, id));

  /// Whether the viewer is an owner or admin of [groupId] itself.
  bool isAdminOf(String groupId) =>
      groupsById[groupId]?.roles[viewer]?.isAdmin ?? false;

  CircleGroup? group(String id) => groupsById[id];
  CircleEvent? event(String id) =>
      events.where((event) => event.id == id).firstOrNull;
  String nameOf(String person) =>
      person == viewer ? 'You' : people[person] ?? 'Someone';
}
