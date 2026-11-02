import '../../profile/presentation/person_avatar.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../groups/domain/group_tree.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/workspace_view.dart';
import '../application/circle_seen.dart';
import '../application/home_filter.dart';
import 'memory_card.dart';
import 'memory_photos.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

export 'memory_card.dart';
export 'memory_compose.dart';
export 'memory_detail.dart';
export 'memory_photos.dart';

class CircleHome extends ConsumerWidget {
  const CircleHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => WorkspaceView(
    builder: (workspace) {
      final selected = ref.watch(homeGroupFilterProvider);
      final groupId = workspace.groupsById.containsKey(selected)
          ? selected
          : null;
      final memories = workspace.memories
          .where((memory) => groupId == null || memory.groupId == groupId)
          .toList();
      final features = ref.watch(circleFeaturesProvider);

      final more = workspace.hasMoreMemories;
      return ColoredBox(
        color: CircleAccents.of(context).recessed,
        child: ReadingPane(
          child: RefreshIndicator(
            onRefresh: () => runCalmly(
              context,
              () => ref.read(circleWorkspaceProvider.notifier).refresh(),
            ),
            child: CustomScrollView(
              key: const PageStorageKey('circle-home'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const CircleFloatingHeader(),
                SliverList.builder(
                  itemCount: memories.length + 1 + (more ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == memories.length + 1) {
                      return const _LoadOlderMemories();
                    }
                    if (index == 0) {
                      return _HomeHeader(
                        workspace: workspace,
                        groupId: groupId,
                        hasMemories: memories.isNotEmpty,
                        features: features,
                      );
                    }
                    final memory = memories[index - 1];
                    final group = workspace.group(memory.groupId)!;
                    return CircleMemoryCard(
                      key: ValueKey(memory.id),
                      memory: memory,
                      group: group,
                      audience: audiencePath(group, workspace.groupsById),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// The composer area: Circle header, avatar + prompt, 4 quick-action tiles.
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({
    required this.workspace,
    required this.groupId,
    required this.hasMemories,
    required this.features,
  });
  final CircleWorkspace workspace;
  final String? groupId;
  final bool hasMemories;
  final CircleFeatures features;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accents = CircleAccents.of(context);
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (workspace.groups.isNotEmpty) ...[
            // Composer row: avatar + prompt.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.md,
                Space.md,
                Space.sm,
              ),
              child: Row(
                children: [
                  PersonAvatar(
                    person: workspace.viewer,
                    name: 'You',
                    size: CircleAvatarSize.medium,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Material(
                      color: accents.recessed,
                      borderRadius: BorderRadius.circular(Space.hero),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Space.hero),
                        onTap: () => context.push(composeLocation(groupId)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.section,
                            vertical: Space.md,
                          ),
                          child: Text(
                            'Share a memory with your Circle...',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: accents.caption,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Four quick-action icons.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                0,
                Space.md,
                Space.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickActionIcon(
                      icon: LucideIcons.image,
                      label: 'Photo',
                      color: theme.colorScheme.primary,
                      onTap: () => context.push(composeLocation(groupId)),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: _QuickActionIcon(
                      icon: LucideIcons.calendar,
                      label: 'Event',
                      color: accents.sage,
                      onTap: features.has(CircleFeature.liveEvents)
                          ? () => context.push('/events/new')
                          : null,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: _QuickActionIcon(
                      icon: LucideIcons.list,
                      label: 'Poll',
                      color: accents.amber,
                      onTap: features.has(CircleFeature.livePolls)
                          ? () => context.push('/polls/new')
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!hasMemories)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.section),
              child: _FirstSteps(workspace: workspace, groupId: groupId),
            ),
        ],
      ),
    );
  }
}

/// Quick action tile with a pastel tinted background and a visible label.
class _QuickActionIcon extends StatelessWidget {
  const _QuickActionIcon({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = onTap != null ? color : color.withValues(alpha: 0.4);
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(CircleRadius.card),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(CircleRadius.card),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: effectiveColor, size: Space.section),
                const SizedBox(height: Space.xs),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadOlderMemories extends ConsumerStatefulWidget {
  const _LoadOlderMemories();
  @override
  ConsumerState<_LoadOlderMemories> createState() => _LoadOlderState();
}

class _LoadOlderState extends ConsumerState<_LoadOlderMemories> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_error != null) setState(() => _error = null);
    try {
      await Future<void>.microtask(
        () => ref.read(circleWorkspaceProvider.notifier).loadMoreMemories(),
      );
    } on CircleFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.lg),
    child: Center(
      child: _error == null
          ? Semantics(
              label: 'Loading older Memories',
              child: const CircularProgressIndicator(),
            )
          : Column(
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: Space.sm),
                OutlinedButton(
                  onPressed: _load,
                  child: const Text('Try again'),
                ),
              ],
            ),
    ),
  );
}

/// Compose location with the audience in view, if any.
String composeLocation(String? groupId) => groupId == null
    ? '/compose'
    : Uri(path: '/compose', queryParameters: {'group': groupId}).toString();

/// "Just now", "5m ago", "2h ago", "Yesterday", then "12 Oct".
String memoryTimeLabel(DateTime createdAt, DateTime now) {
  final age = now.difference(createdAt);
  if (age.inMinutes < 1) return 'Just now';
  if (age.inHours < 1) return '${age.inMinutes}m ago';
  if (age.inHours < 24) return '${age.inHours}h ago';
  if (age.inHours < 48) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = createdAt.toLocal();
  return '${local.day} ${months[local.month - 1]}';
}

/// The Home circles row: circles with the newest Memories first, then the
/// remaining top-level groups. Quiet subgroups stay in Groups. [latest] is
/// each circle's newest Memory; a circle is fresh when someone else shared
/// after this person last opened it.
({
  List<({CircleGroup group, bool fresh})> ordered,
  Map<String, DateTime> latest,
})
homeCircles(CircleWorkspace workspace, CircleSeen? seen) {
  final latest = <String, DateTime>{};
  final latestFromOthers = <String, DateTime>{};
  for (final memory in workspace.memories) {
    final at = memory.createdAt;
    if (at.isAfter(latest[memory.groupId] ?? DateTime(0))) {
      latest[memory.groupId] = at;
    }
    if (memory.authorId != workspace.viewer &&
        at.isAfter(latestFromOthers[memory.groupId] ?? DateTime(0))) {
      latestFromOthers[memory.groupId] = at;
    }
  }
  final active = [
    for (final group in workspace.groups)
      if (latest.containsKey(group.id)) group,
  ]..sort((a, b) => latest[b.id]!.compareTo(latest[a.id]!));
  final ordered = [
    ...active,
    for (final entry in buildGroupTree(workspace.groups))
      if (!entry.group.isSubgroup && !latest.containsKey(entry.group.id))
        entry.group,
  ];
  return (
    ordered: [
      for (final group in ordered)
        (
          group: group,
          fresh:
              seen != null &&
              (latestFromOthers[group.id]?.isAfter(seen.seenAt(group.id)) ??
                  false),
        ),
    ],
    latest: latest,
  );
}

/// The empty Home: three first steps, each ticked once done.
class _FirstSteps extends StatelessWidget {
  const _FirstSteps({required this.workspace, required this.groupId});
  final CircleWorkspace workspace;
  final String? groupId;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasGroup = workspace.groups.isNotEmpty;
    final hasPeople = workspace.groups.any((group) => group.roles.length > 1);
    final firstGroup = hasGroup ? workspace.groups.first.id : null;
    Widget step(
      int number,
      String title,
      String message, {
      required bool done,
      required VoidCallback? onTap,
    }) => Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: done
            ? Icon(
                LucideIcons.circle_check_big,
                color: theme.colorScheme.primary,
              )
            : CircleInitialAvatar(
                name: '$number',
                size: CircleAvatarSize.small,
              ),
        title: Text(
          title,
          style: done
              ? theme.textTheme.titleMedium?.copyWith(
                  color: CircleAccents.of(context).caption,
                )
              : theme.textTheme.titleMedium,
        ),
        subtitle: Text(message),
        trailing: done || onTap == null
            ? null
            : const Icon(LucideIcons.chevron_right),
        onTap: done ? null : onTap,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CircleEmpty(
          title: hasGroup
              ? 'Every circle starts with a story'
              : 'A little space for your people',
          message: hasGroup
              ? 'Share the first Memory with this group.'
              : 'Create a group for family, friends or your team, or open an invite link. Nothing is shared until you choose a group.',
          action: FilledButton.icon(
            // Group creation lives in the Groups branch.
            onPressed: () => hasGroup
                ? context.push(composeLocation(groupId))
                : context.go('/groups/new'),
            icon: const Icon(LucideIcons.plus),
            label: Text(hasGroup ? 'Share a Memory' : 'Create a group'),
          ),
        ),
        const CircleSectionTitle('First steps'),
        step(
          1,
          'Create or join a circle',
          'Family, friends, your team or a club.',
          done: hasGroup,
          onTap: () => context.go('/groups/new'),
        ),
        step(
          2,
          'Invite your people',
          'Share a link or choose from your contacts.',
          done: hasPeople,
          onTap: firstGroup == null
              ? null
              : () => context.push('/groups/g/$firstGroup/invite'),
        ),
        step(
          3,
          'Share your first Memory',
          'A photo or a few words.',
          done: workspace.memories.isNotEmpty,
          onTap: hasGroup ? () => context.push(composeLocation(groupId)) : null,
        ),
      ],
    );
  }
}

/// Private photos from the loaded, authorized Memory timeline.
class CirclePhotos extends ConsumerWidget {
  const CirclePhotos({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => WorkspaceView(
    builder: (workspace) {
      final entries = [
        for (final memory in workspace.memories)
          for (var i = 0; i < memory.photos.length; i++)
            (memory: memory, index: i),
      ];
      return CustomScrollView(
        slivers: [
          if (entries.isEmpty)
            const SliverToBoxAdapter(
              child: CircleEmpty(
                title: 'No photos loaded yet',
                message: 'Photos shared with you appear here.',
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(Space.sm),
            sliver: SliverGrid.count(
              crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 3,
              mainAxisSpacing: Space.xs,
              crossAxisSpacing: Space.xs,
              children: [
                for (final entry in entries)
                  MemoryPhotoTile(
                    photo: entry.memory.photos[entry.index],
                    semanticsLabel: 'Photo from ${entry.memory.author}',
                    onTap: () => context.push(
                      photoViewerLocation(entry.memory.id, entry.index),
                    ),
                  ),
              ],
            ),
          ),
          if (workspace.hasMoreMemories)
            SliverToBoxAdapter(
              child: TextButton(
                onPressed: () => runCalmly(
                  context,
                  () => ref
                      .read(circleWorkspaceProvider.notifier)
                      .loadMoreMemories(),
                ),
                child: const Text('Load older photos'),
              ),
            ),
        ],
      );
    },
  );
}
