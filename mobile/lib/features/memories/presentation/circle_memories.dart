import 'dart:async';

import '../../events/presentation/event_visuals.dart';
import '../../groups/presentation/group_photos.dart';
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
        color: CirclePulsePalette.canvas(context),
        child: ReadingPane(
          color: CirclePulsePalette.canvas(context),
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
                        memories: memories,
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

/// Owner-approved Circle Pulse Home: a white social dashboard with real
/// Circles, creation actions, upcoming plans and active polls.
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({
    required this.workspace,
    required this.groupId,
    required this.memories,
    required this.features,
  });
  final CircleWorkspace workspace;
  final String? groupId;
  final List<CircleMemory> memories;
  final CircleFeatures features;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(circleClockProvider)();
    final account = ref.watch(serverAccountProvider);
    final upcoming = workspace.events
        .where(
          (event) =>
              (groupId == null || event.groupId == groupId) &&
              !event.cancelled &&
              event.endsOrStarts.isAfter(now.toUtc()),
        )
        .toList();
    final pollMemory = memories
        .where((memory) => memory.poll != null && !memory.poll!.closed)
        .firstOrNull;
    final people = {
      for (final group in workspace.groups)
        if (groupId == null || group.id == groupId)
          for (final person in group.roles.keys)
            if (person != workspace.viewer) person,
    }.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.sm,
        Space.md,
        Space.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              homeGreeting(now, account?.displayName ?? ''),
              style: CircleTextStyles.homeGreeting(
                Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'The people and moments that matter, all in one place.',
            style: CircleTextStyles.homeShortcut(
              CircleAccents.of(context).caption,
            ),
          ),
          if (workspace.groups.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            _HomeCircleSelector(workspace: workspace, groupId: groupId),
            const SizedBox(height: Space.sm),
            _HomeComposer(workspace: workspace, groupId: groupId),
            const SizedBox(height: Space.md),
            _CreatePanel(groupId: groupId, features: features),
            if (features.has(CircleFeature.liveEvents) && upcoming.isNotEmpty ||
                features.has(CircleFeature.livePolls) &&
                    pollMemory != null) ...[
              const SizedBox(height: Space.md),
              _HomePulseModules(
                event: features.has(CircleFeature.liveEvents)
                    ? upcoming.first
                    : null,
                pollMemory: features.has(CircleFeature.livePolls)
                    ? pollMemory
                    : null,
                workspace: workspace,
                now: now,
              ),
            ],
            if (people.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              _HomePeoplePanel(
                workspace: workspace,
                people: people,
                canChat: features.has(CircleFeature.liveChat),
              ),
            ],
          ],
          if (memories.isNotEmpty) ...[
            const SizedBox(height: Space.xl),
            const _HomeSectionTitle(title: 'Memories'),
          ] else
            _FirstSteps(workspace: workspace, groupId: groupId),
        ],
      ),
    );
  }
}

