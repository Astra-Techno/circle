import '../../../core/design/circle_icons.dart';
import '../../../core/design/circle_typography.dart';
import 'group_photos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../albums/presentation/albums_tab.dart';
import '../../memories/presentation/circle_memories.dart';
import '../../memories/presentation/scoped_memory_list.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/feature_gate.dart';
import '../../workspace/presentation/group_visuals.dart';
import '../../workspace/presentation/workspace_view.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../domain/group_tree.dart';
import '../domain/membership_rules.dart';
import 'circle_groups.dart';
import 'group_members.dart';

class CircleGroupDetail extends StatelessWidget {
  const CircleGroupDetail({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      final group = workspace.group(id);
      if (group == null) {
        final pending = workspace.pending
            .where((item) => item.groupId == id)
            .firstOrNull;
        if (pending != null) return PendingGroupView(pending: pending);
        return const ReadingPane(
          child: CircleEmpty(
            icon: LucideIcons.users,
            title: 'This circle is private',
            message:
                'You need membership in this exact Circle to see what is shared here.',
          ),
        );
      }
      return _GroupMemories(group: group, workspace: workspace);
    },
  );
}

/// A requested group reveals only its name until someone approves.
class PendingGroupView extends ConsumerWidget {
  const PendingGroupView({super.key, required this.pending});
  final PendingGroup pending;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ReadingPane(
    child: ListView(
      padding: CircleInsets.form,
      children: [
        CircleEmpty(
          title: pending.name,
          message:
              'Waiting for approval. You’ll see Memories and members once an admin approves your request.',
          action: OutlinedButton(
            onPressed: () async {
              final done = await runCalmly(context, () async {
                await ref
                    .read(circleWorkspaceProvider.notifier)
                    .cancelRequest(pending.requestId);
                return true;
              }, success: 'Request cancelled.');
              if (done == true && context.mounted) context.go('/groups');
            },
            child: const Text('Cancel request'),
          ),
        ),
      ],
    ),
  );
}

/// One continuous page; secondary destinations stay in the header actions.
class _GroupMemories extends ConsumerWidget {
  const _GroupMemories({required this.group, required this.workspace});
  final CircleGroup group;
  final CircleWorkspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ReadingPane(
    child: RefreshIndicator(
      onRefresh: () async {
        await runCalmly(
          context,
          () => ref.read(circleWorkspaceProvider.notifier).refresh(),
        );
        if (context.mounted) {
          ref.invalidate(
            memoryTimelineProvider(MemoryQuery(groupId: group.id)),
          );
        }
      },
      child: CustomScrollView(
        key: PageStorageKey('circle-memories-${group.id}'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _GroupHeader(group: group, workspace: workspace),
          ),
          SliverToBoxAdapter(
            child: ScopedMemoryList(
              query: MemoryQuery(groupId: group.id),
              empty: const CircleEmpty(
                icon: LucideIcons.image,
                title: 'The first Memory is yours to make',
                message: 'Use Memory to share a moment with this Circle.',
              ),
              itemBuilder: (_, memory) => CircleMemoryCard(
                key: ValueKey(memory.id),
                memory: memory,
                group: group,
                audience: audiencePath(group, workspace.groupsById),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: Space.hero)),
        ],
      ),
    ),
  );
}

/// Members and InCircles keep exact-group access and a normal Back destination.
class CircleGroupSection extends StatelessWidget {
  const CircleGroupSection({
    super.key,
    required this.id,
    required this.section,
  });
  final String id;
  final String section;
  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      final group = workspace.group(id);
      if (group == null) {
        return const ReadingPane(
          child: CircleEmpty(
            title: 'This circle is private',
            message:
                'You need membership in this exact Circle to see this page.',
          ),
        );
      }
      return ReadingPane(
        child: ListView(
          padding: CircleInsets.form,
          children: [
            CircleHeading(title: group.name, subtitle: ''),
            if (section == 'members')
              GroupMembersTab(group: group, workspace: workspace),
            if (section == 'incircles')
              SubgroupsTab(group: group, workspace: workspace),
            if (section == 'albums')
              CircleFeatureGate(
                feature: CircleFeature.albums,
                inline: true,
                child: AlbumsTab(group: group),
              ),
          ],
        ),
      );
    },
  );
}

