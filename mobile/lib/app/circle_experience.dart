import '../core/form_exit_guard.dart';
import '../features/polls/presentation/live_polls.dart';
import '../features/profile/presentation/account_security_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api/api_providers.dart';
import '../core/circle_brand.dart';
import '../core/circle_components.dart';
import '../core/design.dart';
import '../core/invite_entry.dart';
import '../core/theme_controller.dart';
import '../core/two_pane.dart';
import '../features/albums/presentation/album_detail.dart';
import '../features/auth/domain/access_validation.dart';
import '../features/auth/presentation/access_design.dart';
import '../features/chat/presentation/live_chats.dart';
import '../features/profile/presentation/server_blocking.dart';
import '../features/events/application/events_filter.dart';
import '../features/events/presentation/live_events.dart';
import '../features/groups/domain/membership_rules.dart';
import '../features/groups/presentation/circle_groups.dart';
import '../features/groups/presentation/group_detail.dart';
import '../features/groups/presentation/group_invite.dart';
import '../features/groups/presentation/contact_invite_screen.dart';
import '../features/groups/presentation/contact_invitation_inbox.dart';
import '../features/groups/presentation/group_reports.dart';
import '../features/groups/presentation/group_settings.dart';
import '../features/groups/presentation/invite_link_screen.dart';
import '../features/memories/application/home_filter.dart';
import '../features/memories/presentation/circle_memories.dart';
import '../features/notifications/presentation/activity_screen.dart';
import '../features/notifications/presentation/server_push_settings.dart';
import '../features/notifications/presentation/push_presentation_host.dart';
import '../features/profile/presentation/circle_you.dart';
import '../features/profile/presentation/profile_edit.dart';
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
        '/polls',
        '/polls/new',
        '/chats/new',
        '/you/privacy',
        '/you/notifications',
        '/you/account',
        '/you/account/password',
        '/you/account/sessions',
        '/you/invitations',
        '/activity',
        '/search',
      }.contains(path) ||
      RegExp(
        r'^/(home/memory|chats/g|chats/c|groups/g|invite|events/e|polls/p)/[A-Za-z0-9_-]+$',
      ).hasMatch(path) ||
      RegExp(r'^/polls/p/[A-Za-z0-9_-]+/voters$').hasMatch(path) ||
      RegExp(r'^/you/invitations/[A-Za-z0-9_-]+$').hasMatch(path) ||
      RegExp(r'^/groups/g/[A-Za-z0-9_-]+/invite/link$').hasMatch(path) ||
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

String circleDetailTitle(String path, String fallback) {
  if (path.endsWith('/photos')) return 'Photos';
  if (path == '/you/edit') return 'Edit profile';
  if (path.endsWith('/notifications')) return 'Notifications';
  if (path.endsWith('/sessions')) return 'Your devices';
  if (path.endsWith('/password')) return 'Change password';
  if (path.endsWith('/account')) return 'Account';
  if (path.contains('/invitations')) return 'Invitations';
  if (path == '/chats/privacy') return 'Messaging privacy';
  if (path == '/chats/new') return 'New chat';
  if (path == '/groups/new') return 'New group';
  if (path.endsWith('/settings')) return 'Group settings';
  if (path.endsWith('/invite/link')) return 'Invite link';
  if (path.endsWith('/invite')) return 'Invite people';
  if (path.endsWith('/reports')) return 'Group reports';
  if (path == '/events/new') return 'New event';
  if (path.startsWith('/events/') && path.endsWith('/edit')) {
    return 'Edit event';
  }
  if (path.endsWith('/attendees')) return 'Attendees';
  if (path.startsWith('/events/e/')) return 'Event';
  if (path.startsWith('/groups/g/')) return 'Group';
  return fallback;
}

/// A full-screen page outside the tabs (search, activity, a profile), with
/// Back to wherever the person came from.
Widget _page(BuildContext context, String title, Widget child) => Scaffold(
  appBar: AppBar(
    title: Text(title),
    leading: BackButton(
      onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
    ),
  ),
  body: SafeArea(
    child: CirclePageTitle(title: title, child: child),
  ),
);

/// Shows [child] only where the server offers [feature] (see
/// [CircleFeatureGate]).
Widget _gate(CircleFeature feature, Widget child) =>
    CircleFeatureGate(feature: feature, child: child);

