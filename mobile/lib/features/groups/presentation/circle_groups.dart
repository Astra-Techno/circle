import '../../../core/form_exit_guard.dart';
import 'group_photos.dart';
import 'contact_invitation_entry.dart';
import '../application/group_photos.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/design/circle_typography.dart';
import '../../../core/two_pane.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/group_visuals.dart';
import '../../workspace/presentation/workspace_view.dart';
import '../../profile/presentation/person_avatar.dart';
import '../domain/group_tree.dart';
import '../domain/membership_rules.dart';

/// Indentation steps stop growing after this many levels; deeper levels
/// stay distinguishable through the "Level n · in Parent" hint.

/// Tight overlapping avatar stack dimensions.
const _avatarDiameter = 28.0, _avatarOverlap = 20.0;

/// Filter for the Circles list.
enum _CircleFilter { all, joined, invited }

class CircleGroups extends ConsumerStatefulWidget {
  const CircleGroups({super.key});
  @override
  ConsumerState<CircleGroups> createState() => _CircleGroupsState();
}

class _CircleGroupsState extends ConsumerState<CircleGroups> {
  _CircleFilter _filter = _CircleFilter.all;
  String _query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      final theme = Theme.of(context);
      final accents = CircleAccents.of(context);
      Widget filterChip(_CircleFilter filter) => _FilterChip(
        label: switch (filter) {
          _CircleFilter.all => 'All',
          _CircleFilter.joined => 'Joined',
          _CircleFilter.invited => 'Invited',
        },
        selected: _filter == filter,
        onTap: () => setState(() => _filter = filter),
      );

      // Build group entries based on filter.
      List<GroupTreeEntry> entries;
      switch (_filter) {
        case _CircleFilter.all:
          entries = buildGroupTree(workspace.groups, collapsed: _collapsed);
        case _CircleFilter.joined:
          entries = buildGroupTree(workspace.groups, collapsed: _collapsed);
        case _CircleFilter.invited:
          entries = const [];
      }

      if (_query.isNotEmpty && _filter != _CircleFilter.invited) {
        entries = buildGroupTree(
          workspace.groups,
        ).where((e) => e.group.name.toLowerCase().contains(_query)).toList();
      }
      // Derive latest activity per group from memories and events.
      final activityMap = <String, _GroupActivity>{};
      for (final memory in workspace.memories) {
        final existing = activityMap[memory.groupId];
        if (existing == null || memory.createdAt.isAfter(existing.time)) {
          final hasPhotos = memory.photos.isNotEmpty;
          activityMap[memory.groupId] = _GroupActivity(
            icon: hasPhotos ? CircleIcons.images : CircleIcons.chat,
            text:
                '${workspace.nameOf(memory.authorId)} ${hasPhotos ? 'shared ${memory.photos.length == 1 ? 'a photo' : '${memory.photos.length} photos'}' : 'posted a memory'}',
            time: memory.createdAt,
          );
        }
      }
      for (final event in workspace.events) {
        final existing = activityMap[event.groupId];
        if (existing == null || event.createdAt.isAfter(existing.time)) {
          activityMap[event.groupId] = _GroupActivity(
            icon: CircleIcons.calendar,
            text: event.title,
            time: event.createdAt,
          );
        }
      }

      // Count events per group.
      final eventCounts = <String, int>{};
      final now = DateTime.now();
      for (final event in workspace.events) {
        if (!event.cancelled && event.startsAt.isAfter(now)) {
          eventCounts[event.groupId] = (eventCounts[event.groupId] ?? 0) + 1;
        }
      }