class _GroupHeader extends ConsumerWidget {
  const _GroupHeader({required this.group, required this.workspace});
  final CircleGroup group;
  final CircleWorkspace workspace;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = workspace.viewer;
    final role = group.roles[viewer]!;
    final lineage = groupLineage(group, workspace.groupsById);
    final requests = workspace.joinRequests
        .where((request) => request.groupId == group.id)
        .length;
    final canInvite = MembershipRules.canInvite(group, viewer).allowed;
    final reports = workspace.openReports[group.id] ?? 0;
    final features = ref.watch(circleFeaturesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Breadcrumb lineage.
        if (lineage.length > 1)
          Padding(
            padding: CircleInsets.content,
            child: Semantics(
              label: 'Where this Circle sits',
              container: true,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final (index, ancestor) in lineage.indexed) ...[
                    if (index > 0)
                      const ExcludeSemantics(
                        child: Icon(CircleIcons.chevronRight),
                      ),
                    TextButton(
                      onPressed: ancestor.id == group.id
                          ? null
                          : () => context.push('/groups/g/${ancestor.id}'),
                      child: Text(ancestor.name),
                    ),
                  ],
                ],
              ),
            ),
          ),
        // Cover photo.
        GroupPhotoHeader(
          group: group,
          titleAccessory: role == CircleRole.member
              ? null
              : _RoleBadge(role: role),
        ),
        const SizedBox(height: Space.md),

        // Compact stat pills row.
        Padding(
          padding: CircleInsets.content,
          child: Wrap(
            spacing: Space.xs,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatPill(
                icon: LucideIcons.users,
                label:
                    '${group.roles.length} ${group.roles.length == 1 ? 'member' : 'members'}',
                onTap: () => context.push('/groups/g/${group.id}/members'),
              ),
              const ExcludeSemantics(child: Text('·')),
              _StatPill(
                icon: LucideIcons.layers,
                label: 'InCircles',
                onTap: () => context.push('/groups/g/${group.id}/incircles'),
              ),
              if (group.isSubgroup)
                _StatPill(
                  icon: group.hidden ? LucideIcons.lock : LucideIcons.link,
                  label: group.hidden ? 'Hidden' : 'Listed',
                ),
              if (requests > 0)
                _StatPill(
                  icon: LucideIcons.user_check,
                  label: '$requests ${requests == 1 ? 'request' : 'requests'}',
                  highlight: true,
                  onTap: () => context.push('/groups/g/${group.id}/members'),
                ),
              if (reports > 0)
                _StatPill(
                  icon: LucideIcons.flag,
                  label: '$reports ${reports == 1 ? 'report' : 'reports'}',
                  highlight: true,
                  onTap: () => context.push('/groups/g/${group.id}/reports'),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),

        // Quick action icon buttons.
        Padding(
          padding: CircleInsets.content,
          child: _GroupActionGrid(
            children: [
              if (features.has(CircleFeature.liveChat))
                _QuickAction(
                  icon: LucideIcons.messages_square,
                  label: 'Chat',
                  primary: true,
                  onTap: () => context.push('/chats/g/${group.id}'),
                ),
              if (canInvite)
                _QuickAction(
                  icon: LucideIcons.user_plus,
                  label: 'Invite',
                  onTap: () => context.push('/groups/g/${group.id}/invite'),
                ),
              if (features.has(CircleFeature.liveEvents))
                _QuickAction(
                  icon: LucideIcons.calendar,
                  label: 'Events',
                  onTap: () => context.push('/groups/g/${group.id}/events'),
                ),
              if (features.has(CircleFeature.livePolls))
                _QuickAction(
                  icon: LucideIcons.chart_bar,
                  label: 'Polls',
                  onTap: () => context.push('/polls?group=${group.id}'),
                ),
              _QuickAction(
                icon: LucideIcons.plus,
                label: 'Memory',
                onTap: () => context.push(composeLocation(group.id)),
              ),
              if (features.has(CircleFeature.albums))
                _QuickAction(
                  icon: LucideIcons.images,
                  label: 'Albums',
                  onTap: () => context.push('/groups/g/${group.id}/albums'),
                ),
              _QuickAction(
                icon: LucideIcons.settings,
                label: 'Settings',
                onTap: () => context.push('/groups/g/${group.id}/settings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
      ],
    );
  }
}

/// Balanced rows; measure the effective bold/scaled label before choosing columns.
class _GroupActionGrid extends StatelessWidget {
  const _GroupActionGrid({required this.children});
  final List<_QuickAction> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final minimum = children.fold<double>(CircleSizes.minTouchTarget, (
        width,
        child,
      ) {
        final needed =
            CircleLayout.quickActionWidth(context, child.label) + Space.md * 2;
        return needed > width ? needed : width;
      });
      final columns = ((constraints.maxWidth + Space.sm) / (minimum + Space.sm))
          .floor()
          .clamp(1, 3);
      final width = (constraints.maxWidth - Space.sm * (columns - 1)) / columns;
      return Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final CircleRole role;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(CircleRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.sm,
          vertical: Space.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              role == CircleRole.owner ? LucideIcons.crown : LucideIcons.shield,
              size: CircleSizes.iconInline,
              color: colors.primary,
            ),
            const SizedBox(width: Space.xs),
            Text(
              circleRoleLabel(role),
              style: CircleTextStyles.metadata(colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiet metadata link with a full touch target and no navigation chevron.
class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    this.highlight = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accents = CircleAccents.of(context);
    final color = highlight ? accents.heart : accents.caption;
    final bg = highlight
        ? accents.heartContainer
        : Theme.of(context).colorScheme.surface;
    final pill = Container(
      constraints: const BoxConstraints(minHeight: CircleSizes.minTouchTarget),
      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(CircleRadius.button),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: CircleSizes.iconInline, color: color),
          const SizedBox(width: Space.xs),
          Text(label, style: CircleTextStyles.homeShortcut(color)),
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(
        key: ValueKey('circle-metadata-$label'),
        borderRadius: BorderRadius.circular(CircleRadius.button),
        onTap: onTap,
        child: pill,
      );
    }
    return pill;
  }
}

/// Compact action tile matching the selected Circle identity design.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final accents = CircleAccents.of(context);
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(CircleRadius.card),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: primary
                ? Theme.of(context).colorScheme.primaryContainer
                : accents.recessed,
            borderRadius: BorderRadius.circular(CircleRadius.tile),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: CircleSizes.iconAction,
                color: primary
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(height: Space.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                style: CircleTextStyles.homeShortcut(
                  primary
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showCreateSubgroupSheet(
  BuildContext context,
  WidgetRef ref,
  CircleGroup parent,
) async {
  final created = await showModalBottomSheet<CircleGroup>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _CreateSubgroupSheet(parent: parent),
  );
  if (created != null && context.mounted) {
    context.push('/groups/g/${created.id}');
  }
}

class _CreateSubgroupSheet extends ConsumerStatefulWidget {
  const _CreateSubgroupSheet({required this.parent});
  final CircleGroup parent;

  @override
  ConsumerState<_CreateSubgroupSheet> createState() =>
      _CreateSubgroupSheetState();
}

class _CreateSubgroupSheetState extends ConsumerState<_CreateSubgroupSheet> {
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
    final trimmed = _name.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _error = 'Enter a name for the Circle.');
      return;
    }
    if (trimmed.length > 100) {
      setState(() => _error = 'Name must be 100 characters or fewer.');
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final group = await ref
          .read(circleWorkspaceProvider.notifier)
          .createGroup(
            trimmed,
            _type,
            parentId: widget.parent.id,
            hidden: !_listed,
          );
      if (mounted) Navigator.of(context).pop(group);
    } on CircleFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.md,
        0,
        Space.md,
        Space.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New InCircle in ${widget.parent.name}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: Space.xs),
            Text(
              'Only members of ${widget.parent.name} can join.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: CircleAccents.of(context).caption,
              ),
            ),
            const SizedBox(height: Space.section),
            TextField(
              controller: _name,
              autofocus: true,
              buildCounter: CircleFormMetrics.counter,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Circle name',
                errorText: _error,
                errorMaxLines: 3,
              ),
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: Space.md),
            DropdownButtonFormField<CircleType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Kind of Circle'),
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
            const SizedBox(height: Space.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('List in ${widget.parent.name}'),
              subtitle: Text(
                _listed
                    ? 'Members of ${widget.parent.name} can see its name and ask to join.'
                    : 'Hidden: only people you invite will know it exists.',
              ),
              value: _listed,
              onChanged: (value) => setState(() => _listed = value),
            ),
            const SizedBox(height: Space.md),
            FilledButton.icon(
              onPressed: _busy ? null : _create,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: Space.md,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.plus),
              label: Text(_busy ? 'Creating\u2026' : 'Create InCircle'),
            ),
          ],
        ),
      ),
    );
  }
}

