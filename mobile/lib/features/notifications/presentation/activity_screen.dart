import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../chat/application/chat_providers.dart';
import '../../memories/presentation/circle_memories.dart' show memoryTimeLabel;
import '../../workspace/application/workspace_providers.dart';
import '../application/notification_providers.dart';

/// The shell's bell: opens Activity. The indigo badge counts only unread
/// items that need the person (README §4.0: badges mean something).
class ActivityBell extends ConsumerWidget {
  const ActivityBell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(activityBadgeProvider);
    return IconButton(
      tooltip: 'Activity',
      onPressed: () => context.push('/activity'),
      icon: Badge(
        key: const ValueKey('activity-badge'),
        isLabelVisible: count > 0,
        label: Text('$count', semanticsLabel: '$count need you'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

IconData _icon(ActivityKind kind) => switch (kind) {
  ActivityKind.reply || ActivityKind.mention => Icons.alternate_email,
  ActivityKind.reactions => Icons.favorite_border,
  ActivityKind.newMemory => Icons.photo_outlined,
  ActivityKind.invitation => Icons.mark_email_unread_outlined,
  ActivityKind.approved => Icons.how_to_reg_outlined,
  ActivityKind.declined => Icons.person_off_outlined,
  ActivityKind.joinRequest => Icons.person_add_alt_outlined,
  ActivityKind.eventChanged => Icons.edit_calendar_outlined,
  ActivityKind.eventCancelled => Icons.event_busy_outlined,
  ActivityKind.eventReminder => Icons.alarm_outlined,
  ActivityKind.newEvent => Icons.event_outlined,
  ActivityKind.pollClosing => Icons.how_to_vote_outlined,
  ActivityKind.pollResults => Icons.bar_chart_outlined,
  ActivityKind.roleChange => Icons.shield_outlined,
  ActivityKind.messageRequest => Icons.forward_to_inbox_outlined,
  ActivityKind.directMessage => Icons.chat_bubble_outline,
};

/// I1: what happened in your circles, Today and Earlier. Personal items
/// carry a dot until read; everything else is quiet information.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(activityFeedProvider);
    final now = ref.watch(circleClockProvider)();
    return load.when(
      skipLoadingOnReload: true,
      loading: () => const CircleSkeletonPage(label: 'Loading activity'),
      error: (_, _) => ReadingPane(
        child: ListView(
          padding: CircleInsets.form,
          children: [
            CircleEmpty(
              title: 'Activity couldn’t load',
              message: 'Try again in a moment.',
              action: FilledButton(
                onPressed: () => ref.invalidate(activityFeedProvider),
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
      ),
      data: (feed) {
        final today = [
          for (final entry in feed.entries)
            if (ActivityInboxRules.isToday(entry.item.at, now)) entry,
        ];
        final earlier = [
          for (final entry in feed.entries)
            if (!ActivityInboxRules.isToday(entry.item.at, now)) entry,
        ];
        return ReadingPane(
          child: ListView(
            padding: CircleInsets.form,
            children: [
              const PreviewLabel(
                'Preview: no notifications are sent. Activity comes from '
                'your fictional circles.',
              ),
              if (feed.unread > 0)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () => runCalmly(
                      context,
                      () => ref
                          .read(notificationControllerProvider.notifier)
                          .markAllRead(),
                      success: 'All caught up.',
                    ),
                    icon: const Icon(Icons.done_all),
                    label: const Text('Mark all read'),
                  ),
                ),
              if (feed.entries.isEmpty)
                const CircleEmpty(
                  title: 'All quiet',
                  message:
                      'Mentions, replies, invitations and event updates will '
                      'show up here.',
                ),
              if (today.isNotEmpty) ...[
                const CircleSectionTitle('Today'),
                for (final entry in today) _ActivityRow(entry: entry, now: now),
              ],
              if (earlier.isNotEmpty) ...[
                const CircleSectionTitle('Earlier'),
                for (final entry in earlier)
                  _ActivityRow(entry: entry, now: now),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ActivityRow extends ConsumerWidget {
  const _ActivityRow({required this.entry, required this.now});
  final ActivityEntry entry;
  final DateTime now;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final item = entry.item;
    await ref.read(notificationControllerProvider.notifier).markRead(item.id);
    final workspace = ref.read(circleWorkspaceProvider).value;
    final inbox = await ref.read(chatInboxProvider.future);
    if (workspace == null) return;
    final location = ActivityInboxRules.location(
      item.target,
      workspace,
      conversations: {
        for (final chat in [
          ...inbox.chats,
          ...inbox.requests,
          ...inbox.archived,
        ])
          chat.id,
      },
    );
    if (location == null) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('That’s no longer available to you.')),
        );
      return;
    }
    router.go(location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final item = entry.item;
    final unread = !entry.read;
    return CircleRow(
      child: Semantics(
        value: [if (unread) 'unread', if (entry.badged) 'needs you'].join(', '),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleInitialAvatar(
            icon: _icon(item.kind),
            tone: item.kind.aboutYou ? CircleTone.calm : CircleTone.neutral,
          ),
          title: Text(
            item.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: unread
                ? theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: CircleAccents.of(context).title,
                  )
                : theme.textTheme.bodyMedium,
          ),
          subtitle: Text(
            memoryTimeLabel(item.at, now),
            style: theme.textTheme.bodySmall,
          ),
          trailing: entry.badged
              ? ExcludeSemantics(
                  child: Container(
                    width: Space.sm + Space.xs / 2,
                    height: Space.sm + Space.xs / 2,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
          onTap: () => _open(context, ref),
        ),
      ),
    );
  }
}
