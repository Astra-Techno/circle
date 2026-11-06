import '../../../core/design/circle_icons.dart';
import 'group_photos.dart';
import 'dart:math' as math;
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
import 'group_reports.dart';

/// The group's tabs, most used first. Albums appear only when the server
/// offers them, so five tabs fit a phone without scrolling.
List<String> groupTabsFor(CircleFeatures features) => [
  'Memories',
  'Chat',
  'Events',
  'Members',
  'InCircles',
  if (features.has(CircleFeature.albums)) 'Albums',
];

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
      return _GroupTabs(group: group, workspace: workspace);
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

class _GroupTabs extends ConsumerWidget {
  const _GroupTabs({required this.group, required this.workspace});
  final CircleGroup group;
  final CircleWorkspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final tabs = groupTabsFor(ref.watch(circleFeaturesProvider));
      final side = math.max(
        Space.contentInset,
        (constraints.maxWidth - 640) / 2,
      );
      final padding = CircleInsets.page.copyWith(left: side, right: side);
      return DefaultTabController(
        length: tabs.length,
        child: _GroupTabNavigation(
          group: group.id,
          tabs: tabs,
          child: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: side - Space.contentInset,
                ),
                sliver: SliverToBoxAdapter(
                  child: _GroupHeader(group: group, workspace: workspace),
                ),
              ),
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
                sliver: SliverAppBar(
                  pinned: true,
                  primary: false,
                  automaticallyImplyLeading: false,
                  toolbarHeight: 0,
                  // Six tabs scroll; the faded edge shows there is more.
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(kTextTabBarHeight),
                    child: CircleEdgeFade(
                      child: TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        padding: EdgeInsets.symmetric(
                          horizontal: side - Space.sm,
                        ),
                        tabs: [
                          for (final label in tabs)
                            Tab(
                              child: ConstrainedBox(
                                // With the label padding: a 48px tap target.
                                constraints: const BoxConstraints(
                                  minWidth: Space.hero,
                                ),
                                child: Text(label, textAlign: TextAlign.center),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            body: TabBarView(
              children: [
                for (final label in tabs)
                  Builder(
                    builder: (context) => CustomScrollView(
                      key: PageStorageKey('group-${group.id}-$label'),
                      slivers: [
                        SliverOverlapInjector(
                          handle:
                              NestedScrollView.sliverOverlapAbsorberHandleFor(
                                context,
                              ),
                        ),
                        SliverPadding(
                          padding: padding,
                          sliver: SliverList.list(
                            children: _tab(context, ref, label),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  List<Widget> _tab(BuildContext context, WidgetRef ref, String tab) {
    switch (tab) {
      case 'Memories':
        return [
          // Both actions share one row and wrap only when space runs out.
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push(composeLocation(group.id)),
                icon: const Icon(LucideIcons.pencil),
                label: const Text('Share a Memory here'),
              ),
              if (ref
                  .watch(circleFeaturesProvider)
                  .has(CircleFeature.livePolls))
                OutlinedButton.icon(
                  onPressed: () => context.push('/polls?group=${group.id}'),
                  icon: const Icon(LucideIcons.chart_bar),
                  label: const Text('Polls'),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
          ScopedMemoryList(
            query: MemoryQuery(groupId: group.id),
            empty: const CircleEmpty(
              icon: LucideIcons.image,
              title: 'The first Memory is yours to make',
              message: 'Share a little moment with this exact Circle.',
            ),
            itemBuilder: (_, memory) =>
                CircleMemoryCard(memory: memory, group: group),
          ),
        ];
      case 'InCircles':
        return [SubgroupsTab(group: group, workspace: workspace)];
      case 'Members':
        return [GroupMembersTab(group: group, workspace: workspace)];
      case 'Events':
        return [
          CircleFeatureGate(
            feature: CircleFeature.liveEvents,
            inline: true,
            child: CircleEmpty(
              icon: LucideIcons.calendar_days,
              title: 'Events for ${group.name}',
              message: 'Make plans with this exact circle.',
              action: FilledButton.icon(
                onPressed: () => context.go('/events?group=${group.id}'),
                icon: const Icon(LucideIcons.calendar),
                label: const Text('Open Circle events'),
              ),
            ),
          ),
        ];
      case 'Chat':
        return [
          CircleFeatureGate(
            feature: CircleFeature.liveChat,
            inline: true,
            child: CircleEmpty(
              icon: LucideIcons.message_circle,
              title: 'Talk with everyone in ${group.name}',
              message: 'Private messages saved for this group.',
              action: FilledButton.icon(
                onPressed: () => context.go('/chats/g/${group.id}'),
                icon: const Icon(LucideIcons.messages_square),
                label: const Text('Open Circle chat'),
              ),
            ),
          ),
        ];
      default:
        return [
          CircleFeatureGate(
            feature: CircleFeature.albums,
            inline: true,
            child: AlbumsTab(group: group),
          ),
        ];
    }
  }
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        GroupPhotoHeader(group: group),
        const SizedBox(height: Space.sm),
        Padding(
          padding: CircleInsets.content,
          child: Text(
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CircleAccents.of(context).caption,
            ),
            [
              '${group.roles.length} ${group.roles.length == 1 ? 'member' : 'members'}',
              'You: ${circleRoleLabel(role)}',
              if (group.isSubgroup)
                group.hidden ? 'Hidden InCircle' : 'Listed InCircle',
            ].join(' · '),
          ),
        ),
        const SizedBox(height: Space.sm),
        Padding(
          padding: CircleInsets.content,
          child: Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (canInvite)
                OutlinedButton.icon(
                  onPressed: () => context.push('/groups/g/${group.id}/invite'),
                  icon: const Icon(LucideIcons.user_plus),
                  label: const Text('Invite people'),
                ),
              if (requests > 0)
                OutlinedButton.icon(
                  onPressed: () => DefaultTabController.of(context).animateTo(
                    groupTabsFor(
                      ref.read(circleFeaturesProvider),
                    ).indexOf('Members'),
                  ),
                  icon: const Icon(LucideIcons.user_check),
                  label: Text(
                    requests == 1 ? '1 request' : '$requests requests',
                  ),
                ),
              if (reports > 0) GroupReportsButton(group: group, count: reports),
              if (MembershipRules.canCreateGroup(
                person: viewer,
                parent: group,
              ).allowed)
                OutlinedButton.icon(
                  onPressed: () => _showCreateSubgroupSheet(context, ref, group),
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Create Circle'),
                ),
              TextButton.icon(
                onPressed: () => context.push('/groups/g/${group.id}/settings'),
                icon: const Icon(LucideIcons.settings),
                label: const Text('Settings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
      ],
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
              'Create Circle in ${widget.parent.name}',
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
              label: Text(_busy ? 'Creating\u2026' : 'Create Circle'),
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
            message:
                'Each InCircle has its own members.',
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
              onPressed: () => context.push('/groups/new?parent=${group.id}'),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Create Circle'),
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

/// Chat and Events open directly, including selection by a swipe. Restore the
/// previous content tab so Back returns to useful group content.
class _GroupTabNavigation extends StatefulWidget {
  const _GroupTabNavigation({
    required this.group,
    required this.tabs,
    required this.child,
  });
  final String group;
  final List<String> tabs;
  final Widget child;
  @override
  State<_GroupTabNavigation> createState() => _GroupTabNavigationState();
}

class _GroupTabNavigationState extends State<_GroupTabNavigation> {
  TabController? _controller;
  int _contentIndex = 0;
  bool _opening = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.of(context);
    if (controller == _controller) return;
    _controller?.removeListener(_selected);
    _controller = controller..addListener(_selected);
  }

  void _selected() {
    final controller = _controller!;
    if (_opening || controller.indexIsChanging) return;
    final label = widget.tabs[controller.index];
    if (label != 'Chat' && label != 'Events') {
      _contentIndex = controller.index;
      return;
    }
    _opening = true;
    controller.index = _contentIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await context.push<void>(
          label == 'Chat'
              ? '/chats/g/${widget.group}'
              : '/groups/g/${widget.group}/events',
        );
      } finally {
        if (mounted) _opening = false;
      }
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_selected);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
