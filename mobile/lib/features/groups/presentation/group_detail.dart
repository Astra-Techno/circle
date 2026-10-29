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
  'Subgroups',
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
            title: 'This circle is private',
            message:
                'You need membership in this exact group to see what is shared here.',
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
      final side = math.max(Space.lg, (constraints.maxWidth - 640) / 2);
      final padding = CircleInsets.page.copyWith(left: side, right: side);
      return DefaultTabController(
        length: tabs.length,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, Space.md, side, 0),
              sliver: SliverToBoxAdapter(
                child: _GroupHeader(group: group, workspace: workspace),
              ),
            ),
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
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
                        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
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
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Share a Memory here'),
              ),
              if (ref
                  .watch(circleFeaturesProvider)
                  .has(CircleFeature.livePolls))
                OutlinedButton.icon(
                  onPressed: () => context.push('/polls?group=${group.id}'),
                  icon: const Icon(Icons.poll_outlined),
                  label: const Text('Polls'),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
          ScopedMemoryList(
            query: MemoryQuery(groupId: group.id),
            empty: const CircleEmpty(
              title: 'The first Memory is yours to make',
              message: 'Share a little moment with this exact group.',
            ),
            itemBuilder: (_, memory) =>
                CircleMemoryCard(memory: memory, group: group),
          ),
        ];
      case 'Subgroups':
        return [SubgroupsTab(group: group, workspace: workspace)];
      case 'Members':
        return [GroupMembersTab(group: group, workspace: workspace)];
      case 'Events':
        return [
          CircleFeatureGate(
            feature: CircleFeature.liveEvents,
            inline: true,
            child: CircleEmpty(
              title: 'Events for ${group.name}',
              message: 'Make plans with this exact circle.',
              action: FilledButton.icon(
                onPressed: () => context.go('/events?group=${group.id}'),
                icon: const Icon(Icons.event_outlined),
                label: const Text('Open group events'),
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
              title: 'Talk with everyone in ${group.name}',
              message: 'Private messages saved for this group.',
              action: FilledButton.icon(
                onPressed: () => context.go('/chats/g/${group.id}'),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Open group chat'),
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
          Semantics(
            label: 'Where this group sits',
            container: true,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (index, ancestor) in lineage.indexed) ...[
                  if (index > 0)
                    const ExcludeSemantics(child: Icon(Icons.chevron_right)),
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
        GroupPhotoHeader(group: group),
        const SizedBox(height: Space.sm),
        Text(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: CircleAccents.of(context).caption,
          ),
          [
            '${group.roles.length} ${group.roles.length == 1 ? 'member' : 'members'}',
            'You: ${circleRoleLabel(role)}',
            group.isSubgroup
                ? (group.hidden ? 'Hidden subgroup' : 'Listed subgroup')
                : 'Private group',
          ].join(' · '),
        ),
        const SizedBox(height: Space.lg),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (canInvite)
              FilledButton.icon(
                onPressed: () => context.push('/groups/g/${group.id}/invite'),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Invite people'),
              ),
            if (requests > 0)
              OutlinedButton.icon(
                onPressed: () => DefaultTabController.of(context).animateTo(
                  groupTabsFor(
                    ref.read(circleFeaturesProvider),
                  ).indexOf('Members'),
                ),
                icon: const Icon(Icons.how_to_reg_outlined),
                label: Text(requests == 1 ? '1 request' : '$requests requests'),
              ),
            if (reports > 0) GroupReportsButton(group: group, count: reports),
            TextButton.icon(
              onPressed: () => context.push('/groups/g/${group.id}/settings'),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Settings'),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
      ],
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
            title: 'A smaller circle, when you need one',
            message:
                'Subgroups have their own members. Access is never inherited.',
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
              icon: const Icon(Icons.add),
              label: const Text('Create subgroup'),
            ),
          )
        else
          Text(canCreate.reason!),
        const SizedBox(height: Space.md),
        Text(
          'Hidden subgroups are shown only to their members.',
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
