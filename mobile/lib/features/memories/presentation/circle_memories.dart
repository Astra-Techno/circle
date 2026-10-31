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

      // Build unified feed: memories interspersed with events and polls.
      final events = features.has(CircleFeature.liveEvents)
          ? workspace.events
          : <CircleEvent>[];
      final feedItems = <_FeedItem>[
        for (final memory in memories)
          _FeedItem(
            type: _FeedType.memory,
            createdAt: memory.createdAt,
            memory: memory,
          ),
        for (final event in events)
          _FeedItem(
            type: _FeedType.event,
            createdAt: event.createdAt,
            event: event,
          ),
      ];
      feedItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
                  itemCount: feedItems.length + 1 + (more ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == feedItems.length + 1) {
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
                    final item = feedItems[index - 1];
                    switch (item.type) {
                      case _FeedType.memory:
                        final memory = item.memory!;
                        final group = workspace.group(memory.groupId)!;
                        return CircleMemoryCard(
                          key: ValueKey(memory.id),
                          memory: memory,
                          group: group,
                          audience: audiencePath(group, workspace.groupsById),
                        );
                      case _FeedType.event:
                        final event = item.event!;
                        final group = workspace.group(event.groupId);
                        if (group == null) return const SizedBox.shrink();
                        return EventFeedCard(
                          key: ValueKey('event-${event.id}'),
                          event: event,
                          group: group,
                          workspace: workspace,
                        );
                    }
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

enum _FeedType { memory, event }

class _FeedItem {
  const _FeedItem({
    required this.type,
    required this.createdAt,
    this.memory,
    this.event,
  });
  final _FeedType type;
  final DateTime createdAt;
  final CircleMemory? memory;
  final CircleEvent? event;
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
    return Column(
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
                    borderRadius: BorderRadius.circular(CircleRadius.button),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(CircleRadius.button),
                      onTap: () => context.push(composeLocation(groupId)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.md,
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
          // Four quick-action tiles.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.md,
              Space.xs,
              Space.md,
              Space.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.photo_library_outlined,
                    label: 'Photo',
                    color: theme.colorScheme.primary,
                    bgColor: theme.colorScheme.primaryContainer,
                    onTap: () => context.push(composeLocation(groupId)),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.videocam_outlined,
                    label: 'Video',
                    color: accents.video,
                    bgColor: accents.videoContainer,
                    onTap: () => context.push(composeLocation(groupId)),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.event_outlined,
                    label: 'Event',
                    color: accents.sage,
                    bgColor: accents.sageContainer,
                    onTap: features.has(CircleFeature.liveEvents)
                        ? () => context.push('/events/new')
                        : null,
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.format_list_bulleted_rounded,
                    label: 'Poll',
                    color: accents.amber,
                    bgColor: accents.amberContainer,
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
    );
  }
}

/// Rounded pastel tile: icon + label.
class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color, bgColor;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(CircleRadius.tile),
        child: InkWell(
          borderRadius: BorderRadius.circular(CircleRadius.tile),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: Space.xs),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
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

/// Event as a feed card in the unified Home timeline.
class EventFeedCard extends StatelessWidget {
  const EventFeedCard({
    super.key,
    required this.event,
    required this.group,
    required this.workspace,
  });
  final CircleEvent event;
  final CircleGroup group;
  final CircleWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    final colors = theme.colorScheme;
    final creatorName = workspace.nameOf(event.createdBy);
    final now = DateTime.now();
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final local = event.startsAt.toLocal();
    final dayLabel = days[local.weekday - 1];
    final dayNum = '${local.day}';
    final monthLabel = months[local.month - 1];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final timeLabel =
        '${dayLabel.substring(0, 3)}, ${local.day} ${months[local.month - 1]} · $hour:${local.minute.toString().padLeft(2, '0')} ${local.hour >= 12 ? 'PM' : 'AM'}';

    // RSVP counts.
    final rsvps = event.rsvps;
    final going = rsvps.values
        .where((r) => r.status == Attendance.going)
        .length;
    final maybe = rsvps.values
        .where((r) => r.status == Attendance.maybe)
        .length;
    final myRsvp = rsvps[workspace.viewer];

    return Padding(
      padding: const EdgeInsets.all(Space.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(CircleRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Author row.
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Space.section,
                0,
                Space.sm,
                Space.sm,
              ),
              child: Row(
                children: [
                  PersonAvatar(person: event.createdBy, name: creatorName),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: creatorName,
                                style: theme.textTheme.titleMedium,
                              ),
                              TextSpan(
                                text: ' created an event',
                                style: theme.textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${group.name} · ${memoryTimeLabel(event.editedAt ?? now, now)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: accents.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_horiz, color: accents.caption),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            // Event preview card.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Material(
                color: accents.recessed,
                borderRadius: BorderRadius.circular(CircleRadius.tile),
                child: InkWell(
                  borderRadius: BorderRadius.circular(CircleRadius.tile),
                  onTap: () => context.push('/events/e/${event.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: Row(
                      children: [
                        // Date block.
                        SizedBox(
                          width: 56,
                          child: Column(
                            children: [
                              Text(
                                dayLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                dayNum,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: accents.title,
                                ),
                              ),
                              Text(
                                monthLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: accents.caption,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        // Title + details.
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: theme.textTheme.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (event.venue != null) ...[
                                const SizedBox(height: Space.xs),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: accents.caption,
                                    ),
                                    const SizedBox(width: Space.xs),
                                    Expanded(
                                      child: Text(
                                        event.venue!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: accents.caption),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              ...[
                                const SizedBox(height: Space.xs),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: accents.caption,
                                    ),
                                    const SizedBox(width: Space.xs),
                                    Expanded(
                                      child: Text(
                                        timeLabel,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: accents.caption),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Attendees + RSVP.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.section,
                Space.sm,
                Space.section,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        if (going > 0) '$going going',
                        if (maybe > 0) '$maybe maybe',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: accents.caption,
                      ),
                    ),
                  ),
                  if (myRsvp != null)
                    Chip(
                      avatar: Icon(
                        Icons.check_circle,
                        size: 16,
                        color: colors.primary,
                      ),
                      label: Text(
                        myRsvp.status == Attendance.going
                            ? 'Going'
                            : myRsvp.status == Attendance.maybe
                            ? 'Interested'
                            : 'Not going',
                      ),
                      side: BorderSide.none,
                      backgroundColor: accents.recessed,
                      labelStyle: theme.textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ),
            const Divider(indent: Space.md, endIndent: Space.md),
            // Icon-only actions.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  tooltip: 'Love',
                  icon: const Icon(Icons.favorite_border_rounded),
                  onPressed: () {},
                ),
                IconButton(
                  tooltip: 'Comment',
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  onPressed: () => context.push('/events/e/${event.id}'),
                ),
                IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {},
                ),
                IconButton(
                  tooltip: 'Save',
                  icon: const Icon(Icons.bookmark_border_rounded),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The end of a paginated list: fetches the next page as soon as it comes
/// into view, with a calm Try again if that fails.
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
            ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
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
            : const Icon(Icons.chevron_right),
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
            icon: const Icon(Icons.add),
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
