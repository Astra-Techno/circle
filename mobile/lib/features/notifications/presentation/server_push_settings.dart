import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/notifications/push_config.dart';
import '../application/push_settings.dart';
import '../application/push_session_coordinator.dart';

class ServerPushSettingsScreen extends ConsumerWidget {
  const ServerPushSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(pushSettingsProvider);
    return load.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () =>
          const CircleSkeletonPage(label: 'Loading notification choices'),
      error: (_, _) => ReadingPane(
        child: CircleEmpty(
          title: 'Your choices couldn’t load',
          message: 'Check your connection and try again.',
          action: FilledButton(
            onPressed: () => ref.invalidate(pushSettingsProvider),
            child: const Text('Try again'),
          ),
        ),
      ),
      data: (preferences) =>
          _Choices(preferences: preferences, busy: load.isLoading),
    );
  }
}

class _Choices extends ConsumerWidget {
  const _Choices({required this.preferences, required this.busy});
  final PushPreferences preferences;
  final bool busy;
  String _time(BuildContext context, int minute) => MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay(hour: minute ~/ 60, minute: minute % 60));

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheet) => SingleChildScrollView(
        padding: CircleInsets.form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose what reaches you',
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            const SizedBox(height: Space.md),
            Text(
              'CIRCLE will ask your phone for permission. Only the updates you select can notify you. Quiet hours follow ${preferences.timezone}.',
            ),
            const SizedBox(height: Space.section),
            FilledButton(
              onPressed: () => Navigator.pop(sheet, true),
              child: const Text('Continue'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheet, false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
    if (proceed != true || !context.mounted) return;
    await runCalmly(
      context,
      () => ref
          .read(pushSettingsProvider.notifier)
          .change(enabled: true, requestPermission: true),
      success: 'Notification choices saved.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(pushSettingsProvider.notifier);
    final coordinator = ref.read(pushSessionCoordinatorProvider);
    Widget category(PushCategory type, String label, String help) => CircleRow(
      child: SwitchListTile(
        key: ValueKey('push-${type.name}'),
        title: Text(label),
        subtitle: Text(help),
        value: preferences.categories[type] == true,
        onChanged: busy
            ? null
            : (value) => runCalmly(
                context,
                () => controller.change(categories: {type: value}),
              ),
      ),
    );
    Future<void> pickTime(bool start) async {
      final minute = start ? preferences.quietStart : preferences.quietEnd;
      final selected = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      );
      if (selected == null || !context.mounted) return;
      final value = selected.hour * 60 + selected.minute;
      await runCalmly(
        context,
        () => controller.change(
          quietStart: start ? value : null,
          quietEnd: start ? null : value,
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: coordinator.connectionRevision,
      builder: (context, _, _) => ReadingPane(
        child: ListView(
          padding: CircleInsets.form,
          children: [
            const CircleIntroPanel(
              title: 'Your updates',
              subtitle: 'A little less noise. More of what matters.',
              icon: Icons.notifications_outlined,
            ),
            const SizedBox(height: Space.section),
            Text(
              preferences.enabled && coordinator.active
                  ? 'Notifications are connected on this phone.'
                  : 'Choose your updates, then connect this phone.',
            ),
            const SizedBox(height: Space.sm),
            if (preferences.enabled &&
                pushQuietNow(preferences, DateTime.now()))
              CircleNote(
                'Quiet hours are active in ${preferences.timezone}. Updates wait until ${_time(context, preferences.quietEnd)} in that time zone. You can change this below.',
              ),
            const Text(
              'Your choices apply to this account. Phone permission stays on each device.',
            ),
            const SizedBox(height: Space.lg),
            if (busy)
              const LinearProgressIndicator(
                semanticsLabel: 'Saving notification choices',
              ),
            FilledButton.icon(
              onPressed: busy ? null : () => _enable(context, ref),
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(
                preferences.enabled
                    ? 'Connect this phone'
                    : 'Enable notifications',
              ),
            ),
            if (preferences.enabled)
              TextButton(
                onPressed: busy
                    ? null
                    : () => runCalmly(
                        context,
                        () => controller.change(enabled: false),
                        success: 'Notifications turned off.',
                      ),
                child: const Text('Turn off notifications'),
              ),
            ExpansionTile(
              title: const Text('Connection help'),
              children: [
                ListTile(
                  title: const Text('Notification support'),
                  subtitle: Text(
                    ref.watch(pushClientEnabledProvider)
                        ? 'Included in this app build'
                        : 'Unavailable in this build or on this device',
                  ),
                ),
                ListTile(
                  title: const Text('This phone'),
                  subtitle: Text(
                    coordinator.active
                        ? 'Registered with CIRCLE. Delivery also depends on server setup and your notification choices.'
                        : coordinator.connectionExplanation,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.section),
            const CircleSectionTitle('Choose updates'),
            category(
              PushCategory.memories,
              'New Memories',
              'When someone shares in one of your groups',
            ),
            category(
              PushCategory.repliesReactions,
              'Comments and replies',
              'Comments on your Memories and replies to you',
            ),
            category(
              PushCategory.groups,
              'Groups and safety',
              'Group invitations and reports for group admins',
            ),
            const SizedBox(height: Space.section),
            category(
              PushCategory.chats,
              'Messages',
              'Unmuted group messages and eligible direct requests',
            ),
            category(
              PushCategory.events,
              'Events',
              'Plans, RSVP updates, cancellations and reminders',
            ),
            category(
              PushCategory.polls,
              'Polls',
              'New questions and results for polls you joined; no alerts for each vote',
            ),
            const CircleSectionTitle('Quiet hours'),
            CircleRow(
              child: SwitchListTile(
                title: const Text('Keep things quiet'),
                subtitle: const Text(
                  'Updates wait until your quiet hours end.',
                ),
                value: preferences.quietHours,
                onChanged: busy
                    ? null
                    : (value) => runCalmly(
                        context,
                        () => controller.change(quietHours: value),
                      ),
              ),
            ),
            if (preferences.quietHours) ...[
              CircleRow(
                child: ListTile(
                  title: const Text('Starts'),
                  trailing: Text(_time(context, preferences.quietStart)),
                  onTap: busy ? null : () => pickTime(true),
                ),
              ),
              CircleRow(
                child: ListTile(
                  title: const Text('Ends'),
                  trailing: Text(_time(context, preferences.quietEnd)),
                  onTap: busy ? null : () => pickTime(false),
                ),
              ),
            ],
            CircleRow(
              child: ListTile(
                title: const Text('Time zone'),
                subtitle: Text(preferences.timezone.replaceAll('_', ' ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: busy
                    ? null
                    : () async {
                        final zone = await showDialog<String>(
                          context: context,
                          builder: (_) => const _TimezonePicker(),
                        );
                        if (zone != null && context.mounted) {
                          await runCalmly(
                            context,
                            () => controller.change(timezone: zone),
                          );
                        }
                      },
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final zone = await ref
                          .read(deviceTimezoneProvider)
                          .read();
                      if (!context.mounted) return;
                      if (zone == null ||
                          !ref.read(pushTimezonesProvider).contains(zone)) {
                        showCircleMessage(
                          context,
                          'Choose your time zone from the list.',
                        );
                        return;
                      }
                      await runCalmly(
                        context,
                        () => controller.change(timezone: zone),
                        success: 'Device time zone saved.',
                      );
                    },
              child: const Text('Use device time zone'),
            ),
            const SizedBox(height: Space.section),
            TextButton.icon(
              onPressed: () async {
                final opened = await ref
                    .read(deviceTimezoneProvider)
                    .openSettings();
                if (!opened && context.mounted) {
                  showCircleMessage(
                    context,
                    'Open notification permission in your phone’s settings.',
                  );
                }
              },
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Phone notification settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimezonePicker extends ConsumerStatefulWidget {
  const _TimezonePicker();
  @override
  ConsumerState<_TimezonePicker> createState() => _TimezonePickerState();
}

class _TimezonePickerState extends ConsumerState<_TimezonePicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final zones = ref
        .watch(pushTimezonesProvider)
        .where(
          (zone) => zone
              .replaceAll('_', ' ')
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();
    return AlertDialog(
      title: const Text('Choose a time zone'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.sizeOf(context).height * .5,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search city or region',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: Space.sm),
            Expanded(
              child: ListView.builder(
                itemCount: zones.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(zones[index].replaceAll('_', ' ')),
                  onTap: () => Navigator.pop(context, zones[index]),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
