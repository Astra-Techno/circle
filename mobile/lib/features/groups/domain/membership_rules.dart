import '../../../core/rule_result.dart';
import 'circle_group.dart';

export '../../../core/rule_result.dart';

const _ok = RuleResult.allowed();

/// Pure membership and permission rules shared by repositories and UI.
///
/// Every check uses the exact group only; nothing is inherited from parents.
/// `groups` is every group the caller knows about, keyed by id.
abstract final class MembershipRules {
  static int adminCount(CircleGroup group) =>
      group.roles.values.where((role) => role.isAdmin).length;

  static bool isLastAdmin(CircleGroup group, String person) =>
      (group.roles[person]?.isAdmin ?? false) && adminCount(group) == 1;

  static RuleResult canCreateGroup({
    required String person,
    CircleGroup? parent,
  }) {
    if (person.trim().isEmpty) {
      return const RuleResult.denied('Log in first.');
    }
    if (parent == null) return _ok;
    if (!parent.isMember(person)) {
      return const RuleResult.denied('This group is not shared with you.');
    }
    if (parent.depth + 1 > maxGroupDepth) {
      return const RuleResult.denied(
        'This group is already at the 10-level limit.',
      );
    }
    return _ok;
  }

  static RuleResult canInvite(CircleGroup group, String actor) {
    final role = group.roles[actor];
    if (role == null) {
      return const RuleResult.denied('This group is not shared with you.');
    }
    if (role.isAdmin ||
        group.settings.invitePolicy == InvitePolicy.allMembers) {
      return _ok;
    }
    return const RuleResult.denied('Only admins can invite people here.');
  }

  /// Any member may create events unless the group's admins limited it to
  /// admins. Always the exact group; nothing is inherited.
  static RuleResult canCreateEvent(CircleGroup group, String actor) {
    final role = group.roles[actor];
    if (role == null) {
      return const RuleResult.denied('This group is not shared with you.');
    }
    if (role.isAdmin ||
        group.settings.eventCreation == EventCreationPolicy.members) {
      return _ok;
    }
    return RuleResult.denied('Only admins can create events in ${group.name}.');
  }

  static RuleResult _admin(CircleGroup group, String actor) {
    final role = group.roles[actor];
    if (role == null) {
      return const RuleResult.denied('This group is not shared with you.');
    }
    return role.isAdmin
        ? _ok
        : const RuleResult.denied('Only admins can change this.');
  }

  /// Reset, revoke or change expiry/limits of the invite link.
  static RuleResult canManageLink(CircleGroup group, String actor) =>
      _admin(group, actor);

  static RuleResult canEditSettings(CircleGroup group, String actor) =>
      _admin(group, actor);

  static RuleResult canReviewRequests(CircleGroup group, String actor) =>
      _admin(group, actor);

  static RuleResult canChangeRole(
    CircleGroup group,
    String actor,
    String target,
    CircleRole role,
  ) {
    final admin = _admin(group, actor);
    if (!admin.allowed) return admin;
    final current = group.roles[target];
    if (current == null) {
      return const RuleResult.denied('This person is not in the group.');
    }
    if (role == CircleRole.owner) {
      return const RuleResult.denied('Use Transfer ownership instead.');
    }
    if (current == CircleRole.owner) {
      return const RuleResult.denied('The owner’s role can’t be changed.');
    }
    if (current == role) return const RuleResult.denied('Nothing to change.');
    if (target == actor) {
      return const RuleResult.denied('Ask another admin to change your role.');
    }
    if (role == CircleRole.member && group.roles[actor] != CircleRole.owner) {
      return const RuleResult.denied(
        'Only the owner can remove an admin role.',
      );
    }
    return _ok;
  }

  /// [ownedDescendants] are names of subgroups (below [group]) that [target]
  /// owns; removal would leave them without an owner.
  static RuleResult canRemove(
    CircleGroup group,
    String actor,
    String target, {
    List<String> ownedDescendants = const [],
  }) {
    final admin = _admin(group, actor);
    if (!admin.allowed) return admin;
    final role = group.roles[target];
    if (role == null) {
      return const RuleResult.denied('This person is not in the group.');
    }
    if (target == actor) {
      return const RuleResult.denied('To leave, use Leave group in settings.');
    }
    if (role == CircleRole.owner) {
      return const RuleResult.denied('The owner can’t be removed.');
    }
    if (role == CircleRole.admin && group.roles[actor] != CircleRole.owner) {
      return const RuleResult.denied('Only the owner can remove an admin.');
    }
    if (ownedDescendants.isNotEmpty) {
      return RuleResult.denied(
        'They own ${ownedDescendants.join(', ')}. Ownership there must be transferred first.',
      );
    }
    return _ok;
  }

