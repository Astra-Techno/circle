import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api/api_providers.dart';
import '../core/circle_components.dart';
import '../core/design.dart';
import '../core/invite_entry.dart';
import '../core/theme_controller.dart';
import '../core/two_pane.dart';
import '../features/albums/presentation/album_detail.dart';
import '../features/auth/domain/access_validation.dart';
import '../features/auth/presentation/access_design.dart';
import '../features/chat/presentation/chat_conversation.dart';
import '../features/chat/presentation/chat_details.dart';
import '../features/chat/presentation/chat_photos.dart';
import '../features/chat/presentation/chat_inbox.dart';
import '../features/chat/presentation/chat_new.dart';
import '../features/chat/presentation/chat_privacy.dart';
import '../features/chat/presentation/chat_reply_privately.dart';
import '../features/events/presentation/circle_events.dart';
import '../features/groups/domain/membership_rules.dart';
import '../features/groups/presentation/circle_groups.dart';
import '../features/groups/presentation/group_detail.dart';
import '../features/groups/presentation/group_invite.dart';
import '../features/groups/presentation/group_reports.dart';
import '../features/groups/presentation/group_settings.dart';
import '../features/groups/presentation/invite_link_screen.dart';
import '../features/memories/application/home_filter.dart';
import '../features/memories/presentation/circle_memories.dart';
import '../features/notifications/presentation/activity_screen.dart';
import '../features/notifications/presentation/notification_settings.dart';
import '../features/profile/presentation/circle_you.dart';
import '../features/profile/presentation/person_profile.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/workspace/application/workspace_providers.dart';
import '../features/workspace/presentation/feature_gate.dart';

const _branchRoots = ['/home', '/chats', '/groups', '/events', '/you'];
final _idSegment = RegExp(r'^[A-Za-z0-9_-]+$');

/// Returns [input] when it is a safe in-app destination to resume after
/// entering the preview; otherwise null. Rejects schemes, hosts,
/// backslashes and unknown paths.
String? circleReturnDestination(String? input) {
  final uri = input == null ? null : Uri.tryParse(input);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      input!.contains(r'\')) {
    return null;
  }
  final path = uri.path;
  final allowed =
      {
        ..._branchRoots,
        '/groups/new',
        '/compose',
        '/events/new',
        '/chats/new',
        '/chats/archived',
        '/you/privacy',
        '/you/notifications',
        '/you/account',
        '/activity',
        '/search',
      }.contains(path) ||
      RegExp(
        r'^/(home/memory|chats/g|chats/c|chats/reply|groups/g|invite|events/e)/[A-Za-z0-9_-]+$',
      ).hasMatch(path) ||
      RegExp(r'^/chats/c/[A-Za-z0-9_-]+/details$').hasMatch(path) ||
      RegExp(
        r'^/chats/c/[A-Za-z0-9_-]+/photos/[A-Za-z0-9_-]+$',
      ).hasMatch(path) ||
      RegExp(r'^/events/e/[A-Za-z0-9_-]+/(attendees|edit)$').hasMatch(path) ||
      RegExp(
        r'^/groups/g/[A-Za-z0-9_-]+/(settings|invite|reports)$',
      ).hasMatch(path) ||
      RegExp(
        r'^/groups/g/[A-Za-z0-9_-]+/albums/[A-Za-z0-9_-]+(/photos)?$',
      ).hasMatch(path) ||
      RegExp(r'^/people/[A-Za-z0-9_-]+$').hasMatch(path) ||
      RegExp(r'^/home/memory/[A-Za-z0-9_-]+/photos$').hasMatch(path);
  return allowed ? uri.toString() : null;
}

/// Whether [path] is a detail page inside a shell branch (needs Back).
bool circleIsDetailPath(String path) => !_branchRoots.contains(path);