Widget _chatsPane([String? id]) =>
    _gate(CircleFeature.liveChat, LiveChatsScreen(key: ValueKey(id), id: id));

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

Widget _eventsPane([String? id, String? group]) => _gate(
  CircleFeature.liveEvents,
  LiveEventsScreen(key: ValueKey(id), id: id, group: group),
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
      GoRoute(path: '/', builder: (_, _) => const _Welcome()),
      GoRoute(
        path: '/register',
        builder: (_, state) => AccessForm(
          registering: true,
          next: circleReturnDestination(state.uri.queryParameters['next']),
          connectedTo: server?.host,
          onSubmit: submit,
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, state) => AccessForm(
          registering: false,
          next: circleReturnDestination(state.uri.queryParameters['next']),
          connectedTo: server?.host,
          onSubmit: submit,
          notice: ref.read(serverSessionProvider).notice,
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
        path: '/polls',
        builder: (context, state) => _page(
          context,
          'Polls',
          _gate(
            CircleFeature.livePolls,
            LivePollScreen(
              group: state.uri.queryParameters['group'],
              event: state.uri.queryParameters['event'],
            ),
          ),
        ),
        routes: [
          GoRoute(
            path: 'new',
            onExit: (context, state) => ref.read(serverAccountProvider) == null
                ? true
                : confirmCircleFormExit(context, state.uri.path),
            builder: (context, state) => _page(
              context,
              'New poll',
              _gate(
                CircleFeature.livePolls,
                LivePollForm(
                  key: ValueKey(
                    '${ref.watch(serverAccountProvider)?.id}:${ref.watch(apiClientProvider)?.sessionRevision}',
                  ),
                  group: state.uri.queryParameters['group'],
                  event: state.uri.queryParameters['event'],
                ),
              ),
            ),
          ),
          GoRoute(
            path: 'p/:id',
            builder: (context, state) => _page(
              context,
              'Poll',
              _gate(
                CircleFeature.livePolls,
                _idRoute(state, (id) => LivePollScreen(id: id)),
              ),
            ),
            routes: [
              GoRoute(
                path: 'voters',
                builder: (context, state) => _page(
                  context,
                  'Who voted',
                  _gate(
                    CircleFeature.livePolls,
                    _idRoute(state, (id) => LivePollVoters(id: id)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/photos',
        builder: (context, state) =>
            _page(context, 'Photos', const CirclePhotos()),
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
          path: state.uri.path,
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
                    path: 'privacy',
                    builder: (_, _) => _gate(
                      CircleFeature.liveChat,
                      const LiveChatPrivacyScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'new',
                    onExit: (context, state) =>
                        ref.read(serverAccountProvider) == null
                        ? true
                        : confirmCircleFormExit(context, state.uri.path),
                    builder: (_, _) => _gate(
                      CircleFeature.liveChat,
                      const LiveChatsScreen(contacts: true),
                    ),
                  ),
                  GoRoute(
                    path: 'c/:id',
                    builder: (_, state) => _idRoute(state, _chatsPane),
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
                    onExit: (context, state) =>
                        ref.read(serverAccountProvider) == null
                        ? true
                        : confirmCircleFormExit(context, state.uri.path),
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
                        onExit: (context, state) =>
                            ref.read(serverAccountProvider) == null
                            ? true
                            : confirmCircleFormExit(context, state.uri.path),
                        builder: (_, state) => _idRoute(
                          state,
                          (id) => GroupSettingsScreen(groupId: id),
                        ),
                      ),
                      GoRoute(
                        path: 'invite',
                        routes: [
                          GoRoute(
                            path: 'link',
                            builder: (_, state) => _idRoute(
                              state,
                              (id) => GroupInviteScreen(groupId: id),
                            ),
                          ),
                        ],
                        builder: (_, state) => _idRoute(
                          state,
                          (id) => ContactInviteScreen(groupId: id),
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
                builder: (_, state) =>
                    _eventsPane(null, state.uri.queryParameters['group']),
                routes: [
                  GoRoute(
                    path: 'new',
                    onExit: (context, state) =>
                        ref.read(serverAccountProvider) == null
                        ? true
                        : confirmCircleFormExit(context, state.uri.path),
                    builder: (_, state) => LiveEventForm(
                      group: state.uri.queryParameters['group'],
                    ),
                  ),
                  GoRoute(
                    path: 'e/:id',
                    builder: (_, state) => _idRoute(state, _eventsPane),
                    routes: [
                      GoRoute(
                        path: 'attendees',
                        builder: (_, state) => _idRoute(
                          state,
                          (id) => LiveAttendeesScreen(id: id),
                        ),
                      ),
                      GoRoute(
                        path: 'edit',
                        onExit: (context, state) =>
                            ref.read(serverAccountProvider) == null
                            ? true
                            : confirmCircleFormExit(context, state.uri.path),
                        builder: (_, state) =>
                            _idRoute(state, (id) => LiveEventForm(id: id)),
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
                    path: 'invitations',
                    builder: (_, _) => const ContactInvitationInbox(),
                    routes: [
                      GoRoute(
                        path: ':invitationId',
                        builder: (_, state) => ContactInvitationInbox(
                          invitationId: state.pathParameters['invitationId'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'edit',
                    onExit: (context, state) =>
                        ref.read(serverAccountProvider) == null
                        ? true
                        : confirmCircleFormExit(context, state.uri.path),
                    builder: (_, _) => const ProfileEditScreen(),
                  ),
                  GoRoute(
                    path: 'privacy',
                    builder: (_, _) => _gate(
                      CircleFeature.blocking,
                      const ServerBlockingScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (_, _) => _gate(
                      CircleFeature.notificationSettings,
                      const ServerPushSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'account',
                    routes: [
                      GoRoute(
                        path: 'password',
                        builder: (_, _) => const ChangePasswordScreen(),
                      ),
                      GoRoute(
                        path: 'sessions',
                        builder: (_, _) => const SessionsScreen(),
                      ),
                    ],
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
  const _Welcome();
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
    return AccessWelcome(connectedTo: ref.watch(apiConfigProvider)?.host);
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
    builder: (context, child) => PushPresentationHost(
      onOpen: (path) => ref.read(circleRouterProvider).go(path),
      child: child!,
    ),
  );
}

/// Navigation labels stay readable but stop growing beyond this scale, so
/// the bar never takes over the screen at very large text sizes.
const navigationMaxTextScale = 1.3;

class CircleAppShell extends ConsumerStatefulWidget {
  const CircleAppShell({
    super.key,
    required this.shell,
    required this.detail,
    this.path = '',
  });
  final StatefulNavigationShell shell;

  /// True when a detail page (not a branch root) is showing.
  final bool detail;

  /// The current location, for pages that draw their own top bar.
  final String path;

  @override
  ConsumerState<CircleAppShell> createState() => _CircleAppShellState();
}

class _CircleAppShellState extends ConsumerState<CircleAppShell> {
  bool _navigationVisible = true;
  double _travel = 0;
  double _restoreTravel = 0;

  @override
  void didUpdateWidget(covariant CircleAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _navigationVisible = true;
      _travel = 0;
    }
  }

  bool _scroll(ScrollNotification notification) {
    if (widget.detail ||
        notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical ||
        MediaQuery.accessibleNavigationOf(context)) {
      return false;
    }
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      final delta = notification.scrollDelta ?? 0;
      if (delta == 0) return false;
      if ((_travel > 0) != (delta > 0)) _travel = 0;
      _travel += delta;
      final show = notification.metrics.pixels <= 0 || _travel < -Space.md;
      final hide =
          notification.metrics.pixels > kToolbarHeight && _travel > Space.lg;
      if (show && !_navigationVisible) {
        setState(() => _navigationVisible = true);
      }
      if (hide && _navigationVisible) {
        setState(() => _navigationVisible = false);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell, detail = widget.detail, path = widget.path;

    final index = shell.currentIndex;
    final largeText =
        MediaQuery.textScalerOf(context).scale(1) >
        CircleLayout.largeTextThreshold;
    final filter = ref.watch(homeGroupFilterProvider);
    final eventsFilter = ref.watch(eventsGroupFilterProvider);
    final workspace = ref.watch(circleWorkspaceProvider).value;
    final features = ref.watch(circleFeaturesProvider);
    // "New event" only when the viewer may create an event somewhere.
    final canCreateEvent =
        features.has(CircleFeature.liveEvents) &&
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
            1 when features.has(CircleFeature.liveChat) => (
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
    const titles = ['Memories', 'Chats', 'Circles', 'Events', 'Profile'];
    // Like WhatsApp, an open live conversation is full screen: it draws its
    // own bar (back, photo, name, options) and hides the tab dock.
    if (RegExp(r'^/chats/c/[^/]+$').hasMatch(path)) {
      return Scaffold(body: SafeArea(child: shell));
    }
    final bottomNav = AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      alignment: Alignment.bottomCenter,
      child:
          detail ||
              _navigationVisible ||
              MediaQuery.accessibleNavigationOf(context)
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  0,
                  Space.lg,
                  Space.sm,
                ),
                child: DecoratedBox(
                  decoration: CircleDepth.dock(context),
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: navigationMaxTextScale,
                    child: SizedBox(
                      height: 64,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _DockTab(
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home_rounded,
                            label: 'Home',
                            selected: index == 0,
                            onTap: () => shell.goBranch(0),
                          ),
                          _DockTab(
                            icon: Icons.groups_outlined,
                            activeIcon: Icons.groups_rounded,
                            label: 'Circles',
                            selected: index == 2,
                            onTap: () => shell.goBranch(2),
                          ),
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: Material(
                              color: theme.colorScheme.primary,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () =>
                                    context.push(composeLocation(filter)),
                                child: Icon(
                                  Icons.add,
                                  color: theme.colorScheme.onPrimary,
                                  size: 28,
                                  semanticLabel: 'Create',
                                ),
                              ),
                            ),
                          ),
                          _DockTab(
                            icon: Icons.event_outlined,
                            activeIcon: Icons.event,
                            label: 'Events',
                            selected: index == 3,
                            onTap: () => shell.goBranch(3),
                          ),
                          _DockTab(
                            icon: Icons.person_outline,
                            activeIcon: Icons.person_rounded,
                            label: 'Profile',
                            selected: index == 4,
                            onTap: () => shell.goBranch(4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );

    // Detail pages keep a traditional AppBar with Back.
    if (detail) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: Space.hero * 2 + Space.sm,
          titleSpacing: 0,
          title: Semantics(
            header: true,
            child: Text(
              circleDetailTitle(path, titles[index]),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: theme.textTheme.titleLarge,
            ),
          ),
          leading: BackButton(
            onPressed: () => context.canPop()
                ? context.pop()
                : shell.goBranch(index, initialLocation: true),
          ),
        ),
        body: SafeArea(
          child: CirclePageTitle(
            title: circleDetailTitle(path, titles[index]),
            child: shell,
          ),
        ),
        bottomNavigationBar:
            (path.endsWith('/edit') ||
                path.endsWith('/new') ||
                path.endsWith('/settings') ||
                path.endsWith('/photos') ||
                path.contains('/account/'))
            ? null
            : bottomNav,
      );
    }

    // Root tab pages: no AppBar — each screen draws its own scroll-aware
    // SliverAppBar. The shell passes header data via CircleTabHeaderData.
    final logo = index == 0
        ? Container(
            width: Space.large,
            height: Space.large,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(CircleRadius.small),
            ),
            child: Icon(
              Icons.all_inclusive,
              color: theme.colorScheme.primary,
              semanticLabel: CircleIdentity.name,
            ),
          )
        : null;
    return Scaffold(
      body: Listener(
        onPointerMove: (event) {
          // Restore navigation even if a refresh replaces the scroller with
          // an error/empty panel. Observe pointers without stealing gestures.
          if (_navigationVisible || detail) return;
          if (event.delta.dy > event.delta.dx.abs()) {
            _restoreTravel += event.delta.dy;
            if (_restoreTravel > Space.md) {
              setState(() {
                _navigationVisible = true;
                _restoreTravel = 0;
              });
            }
          } else {
            _restoreTravel = 0;
          }
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: _scroll,
          child: SafeArea(
            top: false,
            child: CircleTabHeaderData(
              title: index == 0 ? 'Circle' : titles[index],
              titleStyle: largeText
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.headlineMedium,
              logo: logo,
              actions: [
                const SearchButton(),
                const ActivityBell(),
                if (features.has(CircleFeature.liveChat))
                  IconButton(
                    tooltip: 'Chats',
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () => shell.goBranch(1),
                  ),
              ],
              fab: fab,
              child: shell,
            ),
          ),
        ),
      ),
      bottomNavigationBar: bottomNav,
    );
  }
}

class _DockTab extends StatelessWidget {
  const _DockTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon, activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : CircleAccents.of(context).caption;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