class _HomeCircleSelector extends ConsumerWidget {
  const _HomeCircleSelector({required this.workspace, required this.groupId});
  final CircleWorkspace workspace;
  final String? groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = homeCircles(workspace, ref.watch(circleSeenProvider).value);
    return SizedBox(
      height: CirclePulseLayout.circleSelectorHeight,
      child: ListView(
        key: const ValueKey('home-circle-selector'),
        scrollDirection: Axis.horizontal,
        children: [
          _HomeCircleChoice(
            label: 'All Circles',
            selected: groupId == null,
            avatar: const CircleInitialAvatar(
              icon: CircleIcons.layers,
              size: CircleAvatarSize.large,
            ),
            onTap: () =>
                ref.read(homeGroupFilterProvider.notifier).select(null),
          ),
          for (final entry in circles.ordered)
            _HomeCircleChoice(
              label: entry.group.name,
              selected: groupId == entry.group.id,
              fresh: entry.fresh,
              avatar: GroupAvatar(
                groupId: entry.group.id,
                type: entry.group.type,
                size: CircleAvatarSize.large,
              ),
              onTap: () {
                ref
                    .read(homeGroupFilterProvider.notifier)
                    .select(entry.group.id);
                final latest = circles.latest[entry.group.id];
                if (latest != null) {
                  unawaited(
                    ref
                        .read(circleSeenProvider.notifier)
                        .markSeen(entry.group.id, latest),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}

class _HomeCircleChoice extends StatelessWidget {
  const _HomeCircleChoice({
    required this.label,
    required this.selected,
    required this.avatar,
    required this.onTap,
    this.fresh = false,
  });
  final String label;
  final bool selected;
  final bool fresh;
  final Widget avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accents = CircleAccents.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(CircleRadius.card),
          onTap: onTap,
          child: SizedBox(
            width: CirclePulseLayout.circleItemWidth,
            child: Padding(
              padding: const EdgeInsets.all(Space.xs),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(
                                  color: colors.primary,
                                  width: CircleLayout.navigationRingWidth,
                                )
                              : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(Space.xs),
                          child: avatar,
                        ),
                      ),
                      if (fresh)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: Space.sm + Space.xs,
                            height: Space.sm + Space.xs,
                            decoration: BoxDecoration(
                              color: accents.activeDot,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.surface,
                                width: CircleLayout.navigationRingWidth,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    label,
                    maxLines:
                        MediaQuery.textScalerOf(context).scale(1) >=
                            CircleLayout.largeTextThreshold
                        ? 1
                        : 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: CircleTextStyles.homeCaption(
                      selected ? colors.primary : accents.caption,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeComposer extends StatelessWidget {
  const _HomeComposer({required this.workspace, required this.groupId});
  final CircleWorkspace workspace;
  final String? groupId;

  @override
  Widget build(BuildContext context) {
    const foreground = CircleOverlay.foreground;
    return Semantics(
      button: true,
      label: 'Share a memory',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(CircleRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(CircleRadius.card),
          onTap: () => context.push(composeLocation(groupId)),
          child: Ink(
            decoration: CirclePulsePalette.composer(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: CirclePulseLayout.composerMinHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(Space.md),
                child: Row(
                  children: [
                    PersonAvatar(
                      person: workspace.viewer,
                      name: 'You',
                      size: CircleAvatarSize.medium,
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share a memory…',
                            style: CircleTextStyles.homeComposer(foreground),
                          ),
                          const SizedBox(height: Space.xs),
                          Text(
                            'A photo, a thought, a moment.',
                            style: CircleTextStyles.homeCaption(foreground),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    const Icon(
                      CircleIcons.create,
                      color: foreground,
                      size: CircleSizes.iconCreate,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatePanel extends StatelessWidget {
  const _CreatePanel({required this.groupId, required this.features});
  final String? groupId;
  final CircleFeatures features;

  @override
  Widget build(BuildContext context) {
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
      if (features.has(CircleFeature.capsules))
        _ActionItem(
          type: CircleActionIconType.capsule,
          tooltip: 'Capsule',
          route: groupId == null
              ? '/capsules/new'
              : '/capsules/new?group=$groupId',
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: CirclePulsePalette.surface(context),
        borderRadius: BorderRadius.circular(CircleRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _HomeSectionTitle(title: 'Create something'),
          const SizedBox(height: Space.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - Space.sm) / 2;
              return Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: width,
                      child: _PulseCreateAction(item: item),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PulseCreateAction extends StatelessWidget {
  const _PulseCreateAction({required this.item});
  final _ActionItem item;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.tooltip,
      child: Material(
        color: CirclePulsePalette.raisedSurface(context),
        borderRadius: BorderRadius.circular(CircleRadius.tile),
        child: InkWell(
          borderRadius: BorderRadius.circular(CircleRadius.tile),
          onTap: () => context.push(item.route),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: CirclePulseLayout.createActionMinHeight,
              minWidth: CircleSizes.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleActionIcon(
                    type: item.type,
                    size: CircleLayout.quickActionPaint,
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    item.tooltip,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: CircleTextStyles.homeShortcut(
                      Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePulseModules extends StatelessWidget {
  const _HomePulseModules({
    required this.event,
    required this.pollMemory,
    required this.workspace,
    required this.now,
  });
  final CircleEvent? event;
  final CircleMemory? pollMemory;
  final CircleWorkspace workspace;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final stack =
        MediaQuery.textScalerOf(context).scale(1) >=
            CircleLayout.largeTextThreshold ||
        MediaQuery.sizeOf(context).width <
            CirclePulseLayout.dashboardBreakpoint;
    final children = [
      if (event != null)
        _UpcomingEventCard(event: event!, workspace: workspace, now: now),
      if (pollMemory?.poll != null)
        _HomePollCard(memory: pollMemory!, poll: pollMemory!.poll!),
    ];
    if (stack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: Space.sm),
            children[i],
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: Space.sm),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

class _UpcomingEventCard extends StatelessWidget {
  const _UpcomingEventCard({
    required this.event,
    required this.workspace,
    required this.now,
  });
  final CircleEvent event;
  final CircleWorkspace workspace;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    const ink = CirclePulsePalette.eventText;
    const muted = CirclePulsePalette.eventMuted;
    return Semantics(
      button: true,
      label: 'Upcoming event: ${event.title}',
      child: Material(
        color: CirclePulsePalette.event,
        borderRadius: BorderRadius.circular(CircleRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(CircleRadius.card),
          onTap: () => context.push('/events/e/${event.id}'),
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleActionIcon(
                  type: CircleActionIconType.event,
                  tinted: true,
                  accent: ink,
                  size: CircleLayout.quickActionPaint,
                ),
                const SizedBox(height: Space.md),
                Text(
                  'UPCOMING EVENT',
                  style: CircleTextStyles.homeCaption(muted),
                ),
                const SizedBox(height: Space.xs),
                Text(event.title, style: CircleTextStyles.homeAuthor(ink)),
                const SizedBox(height: Space.sm),
                Text(
                  eventWhenLabel(event, now),
                  style: CircleTextStyles.homeCaption(muted),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  workspace.group(event.groupId)?.name ?? '',
                  style: CircleTextStyles.homeCaption(muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePollCard extends StatelessWidget {
  const _HomePollCard({required this.memory, required this.poll});
  final CircleMemory memory;
  final PollView poll;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Open poll: ${poll.question}',
      child: Material(
        color: CirclePulsePalette.raisedSurface(context),
        borderRadius: BorderRadius.circular(CircleRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(CircleRadius.card),
          onTap: () => context.push('/home/memory/${memory.id}'),
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const CircleActionIcon(
                      type: CircleActionIconType.poll,
                      tinted: true,
                      size: CircleLayout.quickActionPaint,
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        'LIVE POLL',
                        style: CircleTextStyles.homeCaption(colors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                Text(
                  poll.question,
                  style: CircleTextStyles.homeAuthor(colors.onSurface),
                ),
                const SizedBox(height: Space.sm),
                for (final option in poll.options.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: CircleTextStyles.homeCaption(
                                  colors.onSurface,
                                ),
                              ),
                            ),
                            if (option.percent != null)
                              Text(
                                '${option.percent}%',
                                style: CircleTextStyles.homeCaption(
                                  colors.primary,
                                ),
                              ),
                          ],
                        ),
                        if (option.percent != null) ...[
                          const SizedBox(height: Space.xs),
                          LinearProgressIndicator(
                            value: option.percent! / 100,
                            minHeight: CirclePulseLayout.pollProgressHeight,
                            color: colors.primary,
                            backgroundColor: colors.surface,
                          ),
                        ],
                      ],
                    ),
                  ),
                Text(
                  '${poll.totalVoters} ${poll.totalVoters == 1 ? 'vote' : 'votes'}',
                  style: CircleTextStyles.homeCaption(
                    CircleAccents.of(context).caption,
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

class _HomePeoplePanel extends StatelessWidget {
  const _HomePeoplePanel({
    required this.workspace,
    required this.people,
    required this.canChat,
  });
  final CircleWorkspace workspace;
  final List<String> people;
  final bool canChat;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: CirclePulsePalette.surface(context),
      borderRadius: BorderRadius.circular(CircleRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(CircleRadius.card),
        onTap: () => context.go(canChat ? '/chats' : '/groups'),
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your people are here',
                    style: CircleTextStyles.homeAuthor(colors.onSurface),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    '${people.length} ${people.length == 1 ? 'person shares' : 'people share'} your Circles',
                    style: CircleTextStyles.homeCaption(
                      CircleAccents.of(context).caption,
                    ),
                  ),
                ],
              );
              final avatars = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final person in people.take(4))
                    Padding(
                      padding: const EdgeInsets.only(left: Space.xs),
                      child: PersonAvatar(
                        person: person,
                        name: workspace.nameOf(person),
                        size: CircleAvatarSize.small,
                      ),
                    ),
                  const SizedBox(width: Space.xs),
                  Icon(CircleIcons.chevronRight, color: colors.primary),
                ],
              );
              final stack =
                  constraints.maxWidth <
                      CirclePulseLayout.dashboardBreakpoint ||
                  MediaQuery.textScalerOf(context).scale(1) >=
                      CircleLayout.largeTextThreshold;
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    copy,
                    const SizedBox(height: Space.sm),
                    avatars,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: copy),
                  avatars,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      title,
      style: CircleTextStyles.homeSectionTitle(
        Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
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

/// A local-time greeting with the signed-in person's first name when known.
String homeGreeting(DateTime now, String displayName) {
  final greeting = switch (now.hour) {
    < 12 => 'Good morning',
    < 17 => 'Good afternoon',
    _ => 'Good evening',
  };
  final firstName = displayName.trim().split(RegExp(r'\s+')).first;
  return firstName.isEmpty || firstName == 'You'
      ? greeting
      : '$greeting, $firstName';
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
