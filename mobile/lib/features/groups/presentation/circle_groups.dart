import '../../../core/form_exit_guard.dart';
import 'group_photos.dart';
import 'invite_link_screen.dart';
import 'contact_invitation_entry.dart';
import '../application/group_photos.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/design/circle_icons.dart';
import '../../../core/design/circle_typography.dart';
import '../../../core/two_pane.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/group_visuals.dart';
import '../../workspace/presentation/workspace_view.dart';
import '../../profile/presentation/person_avatar.dart';
import '../domain/group_tree.dart';
import '../domain/membership_rules.dart';

/// Indentation steps stop growing after this many levels; deeper levels
/// stay distinguishable through the "Level n · in Parent" hint.
const _indentStep = Space.section, _indentLevels = 4;

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
            icon: hasPhotos ? LucideIcons.images : LucideIcons.message_circle,
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
            icon: LucideIcons.calendar,
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
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              sliver: SliverList.list(
                children: [
                  const ContactInvitationEntry(),
                  TextButton.icon(
                    onPressed: () => openInviteLinkDialog(context, ref),
                    icon: const Icon(LucideIcons.link),
                    label: const Text('Open an invite link'),
                  ),
                  if (workspace.groups.isNotEmpty)
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search groups',
                        prefixIcon: Icon(LucideIcons.search),
                      ),
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
                          trailing: const Icon(LucideIcons.chevron_right),
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
                    // Pinned Circles: top groups by most recent activity.
                    if (entries.isNotEmpty) ...[
                      if (_query.isEmpty)
                        () {
                          // Pick top-level groups with activity, sorted by
                          // recency, capped at 3.
                          final pinned =
                              entries
                                  .where(
                                    (e) =>
                                        e.level == 0 &&
                                        activityMap.containsKey(e.group.id),
                                  )
                                  .toList()
                                ..sort((a, b) {
                                  final ta = activityMap[a.group.id]!.time;
                                  final tb = activityMap[b.group.id]!.time;
                                  return tb.compareTo(ta);
                                });
                          final pinnedEntries = pinned.take(3).toList();
                          if (pinnedEntries.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: Space.sm,
                                  bottom: Space.sm,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      LucideIcons.pin,
                                      size: Space.md,
                                      color: accents.caption,
                                    ),
                                    const SizedBox(width: Space.sm),
                                    Expanded(
                                      child: Text(
                                        'PINNED CIRCLES',
                                        style: CircleTextStyles.label(
                                          accents.caption,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              for (final entry in pinnedEntries)
                                _CircleCard(
                                  group: entry.group,
                                  workspace: workspace,
                                  level: 0,
                                  activity: activityMap[entry.group.id],
                                  eventCount: eventCounts[entry.group.id] ?? 0,
                                  notificationCount: _notificationCount(
                                    workspace,
                                    entry.group.id,
                                  ),
                                  pinned: true,
                                  expanded: null,
                                  onToggle: null,
                                ),
                            ],
                          );
                        }(),
                    ],
                    // All Circles section header.
                    if (entries.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: Space.md,
                          bottom: Space.sm,
                        ),
                        child: Text(
                          'ALL CIRCLES',
                          style: CircleTextStyles.label(accents.caption),
                        ),
                      ),
                    for (final (i, entry) in entries.indexed) ...[
                      if (_query.isNotEmpty && entry.path.isNotEmpty)
                        Text(
                          entry.path.join(' › '),
                          style: theme.textTheme.bodySmall,
                        ),
                      CircleFadeIn(
                        delay: CircleMotion.staggerDelay * i,
                        child: _CircleCard(
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
                      ),
                    ],
                    if (workspace.pending.isNotEmpty) ...[
                      const SizedBox(height: Space.lg),
                      const CircleSectionTitle('Waiting for approval'),
                      for (final pending in workspace.pending)
                        CircleRow(
                          child: ListTile(
                            leading: const CircleInitialAvatar(
                              icon: LucideIcons.hourglass,
                              tone: CircleTone.neutral,
                            ),
                            title: Text(pending.name),
                            subtitle: const Text('Waiting for approval'),
                            trailing: const Icon(LucideIcons.chevron_right),
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
    return Material(
      color: selected ? theme.colorScheme.primary : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(CircleRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(CircleRadius.button),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: Space.large),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.sm,
            vertical: Space.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CircleRadius.button),
            border: selected ? null : Border.all(color: accents.hairline),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: CircleTextStyles.label(
              selected ? theme.colorScheme.onPrimary : accents.caption,
            ),
          ),
        ),
      ),
    );
  }
}

/// Derive a notification count for a group from unread memories + comments.
int _notificationCount(CircleWorkspace workspace, String groupId) {
  var count = 0;
  for (final memory in workspace.memories) {
    if (memory.groupId == groupId) count++;
  }
  return count;
}

/// Latest activity info for a group.
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

