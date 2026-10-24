import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/theme_controller.dart';
import '../../notifications/application/notification_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/workspace_view.dart';

/// H1: your profile, invitations, Activity, settings and saved Memories.
class CircleYou extends ConsumerWidget {
  const CircleYou({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => WorkspaceView(
    builder: (workspace) {
      final waiting = workspace.invitations.length;
      final saved = workspace.memories.where((memory) => memory.saved);
      final badge = ref.watch(activityBadgeProvider);
      final features = ref.watch(circleFeaturesProvider);
      final account = ref.watch(serverAccountProvider);
      Widget entry({
        required IconData icon,
        required String title,
        required String subtitle,
        required String location,
        Widget? badgeLabel,
      }) => CircleRow(
        child: ListTile(
          leading: CircleInitialAvatar(icon: icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [?badgeLabel, const Icon(Icons.chevron_right)],
          ),
          onTap: () => context.push(location),
        ),
      );
      return ReadingPane(
        child: ListView(
          padding: CircleInsets.page,
          children: [
            const CircleHeading(
              title: 'A little space\nthat’s yours.',
              subtitle: 'Your circles. Your preferences. Your peace of mind.',
            ),
            if (account == null)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleInitialAvatar(
                  name: 'You',
                  size: CircleAvatarSize.large,
                ),
                title: Text('You · Fictional preview'),
                subtitle: Text('No real account or phone number is saved.'),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleInitialAvatar(
                  name: account.displayName.isEmpty
                      ? 'You'
                      : account.displayName,
                  size: CircleAvatarSize.large,
                ),
                title: Text(
                  account.displayName.isEmpty ? 'You' : account.displayName,
                ),
                subtitle: Text('Signed in on ${features.host}'),
              ),
            if (waiting > 0)
              CircleRow(
                child: ListTile(
                  leading: const CircleInitialAvatar(
                    icon: Icons.mark_email_unread_outlined,
                  ),
                  title: Text(
                    waiting == 1
                        ? '1 invitation waiting'
                        : '$waiting invitations waiting',
                  ),
                  subtitle: const Text('Review them in Groups.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/groups'),
                ),
              ),
            if (features.has(CircleFeature.activity))
              entry(
                icon: Icons.notifications_outlined,
                title: 'Activity',
                subtitle: 'Mentions, replies, invitations and event updates',
                location: '/activity',
                badgeLabel: badge == 0
                    ? null
                    : Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: Space.sm,
                        ),
                        child: Badge(
                          label: Text(
                            '$badge',
                            semanticsLabel: '$badge need you',
                          ),
                        ),
                      ),
              ),
            if (features.has(CircleFeature.notificationSettings))
              entry(
                icon: Icons.tune,
                title: 'Notifications',
                subtitle: 'What reaches you, quiet hours, muted chats',
                location: '/you/notifications',
              ),
            if (features.has(CircleFeature.privacy))
              entry(
                icon: Icons.lock_outline,
                title: 'Privacy',
                subtitle: 'Who can message you, close groups, blocked people',
                location: '/you/privacy',
              ),
            entry(
              icon: Icons.manage_accounts_outlined,
              title: 'Account',
              subtitle: features.server
                  ? 'Appearance and logging out'
                  : 'Appearance and ending this preview',
              location: '/you/account',
            ),
            const SizedBox(height: Space.md),
            const CircleSectionTitle('Saved Memories'),
            if (saved.isEmpty) const Text('Save a Memory to keep it close.'),
            for (final memory in saved)
              CircleRow(
                child: ListTile(
                  title: Text(
                    memory.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/home/memory/${memory.id}'),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// H5: appearance, what comes before launch, and ending the preview.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final server = ref.watch(circleFeaturesProvider).server;
    return ReadingPane(
      child: ListView(
        padding: CircleInsets.form,
        children: [
          CircleHeading(
            title: 'Account',
            subtitle: server
                ? 'How CIRCLE looks, and your account.'
                : 'How CIRCLE looks, and your preview session.',
          ),
          DropdownButtonFormField<ThemeMode>(
            initialValue: ref.watch(themeProvider),
            // Fits narrow screens at large text sizes.
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Appearance'),
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('Use device setting'),
              ),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            ],
            onChanged: (mode) {
              if (mode != null) ref.read(themeProvider.notifier).change(mode);
            },
          ),
          const CircleSectionTitle('Comes before launch'),
          Text(
            server
                ? 'Changing your password, choosing a language, exporting '
                      'your data and deleting your account come in a later '
                      'milestone.'
                : 'Changing your password, choosing a language, exporting your '
                      'data and deleting your account arrive with real accounts. '
                      'This preview has no account to change or delete.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: Space.section),
          CircleEmpty(
            title: 'Quiet by design',
            message: server
                ? 'CIRCLE sends no notifications and never uploads your contacts. Logging out removes your session from this device.'
                : 'No notifications, contact uploads or real accounts are used in this preview. All changes disappear when you end the session.',
          ),
          const SizedBox(height: Space.md),
          OutlinedButton(
            onPressed: () => runCalmly(
              context,
              () => server
                  ? ref.read(circleWorkspaceProvider.notifier).logOut()
                  : ref.read(circlePreviewSessionProvider.notifier).leave(),
            ),
            child: Text(
              server ? 'Log out' : 'End preview and clear local changes',
            ),
          ),
        ],
      ),
    );
  }
}
