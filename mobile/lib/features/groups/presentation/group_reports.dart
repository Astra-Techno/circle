import '../../moderation/presentation/server_reports.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../memories/presentation/circle_memories.dart' show memoryTimeLabel;
import '../../moderation/application/moderation_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import 'group_members.dart';

/// C9: a group's reports, for that group's admins only. Reasons and counts,
/// never who reported. Subgroups show only name, size and reasons.
class GroupReportsScreen extends ConsumerWidget {
  const GroupReportsScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(circleFeaturesProvider).server) {
      return ServerReportsScreen(groupId: groupId);
    }
    final load = ref.watch(moderationQueueProvider(groupId));
    final now = ref.watch(circleClockProvider)();
    return load.when(
      skipLoadingOnReload: true,
      loading: () => const CircleSkeletonPage(
        shape: CircleSkeletonShape.cards,
        count: 2,
        label: 'Loading reports',
      ),
      error: (_, _) => const ReadingPane(
        child: Padding(
          padding: CircleInsets.form,
          child: CircleEmpty(
            title: 'Reports couldn’t load',
            message: 'Go back and try again.',
          ),
        ),
      ),
      data: (result) {
        final queue = result.queue;
        if (queue == null) {
          return ReadingPane(
            child: ListView(
              padding: CircleInsets.form,
              children: [
                CircleEmpty(
                  title: 'Reports are for admins',
                  message:
                      result.unavailable ??
                      'Only admins of this group can review reports.',
                ),
              ],
            ),
          );
        }
        return ReadingPane(
          child: ListView(
            padding: CircleInsets.form,
            children: [
              CircleHeading(
                title: 'Reports in ${queue.group.name}',
                subtitle:
                    'Hide what breaks the group’s trust, or dismiss what’s fine. '
                    'Reporters stay anonymous.',
              ),
              const PreviewLabel(
                'Preview: fictional reports. Nothing leaves this device.',
              ),
              CircleSectionTitle(
                queue.items.isEmpty
                    ? 'To review'
                    : 'To review (${queue.items.length})',
              ),
              if (queue.items.isEmpty)
                const CircleEmpty(
                  title: 'Nothing to review',
                  message: 'Reports from members of this group appear here.',
                ),
              for (final item in queue.items)
                _QueueCard(group: queue.group, item: item, now: now),
              const SizedBox(height: Space.md),
              const CircleSectionTitle('Admin actions'),
              if (queue.audit.isEmpty)
                Text(
                  'No admin actions yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              for (final entry in queue.audit)
                CircleRow(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleInitialAvatar(
                      name: entry.actorName,
                      size: CircleAvatarSize.small,
                      tone: CircleTone.neutral,
                    ),
                    title: Text(
                      '${entry.sentence} · ${memoryTimeLabel(entry.at, now)}',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _QueueCard extends ConsumerWidget {
  const _QueueCard({
    required this.group,
    required this.item,
    required this.now,
  });
  final CircleGroup group;
  final QueueItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(circleWorkspaceProvider.notifier);
    final target = item.target;
    final key = target.key;
    final subgroup = target.kind == ReportKind.subgroup;
    final what = subgroup
        ? 'Subgroup'
        : '${target.kind.label[0].toUpperCase()}${target.kind.label.substring(1)}';
    final count = item.count;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.xs,
              children: [
                CirclePill(what, icon: Icons.flag_outlined),
                CirclePill(
                  count == 1 ? '1 report' : '$count reports',
                  tone: CircleTone.strong,
                ),
                if (item.hidden)
                  const CirclePill(
                    'Hidden',
                    icon: Icons.visibility_off_outlined,
                  ),
              ],
            ),
            const SizedBox(height: Space.sm),
            if (subgroup) ...[
              Text(item.subgroupName ?? '', style: theme.textTheme.titleMedium),
              Text(
                '${item.subgroupMemberCount ?? 0} members · '
                'You can remove it without opening it.',
                style: theme.textTheme.bodySmall,
              ),
            ] else ...[
              if (item.personName != null)
                Text(
                  target.kind == ReportKind.member
                      ? item.personName!
                      : 'By ${item.personName}',
                  style: theme.textTheme.titleMedium,
                ),
              if (item.summary != null && target.kind != ReportKind.member)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: Text(
                    '“${item.summary}”',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            const SizedBox(height: Space.sm),
            Text(
              '${ModerationRules.reasonsLabel(item.reasons)} · '
              '${memoryTimeLabel(item.latestAt, now)}',
              style: theme.textTheme.bodySmall,
            ),
            for (final note in item.notes)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text('Note: $note', style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                if (target.kind.hideable)
                  item.hidden
                      ? OutlinedButton(
                          onPressed: () => runCalmly(
                            context,
                            () => controller.unhide(group.id, key),
                            success: 'Shown to everyone again.',
                          ),
                          child: Text(
                            'Unhide',
                            semanticsLabel: 'Unhide this ${target.kind.label}',
                          ),
                        )
                      : FilledButton.tonal(
                          onPressed: () => runCalmly(
                            context,
                            () => controller.hide(group.id, key),
                            success: 'Hidden from members.',
                            onUndo: undoWith(
                              context,
                              () => controller.unhide(group.id, key),
                            ),
                          ),
                          child: Text(
                            'Hide',
                            semanticsLabel: 'Hide this ${target.kind.label}',
                          ),
                        ),
                if (subgroup)
                  FilledButton.tonal(
                    onPressed: () => _removeSubgroup(context, ref),
                    child: Text(
                      'Remove subgroup',
                      semanticsLabel: 'Remove subgroup ${item.subgroupName}',
                    ),
                  ),
                if (item.canRemovePerson && target.personId != null)
                  OutlinedButton(
                    onPressed: () => confirmRemoveMember(
                      context,
                      ref,
                      group,
                      target.personId!,
                      item.personName ?? 'this member',
                    ),
                    child: Text(
                      'Remove member',
                      semanticsLabel:
                          'Remove ${item.personName} from ${group.name}',
                    ),
                  ),
                TextButton(
                  onPressed: () => runCalmly(
                    context,
                    () => controller.dismissReports(group.id, key),
                    success: 'Report dismissed.',
                    onUndo: undoDetached(
                      context,
                      () => controller.restoreReports(group.id, key),
                    ),
                  ),
                  child: Text(
                    'Dismiss',
                    semanticsLabel:
                        'Dismiss reports about this ${target.kind.label}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeSubgroup(BuildContext context, WidgetRef ref) async {
    final name = item.subgroupName ?? 'this subgroup';
    final confirmed = await confirmCircleAction(
      context,
      title: 'Remove $name?',
      message:
          '$name and every subgroup inside it will be removed for all '
          '${item.subgroupMemberCount ?? 0} members. Its Memories, events '
          'and chat close. This can’t be undone.',
      confirm: 'Remove subgroup',
    );
    if (!confirmed || !context.mounted) return;
    await runCalmly(
      context,
      () => ref
          .read(circleWorkspaceProvider.notifier)
          .removeSubgroup(group.id, item.target.id),
      success: '$name was removed.',
    );
  }
}

/// The admin's way in: "2 reports" in the group header (admins only).
class GroupReportsButton extends StatelessWidget {
  const GroupReportsButton({
    super.key,
    required this.group,
    required this.count,
  });
  final CircleGroup group;
  final int count;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => context.push('/groups/g/${group.id}/reports'),
    icon: const Icon(Icons.flag_outlined),
    label: Text(
      count == 0
          ? 'Reports'
          : count == 1
          ? '1 report'
          : '$count reports',
    ),
  );
}