/// A circle card matching the design: cover photo, name, member count,
/// avatar stack, activity preview, event badge, chevron.
class _CircleCard extends ConsumerWidget {
  const _CircleCard({
    required this.group,
    required this.workspace,
    this.level = 0,
    this.activity,
    this.eventCount = 0,
    this.notificationCount = 0,
    this.pinned = false,
    this.expanded,
    this.onToggle,
  });
  final CircleGroup group;
  final CircleWorkspace workspace;
  final int level;
  final _GroupActivity? activity;
  final int eventCount;
  final int notificationCount;
  final bool pinned;
  final bool? expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    final indent = math.min(level, _indentLevels) * _indentStep;
    final memberCount = group.roles.length;
    final memberIds = group.roles.keys.toList();
    final visibleAvatars = memberIds.take(3).toList();
    final remaining = memberCount - visibleAvatars.length;

    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent),
      child: CircleSurfaceCard(
        onTap: () {
          if (!CirclePaneScope.select(context, 'groups', group.id)) {
            context.push('/groups/g/${group.id}');
          }
        },
        padding: const EdgeInsets.symmetric(horizontal: Space.sm),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover photo.
                  _GroupCoverPhoto(groupId: group.id, type: group.type),
                  const SizedBox(width: Space.md),
                  // Info column.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name row with optional pin icon.
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CircleTextStyles.homeAuthor(
                                  theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (pinned) ...[
                              const SizedBox(width: Space.xs),
                              Icon(
                                LucideIcons.pin,
                                size: CircleSizes.iconInline,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: Space.xs),
                        // Member count.
                        Text(
                          '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                          style: CircleTextStyles.metadata(accents.caption),
                        ),
                        const SizedBox(height: Space.xs),
                        // Avatar stack + remaining count.
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width:
                                  visibleAvatars.length * Space.section +
                                  Space.sm,
                              height: CircleAvatarSize.small.diameter,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  for (
                                    var i = 0;
                                    i < visibleAvatars.length;
                                    i++
                                  )
                                    Positioned(
                                      left: i * Space.section,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: theme.colorScheme.surface,
                                            width: Space.xs / 2,
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
                            if (remaining > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.sm,
                                  vertical: Space.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: accents.recessed,
                                  borderRadius: BorderRadius.circular(
                                    CircleRadius.button,
                                  ),
                                ),
                                child: Text(
                                  '+$remaining',
                                  style: CircleTextStyles.caption(
                                    accents.caption,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // Activity line.
                        if (activity != null) ...[
                          const SizedBox(height: Space.xs),
                          Row(
                            children: [
                              Icon(
                                activity!.icon,
                                size: Space.md,
                                color: accents.caption,
                              ),
                              const SizedBox(width: Space.xs),
                              Expanded(
                                child: Text(
                                  activity!.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: CircleTextStyles.metadata(
                                    accents.caption,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            circleTimeAgo(activity!.time),
                            style: CircleTextStyles.caption(accents.caption),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Right side: event badge, notification count, chevron.
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (eventCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.sm,
                            vertical: Space.xs,
                          ),
                          margin: const EdgeInsets.only(bottom: Space.xs),
                          decoration: BoxDecoration(
                            color: accents.heartContainer,
                            borderRadius: BorderRadius.circular(
                              CircleRadius.button,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.calendar,
                                size: CircleSizes.iconInline,
                                color: accents.heart,
                              ),
                              const SizedBox(width: Space.xs),
                              Text(
                                '$eventCount ${eventCount == 1 ? 'event' : 'events'}',
                                style: CircleTextStyles.caption(accents.heart),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (notificationCount > 0)
                            Container(
                              width: Space.section,
                              height: Space.section,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$notificationCount',
                                style: CircleTextStyles.caption(
                                  theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          const SizedBox(width: Space.xs),
                          Icon(
                            LucideIcons.chevron_right,
                            size: Space.section,
                            color: accents.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (expanded != null)
              Tooltip(
                message: '${expanded! ? 'Collapse' : 'Expand'} ${group.name}',
                child: InkWell(
                  onTap: onToggle,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: CircleSizes.minTouchTarget,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: Space.sm,
                        horizontal: Space.sm,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            expanded! ? 'Hide subgroups' : 'Show subgroups',
                            style: CircleTextStyles.caption(accents.caption),
                          ),
                          const SizedBox(width: Space.xs),
                          Icon(
                            expanded!
                                ? LucideIcons.chevron_up
                                : LucideIcons.chevron_down,
                            size: CircleSizes.iconInline,
                            color: accents.caption,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Rounded rectangle cover photo for a group.
class _GroupCoverPhoto extends ConsumerWidget {
  const _GroupCoverPhoto({required this.groupId, required this.type});
  final String groupId;
  final CircleType type;

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
      borderRadius: BorderRadius.circular(CircleRadius.small),
      child: SizedBox(
        width: Space.large * 2 + Space.md,
        height: Space.large * 2,
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
                  size: CircleAvatarSize.large,
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
                          LucideIcons.chevron_right,
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
                              ? LucideIcons.chevron_up
                              : LucideIcons.chevron_down,
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
                      ? 'Creating\u2026'
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