  static RuleResult canTransferOwnership(
    CircleGroup group,
    String actor,
    String target,
  ) {
    if (group.roles[actor] != CircleRole.owner) {
      return const RuleResult.denied('Only the owner can transfer ownership.');
    }
    if (target == actor) {
      return const RuleResult.denied('You already own this group.');
    }
    if (!group.isMember(target)) {
      return const RuleResult.denied('Choose someone who is in this group.');
    }
    return _ok;
  }

  /// [cascade] is the group itself followed by every descendant [person]
  /// belongs to (see [cascade]).
  static RuleResult canLeave(
    CircleGroup group,
    String person,
    List<CircleGroup> cascade,
  ) {
    if (!group.isMember(person)) {
      return const RuleResult.denied('You are not in this group.');
    }
    if (group.roles[person] == CircleRole.owner) {
      return const RuleResult.denied(
        'Owners can’t leave. Transfer ownership to someone else first.',
      );
    }
    if (isLastAdmin(group, person)) {
      return const RuleResult.denied(
        'You’re the only admin. Make someone else an admin first.',
      );
    }
    for (final child in cascade.where((item) => item.id != group.id)) {
      if (child.roles[person] == CircleRole.owner) {
        return RuleResult.denied(
          'You own ${child.name}. Transfer its ownership before leaving.',
        );
      }
      if (isLastAdmin(child, person)) {
        return RuleResult.denied(
          'You’re the only admin of ${child.name}. Make someone else an admin there first.',
        );
      }
    }
    return _ok;
  }

  /// Whether [person] may join [group] (by link, request or invitation).
  /// Joining a subgroup requires active membership of its direct parent.
  static RuleResult canJoin(
    CircleGroup group,
    String person,
    Map<String, CircleGroup> groups,
  ) {
    if (group.isMember(person)) {
      return const RuleResult.denied('You are already in this group.');
    }
    final parentId = group.parentId;
    if (parentId != null) {
      final parent = groups[parentId];
      if (parent == null || !parent.isMember(person)) {
        return RuleResult.denied(
          'Join ${parent?.name ?? 'the parent group'} first. Subgroups are open only to members of the group above them.',
        );
      }
    }
    if (group.depth > maxGroupDepth) {
      return const RuleResult.denied(
        'This group is beyond the 10-level limit.',
      );
    }
    return _ok;
  }

  /// Listed subgroups are shown to members of their direct parent only.
  /// Hidden subgroups and root groups are never listed.
  static bool isDiscoverable(
    CircleGroup group,
    String person,
    Map<String, CircleGroup> groups,
  ) {
    final parentId = group.parentId;
    if (parentId == null || group.hidden || group.isMember(person)) {
      return false;
    }
    return groups[parentId]?.isMember(person) ?? false;
  }

  /// Every descendant of [groupId], parents before children.
  static List<CircleGroup> descendants(
    Map<String, CircleGroup> groups,
    String groupId,
  ) {
    final result = <CircleGroup>[];
    final queue = [groupId];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final children =
          groups.values.where((group) => group.parentId == current).toList()
            ..sort((a, b) => a.order.compareTo(b.order));
      result.addAll(children);
      queue.addAll(children.map((group) => group.id));
    }
    return result;
  }

  /// The groups [person] leaves when leaving or being removed from
  /// [groupId]: the group itself plus every descendant they belong to.
  static List<CircleGroup> cascade(
    Map<String, CircleGroup> groups,
    String groupId,
    String person,
  ) {
    final group = groups[groupId];
    if (group == null || !group.isMember(person)) return const [];
    return [
      group,
      ...descendants(groups, groupId).where((child) => child.isMember(person)),
    ];
  }

  /// Names of descendants of [groupId] that [person] owns.
  static List<String> ownedDescendants(
    Map<String, CircleGroup> groups,
    String groupId,
    String person,
  ) => [
    for (final child in descendants(groups, groupId))
      if (child.roles[person] == CircleRole.owner) child.name,
  ];
}

/// Which member-management actions the UI may offer for [target].
class MemberActions {
  MemberActions(CircleGroup group, String actor, String target)
    : promote = MembershipRules.canChangeRole(
        group,
        actor,
        target,
        CircleRole.admin,
      ).allowed,
      demote = MembershipRules.canChangeRole(
        group,
        actor,
        target,
        CircleRole.member,
      ).allowed,
      remove = MembershipRules.canRemove(group, actor, target).allowed,
      transfer = MembershipRules.canTransferOwnership(
        group,
        actor,
        target,
      ).allowed;
  final bool promote, demote, remove, transfer;
  bool get any => promote || demote || remove || transfer;
}
