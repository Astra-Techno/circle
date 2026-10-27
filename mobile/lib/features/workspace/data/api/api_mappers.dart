import '../../../../core/api/api_json.dart';
import '../../domain/circle_repository.dart';

/// JSON (contract 0.3.1) to domain models. Ids become strings; timestamps
/// are UTC. Nothing here talks to the network.
abstract final class ApiMappers {
  static CircleType type(Object? value) => CircleType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => CircleType.other,
  );

  /// A member's role; the owner is told apart by `is_owner` /
  /// `owner_user_id`, never by `role` (which is `admin` for the owner).
  static CircleRole role(Object? value, {bool owner = false}) => owner
      ? CircleRole.owner
      : value == 'admin'
      ? CircleRole.admin
      : CircleRole.member;

  static String roleName(CircleRole role) =>
      role == CircleRole.member ? 'member' : 'admin';

  /// A group from `GroupSummary`/`Group` JSON. [roles] holds every active
  /// member (from `/groups/{id}/members`); [linkSharing] comes from the
  /// full `Group` (the list doesn't include it).
  static CircleGroup group(
    Map<String, Object?> json, {
    required Map<String, CircleRole> roles,
    String? linkSharing,
    String? eventCreation,
    InviteLink? inviteLink,
    int order = 0,
  }) {
    final parentId = ApiJson.optionalId(json['parent_id']);
    return CircleGroup(
      id: ApiJson.id(json['id']),
      name: ApiJson.string(json['name']),
      type: type(json['type']),
      depth: ApiJson.integer(json['depth']) ?? 1,
      parentId: parentId,
      roles: roles,
      settings: GroupSettings(
        approvalRequired: json['approval_mode'] == 'manual',
        invitePolicy: (linkSharing ?? json['link_sharing']) == 'members'
            ? InvitePolicy.allMembers
            : InvitePolicy.adminsOnly,
        hidden: parentId != null && json['visibility'] == 'hidden',
        eventCreation: (eventCreation ?? json['event_creation']) == 'admins'
            ? EventCreationPolicy.admins
            : EventCreationPolicy.members,
      ),
      inviteLink: inviteLink,
      avatarVersion: ApiJson.optionalString(json['avatar_version']),
      coverVersion: ApiJson.optionalString(json['cover_version']),
      order: order,
    );
  }

  /// One entry of `/groups/{id}/members`.
  static ({String id, String name, CircleRole role}) member(Object? value) {
    final json = ApiJson.map(value);
    return (
      id: ApiJson.id(json['id']),
      name: ApiJson.string(json['display_name'], 'Someone'),
      role: role(json['role'], owner: ApiJson.boolean(json['is_owner'])),
    );
  }

  static JoinRequest joinRequest(Object? value, {required String groupId}) {
    final json = ApiJson.map(value);
    return JoinRequest(
      id: ApiJson.id(json['id']),
      groupId: groupId,
      person: ApiJson.id(json['user_id']),
      createdAt: ApiJson.time(json['created_at']) ?? _epoch,
      source: JoinRequestSource.link,
    );
  }

  /// A just-created link (`NewInviteLink`): the only time the token is seen.
  static ({String id, InviteLink link}) newInviteLink(
    Object? value, {
    required String createdBy,
    required DateTime now,
  }) {
    final json = ApiJson.map(value);
    final token = ApiJson.string(json['token']);
    if (token.isEmpty) ApiJson.unexpected();
    return (
      id: ApiJson.id(json['id']),
      link: InviteLink(
        token: token,
        createdBy: createdBy,
        createdAt: now.toUtc(),
        expiresAt:
            ApiJson.time(json['expires_at']) ??
            now.toUtc().add(defaultInviteExpiry),
        maxUses: ApiJson.integer(json['max_uses']),
      ),
    );
  }

  /// Applies `InviteLinkInfo` (use count, status) to a known link.
  static InviteLink? linkStatus(InviteLink link, Object? value) {
    final json = ApiJson.map(value);
    if (json['status'] == 'revoked') return null;
    return InviteLink(
      token: link.token,
      createdBy: link.createdBy,
      createdAt: ApiJson.time(json['created_at']) ?? link.createdAt,
      expiresAt: ApiJson.time(json['expires_at']) ?? link.expiresAt,
      maxUses: ApiJson.integer(json['max_uses']),
      uses: ApiJson.integer(json['use_count']) ?? link.uses,
    );
  }

  static InvitePreview invitePreview(Object? value, String token) {
    final json = ApiJson.map(value);
    return InvitePreview(
      status: InviteLinkStatus.valid,
      token: token,
      group: GroupPreview(
        // The preview never reveals the group's id.
        id: '',
        name: ApiJson.string(json['group_name'], 'A private group'),
        type: type(json['group_type']),
        memberCount: ApiJson.integer(json['member_count']) ?? 0,
        approvalRequired: ApiJson.boolean(json['approval_required']),
      ),
    );
  }

  static MemoryComment comment(Object? value, {required String viewer}) {
    final json = ApiJson.map(value);
    final author = ApiJson.id(json['author_id']);
    return MemoryComment(
      id: ApiJson.id(json['id']),
      authorId: author,
      authorName: author == viewer
          ? 'You'
          : ApiJson.string(json['author_name'], 'Someone'),
      text: ApiJson.string(json['body']),
      createdAt: ApiJson.time(json['created_at']) ?? _epoch,
      parentId: ApiJson.optionalId(json['parent_id']),
    );
  }

  /// `reactions` of `GET /memories/{id}`: person → emoji.
  static Map<String, String> reactions(Object? value) => {
    for (final item in ApiJson.list(value))
      if (item is Map && item['emoji'] is String)
        ApiJson.id(item['user_id']): item['emoji'] as String,
  };

  /// A Memory from `Memory`/`MemoryListItem` JSON. With [comments] and
  /// [reactions] (from `GET /memories/{id}`) the card is complete; without
  /// them it shows the list's counts. [myReaction] is the viewer's emoji
  /// when known from this session.
  static CircleMemory memory(
    Map<String, Object?> json, {
    required String viewer,
    List<MemoryComment>? comments,
    Map<String, String>? reactions,
    String? myReaction,
    bool? saved,
  }) {
    final id = ApiJson.id(json['id']);
    final authorId = ApiJson.id(json['author_id']);
    final created = ApiJson.time(json['created_at']) ?? _epoch;
    final updated = ApiJson.time(json['updated_at']);
    final edited = updated != null && updated.difference(created).inSeconds > 1;
    final date = ApiJson.optionalString(json['memory_date']);
    final MemoryReactions view;
    if (reactions != null) {
      view = ReactionRules.viewFor(reactions, viewer);
    } else {
      final count = ApiJson.integer(json['reaction_count']) ?? 0;
      final mine = ApiJson.boolean(json['user_reacted']) ? myReaction : null;
      view = MemoryReactions(
        mine: mine,
        unsorted: count - (mine == null ? 0 : 1),
      );
    }
    return CircleMemory(
      id: id,
      groupId: ApiJson.id(json['group_id']),
      authorId: authorId,
      author: authorId == viewer
          ? 'You'
          : ApiJson.string(json['author_name'], 'Someone'),
      text: ApiJson.string(json['body']),
      createdAt: created,
      editedAt: edited ? updated : null,
      photos: [
        for (final item in ApiJson.list(json['media']))
          if (item is Map && item['id'] is String)
            MemoryPhoto(
              id: '$id-${item['id']}',
              mediaId: item['id'] as String,
              width: ApiJson.integer(item['width']),
              height: ApiJson.integer(item['height']),
            ),
      ],
      takenYear: date == null || date.length < 4
          ? null
          : int.tryParse(date.substring(0, 4)),
      place: ApiJson.optionalString(json['place']),
      comments: comments ?? const [],
      commentCount: comments == null
          ? ApiJson.integer(json['comment_count'])
          : null,
      reactions: view,
      saved: saved ?? ApiJson.boolean(json['user_saved']),
    );
  }

  static final _epoch = DateTime.utc(1970);
}
