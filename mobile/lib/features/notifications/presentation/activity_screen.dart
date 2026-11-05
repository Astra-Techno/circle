import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../chat/application/chat_providers.dart';
import '../../memories/presentation/circle_memories.dart' show memoryTimeLabel;
import '../../workspace/application/workspace_providers.dart';
import '../application/notification_providers.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

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
        child: const Icon(LucideIcons.bell),
      ),
    );
  }
}

IconData _icon(ActivityKind kind) => switch (kind) {
  ActivityKind.reply || ActivityKind.mention => LucideIcons.at_sign,
  ActivityKind.reactions => LucideIcons.heart,
  ActivityKind.newMemory => LucideIcons.image,
  ActivityKind.invitation => LucideIcons.mail,
  ActivityKind.approved => LucideIcons.user_check,
  ActivityKind.declined => LucideIcons.user_x,
  ActivityKind.joinRequest => LucideIcons.user_plus,
  ActivityKind.eventChanged => LucideIcons.calendar_cog,
  ActivityKind.eventCancelled => LucideIcons.calendar_x,
  ActivityKind.eventReminder => LucideIcons.alarm_clock,
  ActivityKind.newEvent => LucideIcons.calendar,
  ActivityKind.pollClosing => LucideIcons.vote,
  ActivityKind.pollResults => LucideIcons.chart_bar,
  ActivityKind.roleChange => LucideIcons.shield,
  ActivityKind.messageRequest => LucideIcons.inbox,
  ActivityKind.directMessage => LucideIcons.message_circle,
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
              icon: LucideIcons.wifi_off,
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
                    icon: const Icon(LucideIcons.check_check),
                    label: const Text('Mark all read'),
                  ),
                ),
              if (feed.entries.isEmpty)
                const CircleEmpty(
                  icon: LucideIcons.bell,
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
