import '../../profile/presentation/person_avatar.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/design/circle_typography.dart';
import '../../groups/domain/group_tree.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/workspace_view.dart';
import '../application/circle_seen.dart';
import '../application/home_filter.dart';
import 'memory_card.dart';
import 'memory_photos.dart';

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
        color: Theme.of(context).colorScheme.surface,
        child: ReadingPane(
          maxWidth: CircleLayout.homeComposerMaxWidth,
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
                    return CircleFadeIn(
                      key: ValueKey('fade-${memory.id}'),
                      delay:
                          CircleMotion.staggerDelay * ((index - 1).clamp(0, 5)),
                      child: CircleMemoryCard(
                        key: ValueKey(memory.id),
                        memory: memory,
                        group: group,
                        audience: audiencePath(group, workspace.groupsById),
                      ),
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

/// Selected Home concept: Floating 3D Glass Island with whisper prompt and tactile action tray.
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
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: CircleLayout.homeComposerMaxWidth,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (workspace.groups.isNotEmpty)
              Padding(
                // Full-width divider; content keeps the 16px margins.
                padding: const EdgeInsets.only(top: Space.xs),
                // Merged with the header (owner, 10 Nov 2026): no card of its
                // own; the prompt and tiles continue the header surface and a
                // divider separates them from the Memories.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: accents.hairline)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.md,
                          0,
                          Space.md,
                          Space.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Keepsake whisper prompt row: avatar + tactile capsule with sparkle
                            Row(
                              children: [
                                PersonAvatar(
                                  person: workspace.viewer,
                                  name: 'You',
                                  size: CircleAvatarSize.medium,
                                ),
                                const SizedBox(width: Space.sm),
                                Expanded(
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(
                                      CircleRadius.pill,
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(
                                        CircleRadius.pill,
                                      ),
                                      onTap: () => context.push(
                                        composeLocation(groupId),
                                      ),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minHeight: Space.large,
                                        ),
                                        child: Center(
                                          heightFactor: 1,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Ink(
                                              decoration: BoxDecoration(
                                                color: accents.recessed,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      CircleRadius.pill,
                                                    ),
                                                border: Border.all(
                                                  color: accents.hairline,
                                                ),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: Space.md,
                                                      vertical:
                                                          Space.sm + Space.xs,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Share a memory…',
                                                        maxLines:
                                                            MediaQuery.textScalerOf(
                                                                  context,
                                                                ).scale(1) <=
                                                                CircleLayout
                                                                    .largeTextThreshold
                                                            ? 1
                                                            : 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            CircleTextStyles.homeBody(
                                                              accents.caption,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: Space.xs,
                                                    ),
                                                    Icon(
                                                      CircleIcons.sparkles,
                                                      size:
                                                          CircleSizes.iconSmall,
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Space.sm),
                            // Icon-only flat bold action strip
                            _ActionIconStrip(
                              groupId: groupId,
                              features: features,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!hasMemories)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.section),
                child: _FirstSteps(workspace: workspace, groupId: groupId),
              ),
          ],
        ),
      ),
    );
  }
}

/// Flat bold icon-only action strip for the Home header.
/// Renders 34px [CircleActionIcon] tiles in 48px tap targets with dividers.
class _ActionIconStrip extends StatelessWidget {
  const _ActionIconStrip({required this.groupId, required this.features});
  final String? groupId;
  final CircleFeatures features;

  @override
  Widget build(BuildContext context) {
    final accents = CircleAccents.of(context);
    final items = <_ActionItem>[
      _ActionItem(
        type: CircleActionIconType.memory,
        tooltip: 'Photo',
        route: composeLocation(groupId),
      ),
      if (features.has(CircleFeature.liveEvents))
        _ActionItem(
          type: CircleActionIconType.event,
          tooltip: 'Event',
          route: groupId == null ? '/events/new' : '/events/new?group=$groupId',
        ),
      if (features.has(CircleFeature.livePolls))
        _ActionItem(
          type: CircleActionIconType.poll,
          tooltip: 'Poll',
          route: groupId == null ? '/polls/new' : '/polls/new?group=$groupId',
        ),
      // Capsules are phone-only until the server offers them: hidden.
      if (features.has(CircleFeature.capsules))
        _ActionItem(
          type: CircleActionIconType.capsule,
          tooltip: 'Capsule',
          route: groupId == null
              ? '/capsules/new'
              : '/capsules/new?group=$groupId',
        ),
    ];

    return SizedBox(
      height: CircleSizes.minTouchTarget,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: CircleMemoryLayout.dividerThickness * 4,
                height: CircleSizes.iconDefault,
                color: accents.hairline,
              ),
            Tooltip(
              message: items[i].tooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(CircleRadius.card),
                onTap: () => context.push(items[i].route),
                // 48px tap target around the 34px tile.
                child: SizedBox.square(
                  dimension: CircleSizes.minTouchTarget,
                  child: Center(child: CircleActionIcon(type: items[i].type)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.type,
    required this.tooltip,
    required this.route,
  });
  final CircleActionIconType type;
  final String tooltip;
  final String route;
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
              child: const SizedBox.square(
                dimension: Space.section,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CircleIcons.circleAlert,
                  size: CircleSizes.iconDefault,
                  color: CircleAccents.of(context).caption,
                ),
                const SizedBox(height: Space.sm),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CircleAccents.of(context).caption,
                  ),
                ),
                const SizedBox(height: Space.sm),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(CircleIcons.refreshCw),
                  label: const Text('Try again'),
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
            ? Icon(CircleIcons.circleCheckBig, color: theme.colorScheme.primary)
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
            : const Icon(CircleIcons.chevronRight),
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
            icon: const Icon(CircleIcons.create),
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
                icon: CircleIcons.photo,
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
