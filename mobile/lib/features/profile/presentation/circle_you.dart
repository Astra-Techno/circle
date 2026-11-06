import '../../../core/design/circle_icons.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../memories/presentation/memory_card.dart';
import '../../groups/domain/group_tree.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/circle_brand.dart';
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
  int _memoryTab = 0;
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
            children: [?badgeLabel, const Icon(CircleIcons.chevronRight)],
          ),
          onTap: () => context.push(location),
        ),
      );
      return ReadingPane(
        child: CustomScrollView(
          slivers: [
            const CircleFloatingHeader(),
            if (account != null)
              SliverToBoxAdapter(
                child: ProfileHeader(
                  key: const ValueKey('you-profile-card'),
                  account: account,
                ),
              ),
            SliverPadding(
              padding: CircleInsets.rootPage.copyWith(left: 0, right: 0),
              sliver: SliverList.list(
                children: [
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
                        subtitle: const Text('Review them in Circles.'),
                        trailing: const Icon(CircleIcons.chevronRight),
                        onTap: () => context.go('/groups'),
                      ),
                    ),
                  DefaultTabController(
                    length: 2,
                    initialIndex: _memoryTab,
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      onTap: (index) => setState(() => _memoryTab = index),
                      tabs: const [
                        Tab(text: 'Your Memories'),
                        Tab(text: 'Saved'),
                      ],
                    ),
                  ),
                  if (_memoryTab == 0) ...[
                    for (final memory in workspace.memories.where(
                      (memory) => memory.authorId == workspace.viewer,
                    ))
                      if (workspace.group(memory.groupId) case final group?)
                        CircleMemoryCard(
                          key: ValueKey('profile-${memory.id}'),
                          memory: memory,
                          group: group,
                          audience: audiencePath(group, workspace.groupsById),
                        ),
                    if (!workspace.memories.any(
                      (memory) => memory.authorId == workspace.viewer,
                    ))
                      CircleEmpty(
                        title: 'Your Memories',
                        message: workspace.hasMoreMemories
                            ? 'Your Memories may be in older items. Load more below.'
                            : 'Memories you share appear here.',
                        action: TextButton.icon(
                          onPressed: () => context.go('/home'),
                          icon: const Icon(CircleIcons.home),
                          label: const Text('Browse Memories'),
                        ),
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
                  ],
                  if (_memoryTab == 1)
                    ScopedMemoryList(
                      query: const MemoryQuery(saved: true),
                      empty: CircleEmpty(
                        icon: LucideIcons.bookmark,
                        title: 'Keep a Memory close',
                        message:
                            'Save a Memory to find it here later. Only you see your saved list.',
                        action: TextButton.icon(
                          onPressed: () => context.go('/home'),
                          icon: const Icon(CircleIcons.home),
                          label: const Text('Browse Memories'),
                        ),
                      ),
                      itemBuilder: (_, memory) {
                        final group = workspace.group(memory.groupId);
                        if (group == null) return const SizedBox.shrink();
                        return CircleMemoryCard(
                          key: ValueKey('saved-${memory.id}'),
                          memory: memory,
                          group: group,
                          audience: audiencePath(group, workspace.groupsById),
                        );
                      },
                    ),
                  const SizedBox(height: Space.md),
                  CircleSurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
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
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  if (account != null)
                    Padding(
                      padding: CircleInsets.content,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_loadError != null)
                            TextButton.icon(
                              onPressed: _refreshProfile,
                              icon: const Icon(LucideIcons.refresh_cw),
                              label: const Text(
                                'Retry loading profile details',
                              ),
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
                            (
                              LucideIcons.building,
                              'Lives in',
                              account.currentCity,
                            ),
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
              trailing: const Icon(CircleIcons.chevronRight),
              onTap: () => context.push('/you/account/password'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.monitor_smartphone),
              title: const Text('Your devices'),
              subtitle: const Text('Locations and session logout'),
              trailing: const Icon(CircleIcons.chevronRight),
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
            icon: LucideIcons.lock,
            title: 'Quiet by design',
            message: features.has(CircleFeature.notificationSettings)
                ? 'Choose which updates reach you in Notifications. CIRCLE never uploads your contacts. Logging out removes your session from this device.'
                : 'Notification controls are unavailable in this build. CIRCLE never uploads your contacts. Logging out removes your session from this device.',
          ),
          const SizedBox(height: Space.md),
          OutlinedButton(
            onPressed: () => runCalmly(
              context,
              () => ref.read(circleWorkspaceProvider.notifier).logOut(),
            ),
            child: const Text('Log out'),
          ),
          const SizedBox(height: Space.md),
          Text(
            'Interface version: ${CircleIdentity.interfaceVersion}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
