import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../chat/application/chat_providers.dart';
import '../application/notification_providers.dart';

/// H4: what may reach you, quiet hours, the daily digest, group levels and
/// muted chats. These settings also decide which Activity items get the
/// bell's badge.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(notificationSettingsProvider);
    return load.when(
      skipLoadingOnReload: true,
      loading: () =>
          const CircleSkeletonPage(label: 'Loading notification settings'),
      error: (_, _) => const ReadingPane(
        child: Padding(
          padding: CircleInsets.form,
          child: CircleEmpty(
            title: 'Settings couldn’t load',
            message: 'Go back and try again.',
          ),
        ),
      ),
      data: (view) => _Settings(view: view),
    );
  }
}

class _Settings extends ConsumerWidget {
  const _Settings({required this.view});
  final NotificationSettingsView view;

  Future<int?> _time(BuildContext context, int minute) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(notificationControllerProvider.notifier);
    final settings = view.settings;
    final theme = Theme.of(context);
    const inset = EdgeInsets.symmetric(horizontal: Space.lg);
    Widget pad(Widget child) => Padding(padding: inset, child: child);
    Widget toggle(NotificationType type) => CircleRow(
      child: SwitchListTile(
        title: Text(type.label),
        subtitle: type.personal
            ? null
            : Text(
                NotificationRules.pushOn(settings, type)
                    ? 'Also sent as a push'
                    : 'Activity and digest only',
              ),
        value: NotificationRules.pushOn(settings, type),
        onChanged: (value) =>
            runCalmly(context, () => controller.setPush(type, value)),
      ),
    );

    return ReadingPane(
      child: ListView(
        padding: CircleInsets.form.copyWith(left: 0, right: 0),
        children: [
          pad(
            const CircleHeading(
              title: 'Notifications',
              subtitle:
                  'Only personal things reach you. Everything else waits '
                  'quietly in Activity.',
            ),
          ),
          pad(
            const PreviewLabel(
              'Preview: no notifications are sent; these settings show what '
              'would happen.',
            ),
          ),
          pad(const CircleSectionTitle('Push (personal)')),
          for (final type in NotificationType.values)
            if (type.personal) toggle(type),
          pad(const CircleSectionTitle('Inbox only / daily digest')),
          pad(
            Text(
              'Turn one on to also get it as a push.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          for (final type in NotificationType.values)
            if (!type.personal) toggle(type),
          pad(const CircleSectionTitle('Quiet hours')),
          CircleRow(
            child: SwitchListTile(
              title: const Text('Quiet hours'),
              subtitle: Text(
                '${NotificationRules.timeLabel(settings.quietStart)}–'
                '${NotificationRules.timeLabel(settings.quietEnd)}. Pushes '
                'wait until the end.',
              ),
              value: settings.quietHours,
              onChanged: (value) => runCalmly(
                context,
                () => controller.setQuietHours(enabled: value),
              ),
            ),
          ),
          if (settings.quietHours) ...[
            CircleRow(
              child: ListTile(
                title: const Text('Starts'),
                trailing: Text(
                  NotificationRules.timeLabel(settings.quietStart),
                ),
                onTap: () async {
                  final minute = await _time(context, settings.quietStart);
                  if (minute == null || !context.mounted) return;
                  await runCalmly(
                    context,
                    () => controller.setQuietHours(start: minute),
                  );
                },
              ),
            ),
            CircleRow(
              child: ListTile(
                title: const Text('Ends'),
                trailing: Text(NotificationRules.timeLabel(settings.quietEnd)),
                onTap: () async {
                  final minute = await _time(context, settings.quietEnd);
                  if (minute == null || !context.mounted) return;
                  await runCalmly(
                    context,
                    () => controller.setQuietHours(end: minute),
                  );
                },
              ),
            ),
          ],
          pad(const CircleSectionTitle('Daily digest')),
          CircleRow(
            child: SwitchListTile(
              title: const Text('Daily digest'),
              subtitle: Text(
                settings.digest
                    ? 'One calm summary at '
                          '${NotificationRules.timeLabel(settings.digestAt)}.'
                    : 'Off. Everything stays in Activity.',
              ),
              value: settings.digest,
              onChanged: (value) => runCalmly(
                context,
                () => controller.setDigest(enabled: value),
              ),
            ),
          ),
          if (settings.digest)
            CircleRow(
              child: ListTile(
                title: const Text('Digest time'),
                trailing: Text(NotificationRules.timeLabel(settings.digestAt)),
                onTap: () async {
                  final minute = await _time(context, settings.digestAt);
                  if (minute == null || !context.mounted) return;
                  await runCalmly(
                    context,
                    () => controller.setDigest(at: minute),
                  );
                },
              ),
            ),
          pad(const CircleSectionTitle('Groups')),
          pad(
            Text(
              'Groups with more than ${NotificationRules.quietGroupAbove} '
              'members start at “mentions and replies only”.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (view.groups.isEmpty)
            pad(const Text('Join a group to choose how it notifies you.')),
          for (final choice in view.groups)
            CircleRow(
              child: ListTile(
                title: Text(choice.group.name),
                subtitle: Text(
                  '${choice.group.roles.length} members · '
                  '${choice.level.label}'
                  '${choice.isDefault ? ' (default)' : ''}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _chooseLevel(context, ref, choice),
              ),
            ),
          pad(const CircleSectionTitle('Muted chats')),
          if (view.mutedChats.isEmpty)
            pad(
              Text(
                'None. Mute any chat for 8 hours, a week or always from '
                'the chat itself.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          for (final chat in view.mutedChats)
            CircleRow(
              child: ListTile(
                title: Text(chat.title),
                subtitle: Text(
                  chat.mutedByDefault
                      ? 'Quiet by default (big group)'
                      : chat.mutedForever
                      ? 'Muted until you turn it back on'
                      : 'Muted for now',
                ),
                trailing: TextButton(
                  onPressed: () => runCalmly(
                    context,
                    () => ref
                        .read(chatControllerProvider.notifier)
                        .mute(chat.id, null),
                    success: '${chat.title} unmuted.',
                  ),
                  child: Text('Unmute', semanticsLabel: 'Unmute ${chat.title}'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _chooseLevel(
    BuildContext context,
    WidgetRef ref,
    GroupNotifyChoice choice,
  ) async {
    final picked = await showModalBottomSheet<({GroupNotifyLevel? level})>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.section),
                child: Semantics(
                  header: true,
                  child: Text(
                    choice.group.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              RadioGroup<GroupNotifyLevel>(
                groupValue: choice.level,
                onChanged: (value) => Navigator.of(context).pop((level: value)),
                child: Column(
                  children: [
                    for (final level in GroupNotifyLevel.values)
                      RadioListTile<GroupNotifyLevel>(
                        value: level,
                        title: Text(level.label),
                      ),
                  ],
                ),
              ),
              if (!choice.isDefault)
                Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop((level: null)),
                    child: const Text('Use the default'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    await runCalmly(
      context,
      () => ref
          .read(notificationControllerProvider.notifier)
          .setGroupLevel(choice.group.id, picked.level),
      success: 'Saved for ${choice.group.name}.',
    );
  }
}
