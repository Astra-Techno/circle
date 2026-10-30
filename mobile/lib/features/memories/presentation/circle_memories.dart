import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../groups/domain/group_tree.dart';
import '../../groups/presentation/group_photos.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/workspace_view.dart';
import '../application/circle_seen.dart';
import '../application/home_filter.dart';
import 'memory_card.dart';

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
      final seen = ref.watch(circleSeenProvider).value;
      final circles = homeCircles(workspace, seen);
      void select(String? id) {
        ref.read(homeGroupFilterProvider.notifier).select(id);
        final latest = id == null ? null : circles.latest[id];
        if (latest != null) {
          ref.read(circleSeenProvider.notifier).markSeen(id!, latest);
        }
      }

      final more = workspace.hasMoreMemories;
      return ReadingPane(
        child: RefreshIndicator(
          onRefresh: () => runCalmly(
            context,
            () => ref.read(circleWorkspaceProvider.notifier).refresh(),
          ),
          child: CustomScrollView(
            key: const PageStorageKey('circle-home'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Floating snap header: hides on scroll down, snaps back
              // instantly on any upward scroll (like Instagram).
              const CircleFloatingHeader(),
              SliverList.builder(
                // Memories run edge to edge: photos are full width and each
                // card pads its own text to the 24px editorial margin.
                itemCount: memories.length + 1 + (more ? 1 : 0),
                itemBuilder: (context, index) {
                  // Built only when scrolled near the end: loads older Memories.
                  if (index == memories.length + 1) {
                    return const _LoadOlderMemories();
                  }
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (workspace.groups.isNotEmpty) ...[
                          _CircleStories(
                            children: [
                              _CircleStory(
                                label: 'All',
                                selected: groupId == null,
                                onTap: () => select(null),
                                avatar: const CircleInitialAvatar(
                                  icon: Icons.blur_circular_outlined,
                                  tone: CircleTone.neutral,
                                  size: CircleAvatarSize.large,
                                ),
                              ),
                              for (final circle in circles.ordered)
                                _CircleStory(
                                  key: ValueKey(
                                    'home-circle-${circle.group.id}',
                                  ),
                                  label: circle.group.name,
                                  selected: groupId == circle.group.id,
                                  fresh: circle.fresh,
                                  onTap: () => select(
                                    groupId == circle.group.id
                                        ? null
                                        : circle.group.id,
                                  ),
                                  avatar: GroupAvatar(
                                    groupId: circle.group.id,
                                    type: circle.group.type,
                                    size: CircleAvatarSize.large,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: Space.sm),
                        ],
                        if (memories.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.section,
                            ),
                            child: _FirstSteps(
                              workspace: workspace,
                              groupId: groupId,
                            ),
                          ),
                      ],
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
      );
    },
  );
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

/// The "Your circles" row: round group photos, newest structure first.
/// Tapping one filters Memories to that group; tapping it again shows all.
class _CircleStories extends StatelessWidget {
  const _CircleStories({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Your circles',
    explicitChildNodes: true,
    // Edge to edge: the row scrolls under the page margin.
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const SizedBox(width: Space.sm),
            child,
          ],
        ],
      ),
    ),
  );
}

class _CircleStory extends StatelessWidget {
  const _CircleStory({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.avatar,
    this.fresh = false,
  });
  final String label;
  final bool selected;

  /// New Memories since this person last opened the circle: an indigo
  /// ring, like an unseen story.
  final bool fresh;
  final VoidCallback onTap;
  final Widget avatar;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: [
        selected ? '$label, showing' : 'Show $label',
        if (fresh) 'new Memories',
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CircleRadius.small),
        child: SizedBox(
          width: Space.hero * 2 + Space.sm,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Column(
              children: [
                // An indigo ring: new Memories, or the circle in view.
                Container(
                  padding: const EdgeInsets.all(Space.xs),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected || fresh
                          ? colors.primary
                          : CircleAccents.of(context).hairline,
                      width: fresh ? 3 : 2,
                    ),
                  ),
                  child: avatar,
                ),
                const SizedBox(height: Space.sm),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style:
                      (selected
                              ? theme.textTheme.labelMedium
                              : theme.textTheme.bodySmall)
                          ?.copyWith(
                            color: selected
                                ? colors.primary
                                : CircleAccents.of(context).caption,
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
    }) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: done
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : CircleInitialAvatar(name: '$number', size: CircleAvatarSize.small),
      title: Text(
        title,
        style: done
            ? theme.textTheme.titleMedium?.copyWith(
                color: CircleAccents.of(context).caption,
              )
            : theme.textTheme.titleMedium,
      ),
      subtitle: Text(message),
      trailing: done || onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: done ? null : onTap,
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
