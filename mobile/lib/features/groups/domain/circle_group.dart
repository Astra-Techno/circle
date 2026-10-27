/// Group, membership and invitation models. Pure Dart; no Flutter imports.
library;

enum CircleType { family, friends, school, college, office, club, other }

enum CircleRole { owner, admin, member }

/// Who may invite people (share the link or add someone directly).
enum InvitePolicy { adminsOnly, allMembers }

/// Who may create events in a group (README §3.3). Any member by default.
enum EventCreationPolicy { members, admins }

const maxGroupDepth = 10;
const defaultInviteExpiry = Duration(days: 7);

extension CircleRoleRank on CircleRole {
  bool get isAdmin => this == CircleRole.owner || this == CircleRole.admin;
}

class GroupSettings {
  const GroupSettings({
    this.approvalRequired = true,
    this.invitePolicy = InvitePolicy.adminsOnly,
    this.hidden = false,
    this.eventCreation = EventCreationPolicy.members,
  });

  /// When true, people joining by link or by request wait for an admin.
  final bool approvalRequired;
  final InvitePolicy invitePolicy;

  /// Subgroups only: hidden subgroups are never listed to parent members.
  final bool hidden;
  final EventCreationPolicy eventCreation;

  GroupSettings copyWith({
    bool? approvalRequired,
    InvitePolicy? invitePolicy,
    bool? hidden,
    EventCreationPolicy? eventCreation,
  }) => GroupSettings(
    approvalRequired: approvalRequired ?? this.approvalRequired,
    invitePolicy: invitePolicy ?? this.invitePolicy,
    hidden: hidden ?? this.hidden,
    eventCreation: eventCreation ?? this.eventCreation,
  );
}

class InviteLink {
  const InviteLink({
    required this.token,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    this.maxUses,
    this.uses = 0,
  });
  final String token, createdBy;
  final DateTime createdAt, expiresAt;

  /// Null means no usage limit.
  final int? maxUses;
  final int uses;

  bool expiredAt(DateTime now) => !now.isBefore(expiresAt);
  bool get exhausted => maxUses != null && uses >= maxUses!;

  InviteLink copyWith({DateTime? expiresAt, int? maxUses, int? uses}) =>
      InviteLink(
        token: token,
        createdBy: createdBy,
        createdAt: createdAt,
        expiresAt: expiresAt ?? this.expiresAt,
        maxUses: maxUses ?? this.maxUses,
        uses: uses ?? this.uses,
      );

  InviteLink withoutLimit() => InviteLink(
    token: token,
    createdBy: createdBy,
    createdAt: createdAt,
    expiresAt: expiresAt,
    uses: uses,
  );
}

class CircleGroup {
  CircleGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.depth,
    required Map<String, CircleRole> roles,
    this.parentId,
    this.settings = const GroupSettings(),
    this.inviteLink,
    this.avatarVersion,
    this.coverVersion,
    this.order = 0,
  }) : roles = Map.unmodifiable(roles);
  final String id, name;
  final String? avatarVersion, coverVersion;
  final CircleType type;
  final String? parentId;
  final int depth;

  /// Insertion order of members is join order. Exactly one owner.
  final Map<String, CircleRole> roles;
  final GroupSettings settings;

  /// Present only for people allowed to invite.
  final InviteLink? inviteLink;

  /// Creation order, used as a stable tie-breaker.
  final int order;

  bool get isSubgroup => parentId != null;
  bool get hidden => isSubgroup && settings.hidden;
  bool get approvalRequired => settings.approvalRequired;
  String? get ownerId => roles.entries
      .where((entry) => entry.value == CircleRole.owner)
      .firstOrNull
      ?.key;
  CircleRole? roleOf(String person) => roles[person];
  bool isMember(String person) => roles.containsKey(person);

  CircleGroup copyWith({
    String? name,
    Map<String, CircleRole>? roles,
    GroupSettings? settings,
    InviteLink? inviteLink,
    bool clearInviteLink = false,
  }) => CircleGroup(
    id: id,
    name: name ?? this.name,
    type: type,
    depth: depth,
    parentId: parentId,
    roles: roles ?? this.roles,
    settings: settings ?? this.settings,
    inviteLink: clearInviteLink ? null : inviteLink ?? this.inviteLink,
    order: order,
    avatarVersion: avatarVersion,
    coverVersion: coverVersion,
  );
}

/// Minimal discoverable information about a group the viewer is not in.
class GroupPreview {
  const GroupPreview({
    required this.id,
    required this.name,
    required this.type,
    required this.memberCount,
    required this.approvalRequired,
    this.parentId,
    this.parentName,
  });
  final String id, name;
  final CircleType type;
  final int memberCount;
  final bool approvalRequired;
  final String? parentId, parentName;
}

enum JoinRequestSource { listed, link, invitation }

class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.groupId,
    required this.person,
    required this.createdAt,
    required this.source,
  });
  final String id, groupId, person;
  final DateTime createdAt;
  final JoinRequestSource source;
}

/// A direct addition. Nobody joins until the invitee accepts.
class DirectInvitation {
  const DirectInvitation({
    required this.id,
    required this.groupId,
    required this.invitee,
    required this.inviter,
    required this.createdAt,
  });
  final String id, groupId, invitee, inviter;
  final DateTime createdAt;
}

/// The viewer's own pending request. Only the group name is revealed.
class PendingGroup {
  const PendingGroup({
    required this.requestId,
    required this.groupId,
    required this.name,
  });
  final String requestId, groupId, name;
}

/// An invitation addressed to the viewer, with just enough to decide.
class InvitationView {
  const InvitationView({
    required this.invitation,
    required this.groupName,
    required this.groupType,
    required this.inviterName,
    required this.memberCount,
    this.parentName,
  });
  final DirectInvitation invitation;
  final String groupName, inviterName;
  final CircleType groupType;
  final int memberCount;
  final String? parentName;
}

enum InviteLinkStatus {
  valid,
  alreadyMember,
  alreadyRequested,
  needsParent,
  expired,
  reset,
  exhausted,
  unknown,
}

class InvitePreview {
  const InvitePreview({
    required this.status,
    this.token,
    this.group,
    this.inviterName,
  });
  final InviteLinkStatus status;
  final String? token;

  /// Present only when the link is still valid for someone.
  final GroupPreview? group;
  final String? inviterName;
}

enum JoinOutcome { joined, requested }

/// Preview links look like `circle://invite/<token>`; a bare token works too.
const inviteLinkPrefix = 'circle://invite/';

String inviteLinkFor(String token) => '$inviteLinkPrefix$token';

/// Accepts a bare token or a preview link and returns the token.
String normalizeInviteToken(String input) {
  var value = input.trim();
  final slash = value.lastIndexOf('/');
  if (slash >= 0) value = value.substring(slash + 1);
  return value.toLowerCase();
}

/// Server invite tokens: 16–128 URL-safe characters, case-sensitive.
final _serverToken = RegExp(r'^[A-Za-z0-9_-]{16,128}$');

/// Reads a server invite link (`circle://invite/<token>`,
/// `https://…/i/<token>`) or a bare token, keeping its case. Returns null
/// when [input] doesn't contain a well-formed token.
String? serverInviteToken(String input) {
  var value = input.trim();
  final query = value.indexOf(RegExp(r'[?#]'));
  if (query >= 0) value = value.substring(0, query);
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  final slash = value.lastIndexOf('/');
  if (slash >= 0) value = value.substring(slash + 1);
  return _serverToken.hasMatch(value) ? value : null;
}
