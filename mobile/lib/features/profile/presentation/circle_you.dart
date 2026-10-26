import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/theme_controller.dart';
import 'profile_photo.dart';
import '../../notifications/application/notification_providers.dart';
import '../../memories/presentation/scoped_memory_list.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/workspace_view.dart';

/// H1: your profile, invitations, Activity, settings and saved Memories.
class CircleYou extends ConsumerStatefulWidget {
  const CircleYou({super.key});
  @override
  ConsumerState<CircleYou> createState() => _CircleYouState();
}

class _CircleYouState extends ConsumerState<CircleYou> {
  String? _loadError;
  @override
  void initState() {
    super.initState();
    unawaited(Future.microtask(_refreshProfile));
  }

  Future<void> _refreshProfile() async {
    if (ref.read(serverAccountProvider) == null) return;
    final error = await ref
        .read(serverSessionProvider.notifier)
        .refreshProfile();
    if (mounted) setState(() => _loadError = error);
  }

  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      final waiting = workspace.invitations.length;
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
            if (account != null)
              ProfileHeader(
                key: const ValueKey('you-profile-card'),
                account: account,
              )
            else
              Container(
                key: const ValueKey('you-profile-card'),
                padding: const EdgeInsets.all(Space.section),
                decoration: CircleDepth.profilePanel(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleInitialAvatar(
                          name: account?.displayName.isNotEmpty == true
                              ? account!.displayName
                              : 'You',
                          size: CircleAvatarSize.large,
                        ),
                        const SizedBox(width: Space.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account == null
                                    ? 'You · Fictional preview'
                                    : account.displayName.isEmpty
                                    ? 'You'
                                    : account.displayName,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: Space.xs),
                              Text(
                                account == null
                                    ? 'No real account or phone number is saved.'
                                    : 'Your people. Your private circles.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.lg),
                    TextButton.icon(
                      icon: const Icon(Icons.groups_outlined),
                      label: const Text('Your groups'),
                      onPressed: () => context.go('/groups'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Space.section),
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
                  ? 'Appearance, connection and sign out'
                  : 'Appearance and ending this preview',
              location: '/you/account',
            ),
            const SizedBox(height: Space.md),
            if (account != null) ...[
              if (_loadError != null)
                TextButton.icon(
                  onPressed: _refreshProfile,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry loading profile details'),
                ),
              const CircleSectionTitle('Personal details'),
              const CirclePill('Only you', icon: Icons.lock_outline),
              const SizedBox(height: Space.sm),
              if ([
                account.currentCity,
                account.hometown,
                account.work,
                account.education,
              ].every((value) => value.isEmpty))
                const Text(
                  'Add your city, hometown, work and education in Edit profile.',
                ),
              for (final detail in [
                (Icons.location_city_outlined, 'Lives in', account.currentCity),
                (Icons.home_outlined, 'From', account.hometown),
                (Icons.work_outline, 'Work', account.work),
                (Icons.school_outlined, 'Education', account.education),
              ])
                if (detail.$3.isNotEmpty)
                  CircleRow(
                    child: ListTile(
                      leading: Icon(detail.$1),
                      title: Text(detail.$2),
                      subtitle: Text(detail.$3),
                    ),
                  ),
              const SizedBox(height: Space.section),
            ],
            const CircleSectionTitle('Saved Memories'),
            ScopedMemoryList(
              query: const MemoryQuery(saved: true),
              empty: Container(
                padding: const EdgeInsets.all(Space.section),
                decoration: CircleDepth.panel(
                  context,
                  radius: CircleRadius.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: CircleInitialAvatar(
                        icon: Icons.bookmarks_outlined,
                        size: CircleAvatarSize.large,
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                    Text(
                      'Keep a Memory close',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: Space.sm),
                    const Text(
                      'Save a Memory from your circles and find it here whenever you want.',
                    ),
                    const SizedBox(height: Space.lg),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Browse Memories'),
                      onPressed: () => context.go('/home'),
                    ),
                  ],
                ),
              ),
              itemBuilder: (_, memory) => CircleRow(
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
          if (server) ...[
            const CircleSectionTitle('Connection'),
            const Text('Connected server'),
            const SizedBox(height: Space.sm),
            SelectableText(ref.watch(circleFeaturesProvider).host!),
          ],
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
