import '../../profile/presentation/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../moderation/presentation/report_sheet.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/group_visuals.dart';
import '../domain/membership_rules.dart';

String _requestSource(JoinRequestSource source) => switch (source) {
  JoinRequestSource.link => 'Used the invite link',
  JoinRequestSource.listed => 'Asked from the subgroup list',
  JoinRequestSource.invitation => 'Accepted a member’s invitation',
};

int _roleRank(CircleRole role) => switch (role) {
  CircleRole.owner => 0,
  CircleRole.admin => 1,
  CircleRole.member => 2,
};

class GroupMembersTab extends ConsumerStatefulWidget {
  const GroupMembersTab({
    super.key,
    required this.group,
    required this.workspace,
  });
  final CircleGroup group;
  final CircleWorkspace workspace;

  @override
  ConsumerState<GroupMembersTab> createState() => _GroupMembersState();
}

class _GroupMembersState extends ConsumerState<GroupMembersTab> {
  int _visible = 30;
  @override
  void didUpdateWidget(covariant GroupMembersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.id != widget.group.id) _visible = 30;
  }

  CircleGroup get group => widget.group;
  CircleWorkspace get workspace => widget.workspace;
  @override
  Widget build(BuildContext context) {
    final viewer = workspace.viewer;
    final controller = ref.read(circleWorkspaceProvider.notifier);
    final canReview = MembershipRules.canReviewRequests(group, viewer).allowed;
    final requests = canReview
        ? workspace.joinRequests.where((r) => r.groupId == group.id).toList()
        : const <JoinRequest>[];
    final invited = workspace.sentInvitations
        .where((invitation) => invitation.groupId == group.id)
        .toList();
    final members = group.roles.entries.toList()
      ..sort((a, b) {
        final rank = _roleRank(a.value).compareTo(_roleRank(b.value));
        return rank != 0
            ? rank
            : workspace.nameOf(a.key).compareTo(workspace.nameOf(b.key));
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (requests.isNotEmpty) ...[
          CircleSectionTitle('Asking to join (${requests.length})'),
          for (final request in requests)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workspace.nameOf(request.person),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(_requestSource(request.source)),
                    const SizedBox(height: Space.md),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [
                        FilledButton.tonal(
                          onPressed: () => runCalmly(
                            context,
                            () => controller.approveRequest(request.id),
                            success:
                                '${workspace.nameOf(request.person)} joined ${group.name}.',
                          ),
                          child: Text(
                            'Approve',
                            semanticsLabel:
                                'Approve ${workspace.nameOf(request.person)}',
                          ),
                        ),
                        TextButton(
                          onPressed: () => runCalmly(
                            context,
                            () => controller.declineRequest(request.id),
                            success: 'Request declined.',
                          ),
                          child: Text(
                            'Decline',
                            semanticsLabel:
                                'Decline ${workspace.nameOf(request.person)}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Space.md),
        ],
        CircleSectionTitle('Members (${members.length})'),
        TextButton.icon(
          onPressed: () => runCalmly(context, controller.refresh),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh members'),
        ),
        for (final member in members.take(_visible))
          _MemberTile(
            group: group,
            workspace: workspace,
            person: member.key,
            role: member.value,
          ),
        if (_visible < members.length)
          TextButton(
            onPressed: () => setState(() => _visible += 30),
            child: const Text('Show more members'),
          ),
        if (invited.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          const CircleSectionTitle('Invited, waiting to accept'),
          for (final invitation in invited)
            CircleRow(
              child: ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(workspace.nameOf(invitation.invitee)),
                subtitle: Text(
                  'Invited by ${workspace.nameOf(invitation.inviter)}',
                ),
                trailing: TextButton(
                  onPressed: () => runCalmly(
                    context,
                    () => controller.cancelInvitation(invitation.id),
                    success: 'Invitation cancelled.',
                  ),
                  child: Text(
                    'Cancel',
                    semanticsLabel:
                        'Cancel invitation for ${workspace.nameOf(invitation.invitee)}',
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.group,
    required this.workspace,
    required this.person,
    required this.role,
  });
  final CircleGroup group;
  final CircleWorkspace workspace;
  final String person;
  final CircleRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = workspace.nameOf(person);
    final actions = MemberActions(group, workspace.viewer, person);
    return CircleRow(
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.only(
          start: Space.lg,
          end: Space.sm,
        ),
        leading: PersonAvatar(person: person, name: name),
        title: Text(name),
        subtitle: role == CircleRole.member
            ? null
            : Align(
                alignment: AlignmentDirectional.centerStart,
                child: CircleBadge(
                  circleRoleLabel(role),
                  strong: role == CircleRole.owner,
                ),
              ),
        onTap: () => context.push(personLocation(person, groupId: group.id)),
        trailing: actions.any
            ? IconButton(
                tooltip: 'Manage $name',
                icon: const Icon(Icons.more_horiz),
                onPressed: () => _manage(context, ref, name, actions),
              )
            : null,
      ),
    );
  }

  Future<void> _manage(
    BuildContext context,
    WidgetRef ref,
    String name,
    MemberActions actions,
  ) async {
    final features = ref.read(circleFeaturesProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      // Above the shell's navigation bar, so nothing is hidden.
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.section),
              child: Text(name, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: Space.sm),
            if (actions.promote)
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Make admin'),
                onTap: () => Navigator.pop(context, 'promote'),
              ),
            if (actions.demote)
              ListTile(
                leading: const Icon(Icons.remove_moderator_outlined),
                title: const Text('Remove admin role'),
                onTap: () => Navigator.pop(context, 'demote'),
              ),
            if (actions.transfer)
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Make owner'),
                subtitle: const Text('You’ll become an admin.'),
                onTap: () => Navigator.pop(context, 'transfer'),
              ),
            if (actions.remove)
              ListTile(
                leading: Icon(
                  Icons.person_remove_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Remove from ${group.name}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('View profile'),
              onTap: () => Navigator.pop(context, 'profile'),
            ),
            if (features.has(CircleFeature.moderation))
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text('Report $name'),
                onTap: () => Navigator.pop(context, 'report'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final controller = ref.read(circleWorkspaceProvider.notifier);
    final isOwner = group.roles[workspace.viewer] == CircleRole.owner;
    switch (choice) {
      case 'promote':
        await runCalmly(
          context,
          () => controller.setRole(group.id, person, CircleRole.admin),
          success: '$name is now an admin.',
          onUndo: isOwner
              ? undoWith(
                  context,
                  () => controller.setRole(group.id, person, CircleRole.member),
                )
              : null,
        );
      case 'demote':
        await runCalmly(
          context,
          () => controller.setRole(group.id, person, CircleRole.member),
          success: '$name is no longer an admin.',
          onUndo: undoWith(
            context,
            () => controller.setRole(group.id, person, CircleRole.admin),
          ),
        );
      case 'transfer':
        final confirmed = await confirmCircleAction(
          context,
          title: 'Make $name the owner?',
          message:
              'You’ll become an admin. Only $name will be able to transfer ownership back.',
          confirm: 'Make owner',
        );
        if (confirmed && context.mounted) {
          await runCalmly(
            context,
            () => controller.transferOwnership(group.id, person),
            success: '$name now owns ${group.name}.',
          );
        }
      case 'remove':
        await confirmRemoveMember(context, ref, group, person, name);
      case 'profile':
        await context.push(personLocation(person, groupId: group.id));
      case 'report':
        await reportToAdmins(
          context,
          ref,
          target: ReportTarget.member(person, groupId: group.id),
          what: name,
        );
    }
  }
}

/// A member's profile (H2), opened from the group they were seen in.
String personLocation(String person, {String? groupId}) => Uri(
  path: '/people/$person',
  queryParameters: groupId == null ? null : {'group': groupId},
).toString();

/// Removal with the cascade warning: lists every visible subgroup the
/// person also leaves, then removes them after confirmation.
Future<bool> confirmRemoveMember(
  BuildContext context,
  WidgetRef ref,
  CircleGroup group,
  String person,
  String name,
) async {
  final controller = ref.read(circleWorkspaceProvider.notifier);
  final impact = await runCalmly(
    context,
    () => controller.removalImpact(group.id, person),
  );
  if (impact == null || !context.mounted) return false;
  final confirmed = await confirmCircleAction(
    context,
    title: 'Remove $name?',
    message: impact.isEmpty
        ? '$name will lose access to ${group.name} and any of its subgroups they belong to.'
        : '$name will lose access to ${group.name} and also leave:',
    details: [
      ...impact,
      if (impact.isNotEmpty)
        'Any other subgroups of ${group.name} they belong to',
    ],
    confirm: 'Remove',
  );
  if (!confirmed || !context.mounted) return false;
  final done = await runCalmly(context, () async {
    await controller.removeMember(group.id, person);
    return true;
  }, success: '$name was removed.');
  return done == true;
}
