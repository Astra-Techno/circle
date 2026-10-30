import '../../../core/form_exit_guard.dart';
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
const _indentStep = Space.section, _indentLevels = 4;

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
        child: CustomScrollView(
          slivers: [
            // Collapsing pinned header: large title shrinks to compact bar.
            const CircleCollapsingHeader(),
            SliverPadding(
              padding: CircleInsets.page,
              sliver: SliverList.list(
                children: [
                  const ContactInvitationEntry(),
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
                  if (entries.isNotEmpty)
                    const CircleSectionTitle('Your groups'),
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
                          onTap: () =>
                              context.push('/groups/g/${pending.groupId}'),
                        ),
                      ),
                  ],
                ],
              ),
            ),
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
    final indent = math.min(level, _indentLevels) * _indentStep;
    final nested = level > 0;
    final avatar = nested ? CircleAvatarSize.small : CircleAvatarSize.medium;
    final accents = CircleAccents.of(context);
    final details = [
      '${group.roles.length} ${group.roles.length == 1 ? 'member' : 'members'}',
      if (role != null) circleRoleLabel(role),
      // Nested rows sit under their parent, so the place is already clear.
      if (where != null && !nested) 'in $where',
    ].join(' · ');
    final selected = CirclePaneScope.isSelected(context, 'groups', group.id);
    // One clean list: subgroups indent under their parent with a smaller
    // avatar; the divider starts where the names start.
    return Material(
      color: selected
          ? accents.calmContainer
          : Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () {
          if (!CirclePaneScope.select(context, 'groups', group.id)) {
            context.push('/groups/g/${group.id}');
          }
        },
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: indent),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: Row(
                  children: [
                    GroupAvatar(
                      groupId: group.id,
                      type: group.type,
                      size: avatar,
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            details,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: accents.caption),
                          ),
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
                    ),
                    if (expanded == null)
                      Padding(
                        padding: const EdgeInsets.all(Space.md),
                        child: Icon(
                          Icons.chevron_right,
                          color: accents.caption,
                        ),
                      )
                    else
                      IconButton(
                        tooltip: expanded!
                            ? 'Collapse ${group.name}'
                            : 'Expand ${group.name}',
                        icon: Icon(
                          expanded! ? Icons.expand_less : Icons.expand_more,
                          color: accents.caption,
                        ),
                        onPressed: onToggle,
                      ),
                  ],
                ),
              ),
              Divider(height: 1, indent: avatar.diameter + Space.md),
            ],
          ),
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
  final _edits = FormExitController();
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
      if (mounted) {
        _edits.commit();
        context.go('/groups/g/${group.id}');
      }
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
      return UnsavedForm(
        controller: _edits,
        fields: [_name],
        fingerprint: () => '${_name.text}\u0000$_type\u0000$_listed',
        child: ReadingPane(
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
        ),
      );
    },
  );
}
