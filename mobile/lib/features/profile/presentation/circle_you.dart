import 'dart:async';
import 'package:flutter/material.dart';
import '../../memories/presentation/memory_grid.dart';
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
      final features = ref.watch(circleFeaturesProvider);
      // Activity is hidden until the server offers it.
      final badge = features.has(CircleFeature.activity)
          ? ref.watch(activityBadgeProvider)
          : 0;
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
        child: CustomScrollView(
          slivers: [
            const CircleFloatingHeader(),
            SliverPadding(
              padding: CircleInsets.page,
              sliver: SliverList.list(
                children: [
                  if (account != null)
                    ProfileHeader(
                      key: const ValueKey('you-profile-card'),
                      account: account,
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
                      subtitle:
                          'Mentions, replies, invitations and event updates',
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
                      subtitle: 'Your updates and quiet hours',
                      location: '/you/notifications',
                    ),
                  if (features.has(CircleFeature.blocking))
                    entry(
                      icon: Icons.lock_outline,
                      title: 'Privacy and blocking',
                      subtitle: 'Manage blocked people',
                      location: '/you/privacy',
                    ),
                  entry(
                    icon: Icons.mark_email_unread_outlined,
                    title: 'Invitations',
                    subtitle: 'Choose which circles to join',
                    location: '/you/invitations',
                  ),
                  entry(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Account',
                    subtitle: 'Appearance, connection and sign out',
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
                      (
                        Icons.location_city_outlined,
                        'Lives in',
                        account.currentCity,
                      ),
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
                  const CircleSectionTitle('Your Memories'),
                  MemoryGrid(
                    memories: [
                      for (final memory in workspace.memories)
                        if (memory.authorId == workspace.viewer) memory,
                    ],
                    empty: workspace.hasMoreMemories
                        ? 'Your Memories may be in older items. Load more below.'
                        : 'Memories you share appear here.',
                  ),
                  if (workspace.hasMoreMemories)
                    TextButton.icon(
                      onPressed: () => runCalmly(
                        context,
                        () => ref
                            .read(circleWorkspaceProvider.notifier)
                            .loadMoreMemories(),
                      ),
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Load older Memories'),
                    ),
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
            ),
          ],
        ),
      );
    },
  );
}

/// H5: appearance, password and devices, the connection and logging out.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(circleFeaturesProvider);
    return ReadingPane(
      child: ListView(
        padding: CircleInsets.form,
        children: [
          CircleHeading(
            title: 'Account',
            subtitle: 'How CIRCLE looks, and your account.',
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
          ...[
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/you/account/password'),
            ),
            ListTile(
              leading: const Icon(Icons.devices_outlined),
              title: const Text('Your devices'),
              subtitle: const Text('Locations and session logout'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/you/account/sessions'),
            ),
            ExpansionTile(
              title: const Text('Connection details'),
              children: [
                ListTile(
                  title: const Text('Connected server'),
                  subtitle: Text(features.host),
                ),
              ],
            ),
          ],
          const SizedBox(height: Space.section),
          CircleEmpty(
            title: 'Quiet by design',
            message: features.has(CircleFeature.notificationSettings)
                ? 'Choose which updates reach you in Notifications. CIRCLE never uploads your contacts. Logging out removes your session from this device.'
                : 'CIRCLE sends no notifications and never uploads your contacts. Logging out removes your session from this device.',
          ),
          const SizedBox(height: Space.md),
          OutlinedButton(
            onPressed: () => runCalmly(
              context,
              () => ref.read(circleWorkspaceProvider.notifier).logOut(),
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