class SubgroupsTab extends ConsumerWidget {
  const SubgroupsTab({super.key, required this.group, required this.workspace});
  final CircleGroup group;
  final CircleWorkspace workspace;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = buildGroupTree(
      workspace.groups.where((item) => item.parentId == group.id),
    );
    final joinable = workspace.discoverable
        .where((preview) => preview.parentId == group.id)
        .toList();
    final canCreate = MembershipRules.canCreateGroup(
      person: workspace.viewer,
      parent: group,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mine.isEmpty && joinable.isEmpty)
          const CircleEmpty(
            icon: LucideIcons.users,
            title: 'A smaller circle, when you need one',
            message: 'Each InCircle has its own members.',
          ),
        for (final entry in mine) CircleGroupTile(group: entry.group),
        if (joinable.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Text(
            'More in ${group.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Space.md),
          for (final preview in joinable)
            _JoinableTile(
              preview: preview,
              reported: workspace.reported(ReportKind.subgroup, preview.id),
              pending: workspace.pending
                  .where((item) => item.groupId == preview.id)
                  .firstOrNull,
            ),
        ],
        const SizedBox(height: Space.md),
        if (canCreate.allowed)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => _showCreateSubgroupSheet(context, ref, group),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Create InCircle'),
            ),
          )
        else
          Text(canCreate.reason!),
        const SizedBox(height: Space.md),
        Text(
          'Hidden Circles are shown only to their members.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _JoinableTile extends ConsumerWidget {
  const _JoinableTile({
    required this.preview,
    this.pending,
    this.reported = false,
  });
  final GroupPreview preview;
  final PendingGroup? pending;
  final bool reported;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(circleWorkspaceProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(preview.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Space.xs),
            Text(
              [
                '${preview.memberCount} ${preview.memberCount == 1 ? 'member' : 'members'}',
                if (pending != null)
                  'Waiting for approval'
                else if (preview.approvalRequired)
                  'Admins approve new members'
                else
                  'Open to members of ${preview.parentName}',
              ].join(' · '),
            ),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [_joinAction(context, controller)],
            ),
          ],
        ),
      ),
    );
  }

  Widget _joinAction(
    BuildContext context,
    CircleWorkspaceController controller,
  ) => pending != null
      ? TextButton(
          onPressed: () => runCalmly(
            context,
            () => controller.cancelRequest(pending!.requestId),
            success: 'Request cancelled.',
          ),
          child: Text(
            'Cancel request',
            semanticsLabel: 'Cancel request to join ${preview.name}',
          ),
        )
      : FilledButton.tonal(
          onPressed: () async {
            final outcome = await runCalmly(
              context,
              () => controller.requestToJoin(preview.id),
            );
            if (outcome == null || !context.mounted) return;
            showCircleMessage(
              context,
              outcome == JoinOutcome.joined
                  ? 'You joined ${preview.name}.'
                  : 'Request sent to the admins of ${preview.name}.',
            );
          },
          child: Text(
            preview.approvalRequired ? 'Ask to join' : 'Join',
            semanticsLabel:
                '${preview.approvalRequired ? 'Ask to join' : 'Join'} ${preview.name}',
          ),
        );
}
