import 'group_photos.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/two_pane.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/group_visuals.dart';
import '../../workspace/presentation/workspace_view.dart';
import '../domain/group_tree.dart';
import '../domain/membership_rules.dart';
import 'invite_link_screen.dart';
import 'contact_invitation_entry.dart';

/// Indentation steps stop growing after this many levels; deeper levels
/// stay distinguishable through the "Level n · in Parent" hint.
const _indentStep = 16.0, _indentLevels = 4;

class CircleGroups extends ConsumerStatefulWidget {
  const CircleGroups({super.key});
  @override
  ConsumerState<CircleGroups> createState() => _CircleGroupsState();
}

class _CircleGroupsState extends ConsumerState<CircleGroups> {
  String _query = '';
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      final searching = _query.isNotEmpty;
      final entries = searching
          ? buildGroupTree(
              workspace.groups,
            ).where((e) => e.group.name.toLowerCase().contains(_query)).toList()
          : buildGroupTree(workspace.groups, collapsed: _collapsed);
      return ReadingPane(
        child: ListView(
          padding: CircleInsets.page,
          children: [
            const CircleIntroPanel(
              title: 'Your kind of company.',
              subtitle: 'A little closer to the people who matter.',
              icon: Icons.diversity_2_outlined,
            ),
            const SizedBox(height: Space.section),
            if (ref.watch(circleFeaturesProvider).server)
              const ContactInvitationEntry(),
            if (!ref.watch(circleFeaturesProvider).server &&
                workspace.invitations.isNotEmpty) ...[
              ExpansionTile(
                key: const PageStorageKey('group-invitations'),
                initiallyExpanded: workspace.groups.isEmpty,
                tilePadding: const EdgeInsets.symmetric(horizontal: Space.lg),
                childrenPadding: const EdgeInsets.all(Space.sm),
                leading: const CircleInitialAvatar(
                  icon: Icons.mark_email_unread_outlined,
                ),
                title: const Text('Invitations for you'),
                subtitle: Text(
                  '${workspace.invitations.length} waiting to be reviewed',
                ),
                children: [
                  for (final invitation in workspace.invitations)
                    InvitationCard(invitation: invitation),
                ],
              ),
              const SizedBox(height: Space.lg),
            ],
            if (workspace.groups.isNotEmpty)
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search groups',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => openInviteLinkDialog(context, ref),
                icon: const Icon(Icons.link),
                label: const Text('Open an invite link'),
              ),
            ),
            const SizedBox(height: Space.sm),
            if (entries.isEmpty)
              CircleEmpty(
                title: workspace.groups.isEmpty
                    ? 'Start with someone you know'
                    : 'No groups found',
                message: workspace.groups.isEmpty
                    ? 'Create your first private group, or open an invite link someone shared with you.'
                    : 'Try a different group name.',
                action: workspace.groups.isEmpty
                    ? FilledButton(
                        onPressed: () => context.push('/groups/new'),
                        child: const Text('Create a group'),
                      )
                    : null,
              ),
            if (entries.isNotEmpty) const CircleSectionTitle('Your groups'),
            for (final entry in entries)
              CircleGroupTile(
                group: entry.group,
                level: searching ? 0 : entry.level,
                where: searching && entry.path.isNotEmpty
                    ? entry.path.join(' › ')
                    : entry.path.lastOrNull,
                requests: workspace.joinRequests
                    .where((request) => request.groupId == entry.group.id)
                    .length,
                expanded: searching || !entry.hasChildren
                    ? null
                    : entry.expanded,
                onToggle: () => setState(() {
                  if (!_collapsed.remove(entry.group.id)) {
                    _collapsed.add(entry.group.id);
                  }
                }),
              ),
            if (workspace.pending.isNotEmpty) ...[
              const SizedBox(height: Space.lg),
              const CircleSectionTitle('Waiting for approval'),
              for (final pending in workspace.pending)
                CircleRow(
                  child: ListTile(
                    leading: const CircleInitialAvatar(
                      icon: Icons.hourglass_empty,
                      tone: CircleTone.neutral,
                    ),
                    title: Text(pending.name),
                    subtitle: const Text('Waiting for approval'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/groups/g/${pending.groupId}'),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class CircleGroupTile extends ConsumerWidget {
  const CircleGroupTile({
    super.key,
    required this.group,
    this.level = 0,
    this.where,
    this.requests = 0,
    this.expanded,
    this.onToggle,
  });
  final CircleGroup group;

  /// Visual nesting level within the list (0 = top).
  final int level;

  /// Where the group sits, e.g. its parent's name or a full path.
  final String? where;
  final int requests;

  /// Null when the tile has no collapsible children.
  final bool? expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(circleViewerProvider);
    final role = group.roles[viewer];
    final tone = circleToneColors(context, circleTypeTone(group.type));
    final indent = math.min(level, _indentLevels) * _indentStep;
    final details = [
      '${group.roles.length} ${group.roles.length == 1 ? 'member' : 'members'}',
      if (role != null) circleRoleLabel(role),
      if (group.depth > 1) 'Level ${group.depth}',
      if (where != null) 'in $where',
    ].join(' · ');
    return Container(
      padding: EdgeInsetsDirectional.only(start: indent),
      margin: EdgeInsets.only(bottom: level == 0 ? Space.sm : 0),
      decoration: level == 0 ? CircleDepth.dock(context) : null,
      child: CircleRow(
        divider: level > 0,
        child: DecoratedBox(
          // A start-edge guide marks nested groups.
          decoration: level == 0
              ? const BoxDecoration()
              : BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(color: tone.dot, width: 3),
                  ),
                ),
          child: ListTile(
            contentPadding: const EdgeInsetsDirectional.fromSTEB(
              Space.lg,
              Space.md,
              Space.sm,
              Space.md,
            ),
            leading: GroupAvatar(groupId: group.id, type: group.type),
            title: Text(group.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(details),
                if (requests > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: CircleBadge(
                      requests == 1
                          ? '1 request to review'
                          : '$requests requests to review',
                      strong: true,
                    ),
                  ),
              ],
            ),
            trailing: expanded == null
                ? const Icon(Icons.chevron_right)
                : IconButton(
                    tooltip: expanded!
                        ? 'Collapse ${group.name}'
                        : 'Expand ${group.name}',
                    icon: Icon(
                      expanded! ? Icons.expand_less : Icons.expand_more,
                    ),
                    onPressed: onToggle,
                  ),
            selected: CirclePaneScope.isSelected(context, 'groups', group.id),
            onTap: () {
              if (!CirclePaneScope.select(context, 'groups', group.id)) {
                context.push('/groups/g/${group.id}');
              }
            },
          ),
        ),
      ),
    );
  }
}

/// A direct invitation waiting for the viewer's consent.
class InvitationCard extends ConsumerWidget {
  const InvitationCard({super.key, required this.invitation});
  final InvitationView invitation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(circleWorkspaceProvider.notifier);
    final id = invitation.invitation.id;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invitation.groupName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Space.xs),
            Text(
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              [
                '${invitation.inviterName} invited you',
                '${invitation.memberCount} members',
                if (invitation.parentName != null)
                  'in ${invitation.parentName}',
              ].join(' · '),
            ),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                FilledButton(
                  onPressed: () async {
                    final outcome = await runCalmly(
                      context,
                      () => controller.respondToInvitation(id, accept: true),
                    );
                    if (outcome == null || !context.mounted) return;
                    showCircleMessage(
                      context,
                      outcome == JoinOutcome.joined
                          ? 'You joined ${invitation.groupName}.'
                          : 'Request sent. An admin of ${invitation.groupName} will review it.',
                    );
                  },
                  child: Text(
                    'Accept',
                    semanticsLabel:
                        'Accept invitation to ${invitation.groupName}',
                  ),
                ),
                TextButton(
                  onPressed: () => runCalmly(
                    context,
                    () => controller.respondToInvitation(id, accept: false),
                    success: 'Invitation declined.',
                  ),
                  child: Text(
                    'Decline',
                    semanticsLabel:
                        'Decline invitation to ${invitation.groupName}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CircleCreateGroup extends ConsumerStatefulWidget {
  const CircleCreateGroup({super.key, this.parentId});
  final String? parentId;
  @override
  ConsumerState<CircleCreateGroup> createState() => _CircleCreateGroupState();
}

class _CircleCreateGroupState extends ConsumerState<CircleCreateGroup> {
  final _name = TextEditingController();
  CircleType _type = CircleType.friends;
  bool _listed = true;
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final group = await ref
          .read(circleWorkspaceProvider.notifier)
          .createGroup(
            _name.text,
            _type,
            parentId: widget.parentId,
            hidden: !_listed,
          );
      if (mounted) context.go('/groups/g/${group.id}');
    } on CircleFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      final parent = widget.parentId == null
          ? null
          : workspace.group(widget.parentId!);
      if (widget.parentId != null) {
        final rule = MembershipRules.canCreateGroup(
          person: workspace.viewer,
          parent: parent,
        );
        if (!rule.allowed) {
          return ReadingPane(
            child: ListView(
              padding: CircleInsets.form,
              children: [
                CircleEmpty(
                  title: 'A subgroup can’t be added here',
                  message: rule.reason!,
                ),
              ],
            ),
          );
        }
      }
      return ReadingPane(
        child: ListView(
          padding: CircleInsets.form,
          children: [
            CircleHeading(
              title: parent == null
                  ? 'Bring your\npeople together.'
                  : 'Make a little\nroom within.',
              subtitle: parent == null
                  ? 'A private group, with you as its owner.'
                  : 'A subgroup of ${parent.name}, with you as its owner. Only members of ${parent.name} can join it.',
            ),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: 'Group name',
                hintText: 'Something your people will recognise',
                errorText: _error,
                errorMaxLines: 4,
              ),
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: Space.section),
            DropdownButtonFormField<CircleType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Kind of group'),
              items: [
                for (final type in CircleType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(circleTypeLabel(type)),
                  ),
              ],
              onChanged: (type) {
                if (type != null) setState(() => _type = type);
              },
            ),
            if (parent != null)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('More options'),
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _listed,
                    title: Text('List in ${parent.name}'),
                    subtitle: Text(
                      _listed
                          ? 'Members of ${parent.name} can see its name and ask to join.'
                          : 'Hidden: only people you invite will know it exists.',
                    ),
                    onChanged: (value) => setState(() => _listed = value),
                  ),
                ],
              ),
            const SizedBox(height: Space.section),
            const Text(
              'Only you are added. Others join with your invite link or by accepting an invitation.',
            ),
            const SizedBox(height: Space.section),
            FilledButton(
              onPressed: _busy ? null : _create,
              child: Text(
                _busy
                    ? 'Creating…'
                    : parent == null
                    ? 'Create private group'
                    : 'Create subgroup',
              ),
            ),
          ],
        ),
      );
    },
  );
}
