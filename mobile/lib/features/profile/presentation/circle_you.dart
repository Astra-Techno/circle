import 'dart:async';
import 'package:flutter/material.dart';
import '../../memories/presentation/memory_grid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/design/circle_typography.dart';
import '../../../core/theme_controller.dart';
import 'profile_photo.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
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
      }) => CircleSurfaceCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: CircleInitialAvatar(icon: icon),
          title: Text(
            title,
            style: CircleTextStyles.homeAuthor(
              Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: CircleTextStyles.metadata(CircleAccents.of(context).caption),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [?badgeLabel, const Icon(LucideIcons.chevron_right)],
          ),
          onTap: () => context.push(location),
        ),
      );
      return ReadingPane(
        child: CustomScrollView(
          slivers: [
            const CircleFloatingHeader(),
            SliverPadding(
              padding: CircleInsets.rootPage,
              sliver: SliverList.list(
                children: [
                  if (account != null)
                    CircleSurfaceCard(
                      child: ProfileHeader(
                        key: const ValueKey('you-profile-card'),
                        account: account,
                      ),
                    ),
                  const SizedBox(height: Space.md),
                  if (waiting > 0)
                    CircleSurfaceCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: const CircleInitialAvatar(
                          icon: LucideIcons.mail,
                        ),
                        title: Text(
                          waiting == 1
                              ? '1 invitation waiting'
                              : '$waiting invitations waiting',
                        ),
                        subtitle: const Text('Review them in Groups.'),
                        trailing: const Icon(LucideIcons.chevron_right),
                        onTap: () => context.go('/groups'),
                      ),
                    ),
                  if (features.has(CircleFeature.activity))
                    entry(
                      icon: LucideIcons.bell,
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
                      icon: LucideIcons.sliders_horizontal,
                      title: 'Notifications',
                      subtitle: 'Your updates and quiet hours',
                      location: '/you/notifications',
                    ),
                  if (features.has(CircleFeature.blocking))
                    entry(
                      icon: LucideIcons.lock,
                      title: 'Privacy and blocking',
                      subtitle: 'Manage blocked people',
                      location: '/you/privacy',
                    ),
                  entry(
                    icon: LucideIcons.mail,
                    title: 'Invitations',
                    subtitle: 'Choose which circles to join',
                    location: '/you/invitations',
                  ),
                  entry(
                    icon: LucideIcons.user_cog,
                    title: 'Account',
                    subtitle: 'Appearance, connection and sign out',
                    location: '/you/account',
                  ),
                  const SizedBox(height: Space.md),
                  if (account != null) ...[
                    if (_loadError != null)
                      TextButton.icon(
                        onPressed: _refreshProfile,
                        icon: const Icon(LucideIcons.refresh_cw),
                        label: const Text('Retry loading profile details'),
                      ),
                    const CircleSectionTitle('Personal details'),
                    const CirclePill('Only you', icon: LucideIcons.lock),
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
                      (LucideIcons.building, 'Lives in', account.currentCity),
                      (LucideIcons.house, 'From', account.hometown),
                      (LucideIcons.briefcase, 'Work', account.work),
                      (
                        LucideIcons.graduation_cap,
                        'Education',
                        account.education,
                      ),
                    ])
                      if (detail.$3.isNotEmpty)
                        CircleSurfaceCard(
                          padding: EdgeInsets.zero,
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
                      icon: const Icon(LucideIcons.chevron_down),
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
                              icon: LucideIcons.bookmark,
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
                            icon: const Icon(LucideIcons.images),
                            label: const Text('Browse Memories'),
                            onPressed: () => context.go('/home'),
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (_, memory) => CircleSurfaceCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        title: Text(
                          memory.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(LucideIcons.chevron_right),
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
              leading: const Icon(LucideIcons.lock),
              title: const Text('Change password'),
              trailing: const Icon(LucideIcons.chevron_right),
              onTap: () => context.push('/you/account/password'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.monitor_smartphone),
              title: const Text('Your devices'),
              subtitle: const Text('Locations and session logout'),
              trailing: const Icon(LucideIcons.chevron_right),
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