/// A full-screen page outside the tabs (search, activity, a profile), with
/// Back to wherever the person came from.
Widget _page(BuildContext context, String title, Widget child) => Scaffold(
  appBar: AppBar(
    title: Text(title),
    leading: BackButton(
      onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
    ),
  ),
  body: SafeArea(child: child),
);

/// Shows [child] only where the session has [feature] (see
/// [CircleFeatureGate]); the preview always does.
Widget _gate(CircleFeature feature, Widget child) =>
    CircleFeatureGate(feature: feature, child: child);

Widget _chatsPane([String? id]) => _gate(
  CircleFeature.chat,
  CircleAdaptivePane(
    kind: 'chats',
    initial: id,
    list: const ChatInboxScreen(),
    detail: (id) => ChatConversationScreen(key: ValueKey(id), id: id),
    placeholder: const CirclePanePlaceholder(
      title: 'Choose a chat',
      message: 'Pick a conversation on the left to read it here.',
    ),
  ),
);

Widget _groupsPane([String? id]) => CircleAdaptivePane(
  kind: 'groups',
  initial: id,
  list: const CircleGroups(),
  detail: (id) => CircleGroupDetail(key: ValueKey(id), id: id),
  placeholder: const CirclePanePlaceholder(
    title: 'Choose a group',
    message: 'Pick a group on the left to open its space here.',
  ),
);

Widget _eventsPane([String? id]) => _gate(
  CircleFeature.events,
  CircleAdaptivePane(
    kind: 'events',
    initial: id,
    list: const CircleEvents(),
    detail: (id) => CircleEventDetail(key: ValueKey(id), id: id),
    placeholder: const CirclePanePlaceholder(
      title: 'Choose an event',
      message: 'Pick an event on the left to see its details here.',
    ),
  ),
);

Widget _albumRoute(GoRouterState state, Widget Function(String id) builder) {
  final id = state.pathParameters['album'] ?? '';
  return _idSegment.hasMatch(id)
      ? builder(id)
      : const ReadingPane(
          child: CircleEmpty(
            title: 'This page is unavailable',
            message: 'Return to your circles.',
          ),
        );
}

Widget _idRoute(GoRouterState state, Widget Function(String id) builder) {
  final id = state.pathParameters['id'] ?? '';
  return _idSegment.hasMatch(id)
      ? builder(id)
      : const ReadingPane(
          child: CircleEmpty(
            title: 'This page is unavailable',
            message: 'Return to your circles.',
          ),
        );
}

final circleRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  late final GoRouter router;
  void enter(bool showcase) =>
      ref.read(circlePreviewSessionProvider.notifier).enter(showcase: showcase);
  // Server builds sign in for real; preview builds validate and discard.
  final server = ref.read(apiConfigProvider);
  final session = ref.read(serverSessionProvider.notifier);
  Future<String?> submit(AccessDetails details) => details.registering
      ? session.register(
          mobile: details.mobile,
          password: details.password,
          displayName: details.name,
        )
      : session.logIn(mobile: details.mobile, password: details.password);
  // A stored session the server refused (at start-up) also goes to log-in.
  ref.listen(serverSessionProvider.select((state) => state.notice), (
    previous,
    notice,
  ) {
    if (notice != null && notice != previous) router.go('/login');
  });
  ref.listen(circleSessionActiveProvider, (previous, entered) {
    if (previous == true && !entered) {
      ref.read(homeGroupFilterProvider.notifier).select(null);
      ref.read(eventsGroupFilterProvider.notifier).select(null);
      // A session the server ended goes to log-in with its calm notice.
      router.go(
        ref.read(serverSessionProvider).notice == null ? '/' : '/login',
      );
    }
    refresh.value++;
  });
  router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final invite = circleInviteDestination(
        state.uri,
        serverOrigin: server?.baseUrl,
      );
      if (invite != null && invite != state.uri.toString()) return invite;
      final entered = ref.read(circleSessionActiveProvider);
      final public = {'/', '/login', '/register'}.contains(state.uri.path);
      if (!entered && !public) {
        return Uri(
          path: '/login',
          queryParameters: {
            if (circleReturnDestination(state.uri.toString()) != null)
              'next': state.uri.toString(),
          },
        ).toString();
      }
      if (entered && public) {
        return circleReturnDestination(state.uri.queryParameters['next']) ??
            '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => _Welcome(onExploreDemo: () => enter(true)),
      ),
      GoRoute(
        path: '/register',
        builder: (_, state) => AccessForm(
          registering: true,
          next: circleReturnDestination(state.uri.queryParameters['next']),
          onPreviewComplete: () => enter(false),
          connectedTo: server?.host,
          onSubmit: server == null ? null : submit,
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, state) => AccessForm(
          registering: false,
          next: circleReturnDestination(state.uri.queryParameters['next']),
          onPreviewComplete: () => enter(false),
          connectedTo: server?.host,
          onSubmit: server == null ? null : submit,
          notice: server == null
              ? null
              : ref.read(serverSessionProvider).notice,
        ),
      ),
      GoRoute(
        path: '/compose',
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            title: const Text('New Memory'),
            leading: BackButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
          ),
          body: SafeArea(
            child: CircleCompose(
              initialGroupId: state.uri.queryParameters['group'],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/search',
        builder: (context, _) => _page(context, 'Search', const SearchScreen()),
      ),
      GoRoute(
        path: '/activity',
        builder: (context, _) => _page(
          context,
          'Activity',
          _gate(CircleFeature.activity, const ActivityScreen()),
        ),
      ),
      GoRoute(
        path: '/people/:id',
        builder: (context, state) => _page(
          context,
          'Profile',
          _idRoute(
            state,
            (id) => PersonProfileScreen(
              person: id,
              groupId: state.uri.queryParameters['group'],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (_, state) =>
            InviteLinkScreen(token: state.pathParameters['token']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, state, shell) => CircleAppShell(
          shell: shell,
          detail: circleIsDetailPath(state.uri.path),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => const CircleHome(),
                routes: [
                  GoRoute(
                    path: 'memory/:id',
                    builder: (_, state) =>
                        _idRoute(state, (id) => CircleMemoryDetail(id: id)),
                    routes: [
                      GoRoute(
                        path: 'photos',
                        builder: (_, state) => _idRoute(
                          state,
                          (id) => MemoryPhotoViewer(
                            memoryId: id,
                            initialIndex:
                                int.tryParse(
                                  state.uri.queryParameters['index'] ?? '',
                                ) ??
                                0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chats',
                builder: (_, _) => _chatsPane(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, _) =>
                        _gate(CircleFeature.chat, const NewChatScreen()),
                  ),
                  GoRoute(
                    path: 'archived',
                    builder: (_, _) =>
                        _gate(CircleFeature.chat, const ChatArchivedScreen()),
                  ),
                  // A group's chat, from its group space.
                  GoRoute(
                    path: 'g/:id',
                    redirect: (_, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return _idSegment.hasMatch(id)
                          ? '/chats/c/g-$id'
                          : '/chats';
                    },
                  ),
                  GoRoute(
                    path: 'reply/:id',
                    builder: (_, state) => _gate(
                      CircleFeature.chat,
                      _idRoute(
                        state,
                        (id) =>
                            ChatReplyPrivately(key: ValueKey(id), memoryId: id),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'c/:id',
                    builder: (_, state) => _idRoute(state, _chatsPane),
                    routes: [
                      GoRoute(
                        path: 'details',
                        builder: (_, state) => _gate(
                          CircleFeature.chat,
                          _idRoute(state, (id) => ChatDetailsScreen(id: id)),
                        ),
                      ),
                      GoRoute(
                        path: 'photos/:message',
                        builder: (_, state) => _gate(
                          CircleFeature.chat,
                          _idRoute(state, (id) {
                            final message =
                                state.pathParameters['message'] ?? '';
                            return _idSegment.hasMatch(message)
                                ? ChatPhotoViewer(
                                    conversationId: id,
                                    messageId: message,
                                    initialIndex:
                                        int.tryParse(
                                          state.uri.queryParameters['index'] ??
                                              '',
                                        ) ??
                                        0,
                                  )
                                : const ReadingPane(
                                    child: CircleEmpty(
                                      title: 'This page is unavailable',
                                      message: 'Return to your circles.',
                                    ),
                                  );
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/groups',
                builder: (_, _) => _groupsPane(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, state) => CircleCreateGroup(
                      parentId: state.uri.queryParameters['parent'],
                    ),
                  ),
                  GoRoute(
                    path: 'g/:id',
                    builder: (_, state) => _idRoute(state, _groupsPane),
                    routes: [
                      GoRoute(
                        path: 'reports',
                        builder: (_, state) => _gate(
                          CircleFeature.moderation,
                          _idRoute(
                            state,
                            (id) => GroupReportsScreen(groupId: id),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'albums/:album',
                        builder: (_, state) => _gate(
                          CircleFeature.albums,
                          _idRoute(
                            state,
                            (id) => _albumRoute(
                              state,
                              (album) => AlbumDetailScreen(
                                groupId: id,
                                albumId: album,
                              ),
                            ),
                          ),
                        ),
                        routes: [
                          GoRoute(
                            path: 'photos',
                            builder: (_, state) => _gate(
                              CircleFeature.albums,
                              _idRoute(
                                state,
                                (id) => _albumRoute(
                                  state,
                                  (album) => AlbumPhotoViewer(
                                    groupId: id,
                                    albumId: album,
                                    initialIndex:
                                        int.tryParse(
                                          state.uri.queryParameters['index'] ??
                                              '',
                                        ) ??
                                        0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'settings',
                        builder: (_, state) => _idRoute(
                          state,
                          (id) => GroupSettingsScreen(groupId: id),
                        ),
                      ),
                      GoRoute(
                        path: 'invite',
                        builder: (_, state) => _idRoute(
                          state,
                          (id) => GroupInviteScreen(groupId: id),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/events',
                builder: (_, _) => _eventsPane(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, state) => EventFormScreen(
                      initialGroupId: state.uri.queryParameters['group'],
                    ),
                  ),
                  GoRoute(
                    path: 'e/:id',
                    builder: (_, state) => _idRoute(state, _eventsPane),
                    routes: [
                      GoRoute(
                        path: 'attendees',
                        builder: (_, state) =>
                            _idRoute(state, (id) => EventAttendees(id: id)),
                      ),
                      GoRoute(
                        path: 'edit',
                        builder: (_, state) => _idRoute(
                          state,
                          (id) => EventFormScreen(eventId: id),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/you',
                builder: (_, _) => const CircleYou(),
                routes: [
                  GoRoute(
                    path: 'privacy',
                    builder: (_, _) =>
                        _gate(CircleFeature.privacy, const ChatPrivacyScreen()),
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (_, _) => _gate(
                      CircleFeature.notificationSettings,
                      const NotificationSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'account',
                    builder: (_, _) => const AccountScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, _) => Scaffold(
      body: SafeArea(
        child: CircleEmpty(
          title: 'This page is unavailable',
          message: 'Return to your circles.',
          action: TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Go home'),
          ),
        ),
      ),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// The welcome page, or a calm moment while a stored session is checked.
class _Welcome extends ConsumerWidget {
  const _Welcome({required this.onExploreDemo});
  final VoidCallback onExploreDemo;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(serverSessionProvider.select((s) => s.restoring))) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Semantics(
              label: 'Opening CIRCLE',
              child: const CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }
    return AccessWelcome(
      onExploreDemo: onExploreDemo,
      connectedTo: ref.watch(apiConfigProvider)?.host,
    );
  }
}

class CircleExperience extends ConsumerWidget {
  const CircleExperience({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'CIRCLE',
    debugShowCheckedModeBanner: false,
    theme: circleTheme(Brightness.light),
    darkTheme: circleTheme(Brightness.dark),
    themeMode: ref.watch(themeProvider),
    routerConfig: ref.watch(circleRouterProvider),
  );
}

/// Navigation labels stay readable but stop growing beyond this scale, so
/// the bar never takes over the screen at very large text sizes.
const navigationMaxTextScale = 1.3;

class CircleAppShell extends ConsumerWidget {
  const CircleAppShell({super.key, required this.shell, required this.detail});
  final StatefulNavigationShell shell;

  /// True when a detail page (not a branch root) is showing.
  final bool detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = shell.currentIndex;
    final textScale = math.min(
      MediaQuery.textScalerOf(context).scale(1),
      navigationMaxTextScale,
    );
    final filter = ref.watch(homeGroupFilterProvider);
    final eventsFilter = ref.watch(eventsGroupFilterProvider);
    final workspace = ref.watch(circleWorkspaceProvider).value;
    final features = ref.watch(circleFeaturesProvider);
    final branches = [
      0,
      if (features.has(CircleFeature.chat)) 1,
      2,
      if (features.has(CircleFeature.events)) 3,
      4,
    ];
    // "New event" only when the viewer may create an event somewhere.
    final canCreateEvent =
        features.has(CircleFeature.events) &&
        (workspace?.groups.any(
              (group) => MembershipRules.canCreateEvent(
                group,
                workspace.viewer,
              ).allowed,
            ) ??
            false);
    final fab = detail
        ? null
        : switch (index) {
            0 => (label: 'Create Memory', location: composeLocation(filter)),
            1 when features.has(CircleFeature.chat) => (
              label: 'New chat',
              location: '/chats/new',
            ),
            2 => (label: 'New group', location: '/groups/new'),
            3 when canCreateEvent => (
              label: 'New event',
              location: eventCreateLocation(eventsFilter),
            ),
            _ => null,
          };
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    const titles = ['Memories', 'Chats', 'Groups', 'Events', 'You'];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: detail ? 0 : Space.lg,
        // The prototype label lives here once, instead of on every control.
        title: Row(
          children: [
            if (!detail) ...[
              Semantics(
                button: true,
                label: 'Open You',
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => shell.goBranch(4),
                  child: CircleInitialAvatar(
                    name:
                        ref.watch(serverAccountProvider)?.displayName ?? 'You',
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    features.server ? 'CIRCLE' : 'CIRCLE • PREVIEW',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: accents.calmText,
                    ),
                  ),
                  Text(
                    titles[index],
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
        // Search and the activity bell on every tab's main page (§4.1).
        actions: detail
            ? null
            : const [SearchButton(), ActivityBell(), SizedBox(width: Space.xs)],
        leading: detail
            ? BackButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : shell.goBranch(index, initialLocation: true),
              )
            : null,
      ),
      body: SafeArea(child: shell),
      floatingActionButton: fab == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(fab.location),
              icon: const Icon(Icons.add),
              label: Text(fab.label),
            ),
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: navigationMaxTextScale,
        child: NavigationBar(
          height: 60 + 12 * textScale,
          selectedIndex: branches.contains(index) ? branches.indexOf(index) : 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (target) => shell.goBranch(
            branches[target],
            initialLocation: branches[target] == index,
          ),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            if (features.has(CircleFeature.chat))
              NavigationDestination(
                icon: Icon(Icons.forum_outlined),
                label: 'Chats',
              ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              label: 'Groups',
            ),
            if (features.has(CircleFeature.events))
              NavigationDestination(
                icon: Icon(Icons.event_outlined),
                label: 'Events',
              ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'You',
            ),
          ],
        ),
      ),
    );
  }
}