      return ReadingPane(
        child: CustomScrollView(
          slivers: [
            const CircleCollapsingHeader(),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: Space.sm),
                child: ContactInvitationEntry(),
              ),
            ),
            SliverPadding(
              padding: CircleInsets.content,
              sliver: SliverList.list(
                children: [
                  if (workspace.groups.isNotEmpty)
                    CircleSearchField(
                      controller: _search,
                      label: 'Search Circles',
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                    ),
                  // Filter chips — full width, evenly spaced.
                  Padding(
                    padding: const EdgeInsets.only(
                      top: Space.md,
                      bottom: Space.md,
                    ),
                    child:
                        MediaQuery.textScalerOf(context).scale(1) >
                            CircleLayout.largeTextThreshold
                        ? Wrap(
                            spacing: Space.sm,
                            runSpacing: Space.sm,
                            children: [
                              for (final filter in _CircleFilter.values)
                                filterChip(filter),
                            ],
                          )
                        : Row(
                            children: [
                              for (final filter in _CircleFilter.values) ...[
                                if (filter != _CircleFilter.all)
                                  const SizedBox(width: Space.sm),
                                Expanded(child: filterChip(filter)),
                              ],
                            ],
                          ),
                  ),
                  if (_filter == _CircleFilter.invited) ...[
                    if (workspace.invitations.isEmpty)
                      CircleEmpty(
                        icon: CircleIcons.members,
                        title: 'No invitations',
                        message:
                            'Invitations from your circles will appear here.',
                      ),
                    for (final inv in workspace.invitations)
                      CircleRow(
                        child: ListTile(
                          leading: CircleInitialAvatar(
                            icon: circleTypeIcon(inv.groupType),
                            tone: circleTypeTone(inv.groupType),
                          ),
                          title: Text(inv.groupName),
                          subtitle: Text('${inv.inviterName} invited you'),
                          trailing: const Icon(CircleIcons.chevronRight),
                          onTap: () => context.push(
                            '/groups/g/${inv.invitation.groupId}',
                          ),
                        ),
                      ),
                  ],
                  if (_filter != _CircleFilter.invited) ...[
                    if (entries.isEmpty)
                      CircleEmpty(
                        title: workspace.groups.isEmpty
                            ? 'Start with someone you know'
                            : 'No Circles found',
                        message: workspace.groups.isEmpty
                            ? 'Create your first Circle, or use an invitation someone shared with you.'
                            : 'Try a different Circle name.',
                        action: workspace.groups.isEmpty
                            ? FilledButton(
                                onPressed: () => context.push('/groups/new'),
                                child: const Text('Create a Circle'),
                              )
                            : null,
                      ),
                    // Pinned & All Circles sections
                    if (entries.isNotEmpty) ...[
                      if (_query.isEmpty &&
                          _filter == _CircleFilter.all &&
                          entries.where((e) => e.level == 0).length >= 2) ...[
                        Builder(
                          builder: (context) {
                            final topLevel = entries
                                .where((e) => e.level == 0)
                                .take(2)
                                .toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: Space.sm,
                                    bottom: Space.sm,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        CircleIcons.pin,
                                        size: Space.md,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: Space.xs),
                                      Expanded(
                                        child: Text(
                                          'Pinned Circles',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              CircleTextStyles.sectionTitle(
                                                theme.colorScheme.onSurface,
                                              ).copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: Space.xs),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: Space.contentInset,
                                          vertical: Space.xs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accents.recessed,
                                          borderRadius: BorderRadius.circular(
                                            CircleRadius.pill,
                                          ),
                                        ),
                                        child: Text(
                                          'Edit',
                                          style:
                                              CircleTextStyles.caption(
                                                theme.colorScheme.primary,
                                              ).copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                for (final entry in topLevel)
                                  _CircleCard(
                                    group: entry.group,
                                    workspace: workspace,
                                    level: entry.level,
                                    isPinned: true,
                                    activity: activityMap[entry.group.id],
                                    eventCount:
                                        eventCounts[entry.group.id] ?? 0,
                                    notificationCount: _notificationCount(
                                      workspace,
                                      entry.group.id,
                                    ),
                                  ),
                                const SizedBox(height: Space.md),
                              ],
                            );
                          },
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(
                          top: Space.sm,
                          bottom: Space.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'All Circles',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CircleTextStyles.sectionTitle(
                                  theme.colorScheme.onSurface,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: Space.xs),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Sort by',
                                  style: CircleTextStyles.metadata(
                                    accents.caption,
                                  ),
                                ),
                                const SizedBox(width: Space.xs),
                                Icon(
                                  CircleIcons.chevronDown,
                                  size: 14,
                                  color: accents.caption,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    for (final entry in entries) ...[
                      if (_query.isNotEmpty && entry.path.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: Space.xs,
                            left: Space.sm,
                          ),
                          child: Text(
                            entry.path.join(' › '),
                            style: CircleTextStyles.metadata(accents.caption),
                          ),
                        ),
                      _CircleCard(
                        group: entry.group,
                        workspace: workspace,
                        level: entry.level,
                        activity: activityMap[entry.group.id],
                        eventCount: eventCounts[entry.group.id] ?? 0,
                        notificationCount: _notificationCount(
                          workspace,
                          entry.group.id,
                        ),
                        expanded: !entry.hasChildren ? null : entry.expanded,
                        onToggle: () => setState(() {
                          if (!_collapsed.remove(entry.group.id)) {
                            _collapsed.add(entry.group.id);
                          }
                        }),
                      ),
                    ],
                    if (workspace.pending.isNotEmpty) ...[
                      const SizedBox(height: Space.lg),
                      const CircleSectionTitle('Waiting for approval'),
                      for (final pending in workspace.pending)
                        CircleRow(
                          child: ListTile(
                            leading: const CircleInitialAvatar(
                              icon: CircleIcons.hourglass,
                              tone: CircleTone.neutral,
                            ),
                            title: Text(pending.name),
                            subtitle: const Text('Waiting for approval'),
                            trailing: const Icon(CircleIcons.chevronRight),
                            onTap: () =>
                                context.push('/groups/g/${pending.groupId}'),
                          ),
                        ),
                    ],
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

/// Pill-shaped filter chip: filled when selected, outlined when not.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: accents.recessed,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CircleRadius.pill),
        side: BorderSide.none,
      ),
      labelStyle: CircleTextStyles.label(
        selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurfaceVariant,
      ).copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
    );
  }
}

/// Number of loaded Memories in this exact circle.
int _notificationCount(CircleWorkspace workspace, String groupId) {
  var count = 0;
  for (final memory in workspace.memories) {
    if (memory.groupId == groupId) count++;
  }
  return count;
}

class _GroupActivity {
  const _GroupActivity({
    required this.icon,
    required this.text,
    required this.time,
  });
  final IconData icon;
  final String text;
  final DateTime time;
}

/// Compact circle row: cover photo, info column with inline stats + activity,
/// and a right-side chevron or collapse/expand control.
class _CircleCard extends ConsumerWidget {
  const _CircleCard({
    required this.group,
    required this.workspace,
    this.level = 0,
    this.isPinned = false,
    this.activity,
    this.eventCount = 0,
    this.notificationCount = 0,
    this.expanded,
    this.onToggle,
  });
  final CircleGroup group;
  final CircleWorkspace workspace;
  final int level;
  final bool isPinned;
  final _GroupActivity? activity;
  final int eventCount;
  final int notificationCount;
  final bool? expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = Theme.of(context);
      final accents = CircleAccents.of(context);
      final compact = CircleLayout.stackDetails(context, constraints.maxWidth);
      final indent = CircleLayout.treeIndent(
        context,
        constraints.maxWidth,
        level,
      );
      final memberCount = group.roles.length;
      final memberIds = group.roles.keys.toList();
      final visibleAvatars = memberIds.take(3).toList();
      final remaining = memberCount - visibleAvatars.length;

      // Inline stats: "12 members · 2 events"
      final stats = StringBuffer(
        '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
      );
      if (eventCount > 0) {
        stats.write(' · $eventCount ${eventCount == 1 ? 'event' : 'events'}');
      }

      return Padding(
        padding: EdgeInsetsDirectional.only(start: indent),
        child: Semantics(
          button: true,
          label: group.name,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: accents.hairline, width: 0.5),
              ),
            ),
            child: InkWell(
              onTap: () {
                if (!CirclePaneScope.select(context, 'groups', group.id)) {
                  context.push('/groups/g/${group.id}');
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.sm,
                  vertical: Space.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Cover photo — landscape rounded rectangle.
                    if (!compact) ...[
                      _GroupCoverPhoto(
                        groupId: group.id,
                        type: group.type,
                        width: 104.0,
                        height: 76.0,
                      ),
                      const SizedBox(width: Space.md),
                    ],
                    // Info column.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Name + pin icon.
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  group.name,
                                  maxLines: compact ? null : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: CircleTextStyles.cardTitle(
                                    theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (isPinned) ...[
                                const SizedBox(width: Space.xs),
                                Icon(
                                  CircleIcons.pin,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          // Member count + event count inline.
                          Text(
                            stats.toString(),
                            style: CircleTextStyles.metadata(accents.caption),
                          ),
                          const SizedBox(height: Space.xs),
                          // Avatar stack row.
                          Row(
                            children: [
                              SizedBox(
                                width:
                                    visibleAvatars.length * _avatarOverlap +
                                    (_avatarDiameter - _avatarOverlap),
                                height: _avatarDiameter,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    for (
                                      var i = 0;
                                      i < visibleAvatars.length;
                                      i++
                                    )
                                      Positioned(
                                        left: i * _avatarOverlap,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: theme.colorScheme.surface,
                                              width: 2,
                                            ),
                                          ),
                                          child: PersonAvatar(
                                            person: visibleAvatars[i],
                                            name: workspace.nameOf(
                                              visibleAvatars[i],
                                            ),
                                            size: CircleAvatarSize.small,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (remaining > 0) ...[
                                const SizedBox(width: Space.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Space.xs,
                                  ),
                                  height: _avatarDiameter,
                                  decoration: BoxDecoration(
                                    color: accents.recessed,
                                    borderRadius: BorderRadius.circular(
                                      CircleRadius.pill,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '+$remaining',
                                    style: CircleTextStyles.caption(
                                      accents.caption,
                                    ).copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // Activity line: "text · 2h ago"
                          if (activity != null) ...[
                            const SizedBox(height: Space.xs),
                            Row(
                              children: [
                                Icon(
                                  activity!.icon,
                                  size: CircleSizes.iconInline,
                                  color: accents.caption,
                                ),
                                const SizedBox(width: Space.xs),
                                Expanded(
                                  child: Text(
                                    '${activity!.text} · ${circleTimeAgo(activity!.time)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: CircleTextStyles.metadata(
                                      accents.caption,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    // Trailing badges + chevron / collapse control.
                    if (notificationCount > 0) ...[
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        padding: const EdgeInsets.all(Space.xs),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$notificationCount',
                          style: CircleTextStyles.caption(
                            theme.colorScheme.onPrimary,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: Space.xs),
                    ] else if (eventCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.sm,
                          vertical: Space.xs,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(
                            CircleRadius.pill,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CircleIcons.calendar,
                              size: 13,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: Space.xs),
                            Text(
                              '$eventCount ${eventCount == 1 ? 'event' : 'events'}',
                              style: CircleTextStyles.caption(
                                theme.colorScheme.error,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.xs),
                    ],
                    // Right side: collapse/expand or nav chevron.
                    if (expanded != null)
                      Tooltip(
                        message:
                            '${expanded! ? 'Collapse' : 'Expand'} ${group.name}',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            CircleRadius.pill,
                          ),
                          onTap: onToggle,
                          child: SizedBox(
                            width: CircleSizes.minTouchTarget,
                            height: CircleSizes.minTouchTarget,
                            child: Center(
                              child: AnimatedRotation(
                                turns: expanded! ? 0.5 : 0,
                                duration: CircleMotion.micro,
                                curve: CircleMotion.enterCurve,
                                child: Icon(
                                  CircleIcons.chevronDown,
                                  size: Space.section,
                                  color: accents.caption,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Icon(
                        CircleIcons.chevronRight,
                        size: Space.section,
                        color: accents.caption,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Rounded rectangle cover photo for a group.
class _GroupCoverPhoto extends ConsumerWidget {
  const _GroupCoverPhoto({
    required this.groupId,
    required this.type,
    this.width = 104.0,
    this.height = 76.0,
  });
  final String groupId;
  final CircleType type;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(circleWorkspaceProvider).value;
    final group = workspace?.group(groupId);
    final coverVersion = group?.coverVersion;
    ImageProvider<Object>? image;
    if (coverVersion != null) {
      final bytes = ref
          .watch(
            (CirclePhotoMetrics.coverThumbnailFits(
                  MediaQuery.devicePixelRatioOf(context),
                )
                ? groupPhotoPreviewBytesProvider
                : groupPhotoBytesProvider)((
              group: groupId,
              kind: ProfilePhotoKind.cover,
              version: coverVersion,
            )),
          )
          .value;
      if (bytes != null) image = MemoryImage(bytes);
    }

    final accents = CircleAccents.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(CircleRadius.card),
      child: SizedBox(
        width: width,
        height: height,
        child: image != null
            ? Semantics(
                label: 'Cover photo',
                child: Image(image: image, fit: BoxFit.cover),
              )
            : Container(
                color: accents.recessed,
                alignment: Alignment.center,
                child: GroupAvatar(
                  groupId: groupId,
                  type: type,
                  size: CircleAvatarSize.medium,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CircleGroupTile is kept for backward compatibility with tests/detail pages.
// ─────────────────────────────────────────────────────────────────────────────

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
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final viewer = ref.watch(circleViewerProvider);
      final role = group.roles[viewer];
      final compact = CircleLayout.stackDetails(context, constraints.maxWidth);
      final indent = CircleLayout.treeIndent(
        context,
        constraints.maxWidth,
        level,
      );
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
                      if (!compact) ...[
                        GroupAvatar(
                          groupId: group.id,
                          type: group.type,
                          size: avatar,
                        ),
                        const SizedBox(width: Space.md),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              maxLines: compact ? null : 2,
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
                            CircleIcons.chevronRight,
                            color: accents.caption,
                          ),
                        )
                      else
                        IconButton(
                          tooltip: expanded!
                              ? 'Collapse ${group.name}'
                              : 'Expand ${group.name}',
                          icon: Icon(
                            expanded!
                                ? CircleIcons.chevronUp
                                : CircleIcons.chevronDown,
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
    },
  );
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
                  icon: CircleIcons.members,
                  title: 'A subgroup can\'t be added here',
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
          child: CircleEditorLayout(
            children: [
              CircleHeading(
                title: parent == null
                    ? 'Bring your\npeople together.'
                    : 'Make a little\nroom within.',
                subtitle: parent == null
                    ? 'A private Circle, with you as its owner.'
                    : 'A private InCircle within ${parent.name}. Only its members can join.',
              ),
              CircleFieldLabel(
                label: 'Circle name',
                child: TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    hintText: 'Something your people will recognise',
                    errorText: _error,
                    errorMaxLines: 4,
                  ),
                  buildCounter: CircleFormMetrics.counter,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(height: Space.section),
              CircleFieldLabel(
                label: 'Circle type',
                child: DropdownButtonFormField<CircleType>(
                  initialValue: _type,
                  decoration: const InputDecoration(),
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
                      ? 'Creating\u2026'
                      : parent == null
                      ? 'Create Circle'
                      : 'Create InCircle',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
