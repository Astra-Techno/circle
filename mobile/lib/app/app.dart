import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design.dart';
import '../features/auth/presentation/welcome.dart';
import '../features/feed/presentation/feed_screens.dart';
import '../features/community/domain/entry.dart';
import '../features/community/presentation/community_screens.dart';
import 'session.dart';
import 'route_policy.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  late final GoRouter router;
  ref.listen(sessionProvider, (previous, entered) {
    if (previous == true && !entered) {
      // Ending a session discards pending return destinations and old pages.
      router.go('/invite');
    }
    refresh.value++;
  });
  router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) => invitationRedirect(
      entered: ref.read(sessionProvider),
      location: state.uri,
    ),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/invite', builder: (_, _) => const InvitationScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            CircleShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/feed', builder: (_, _) => const FeedScreen()),
          GoRoute(path: '/create', builder: (_, _) => const CreatePostScreen()),
          GoRoute(
            path: '/post/:id',
            builder: (_, state) =>
                FeedScreen(postId: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/groups',
            builder: (_, _) => const CommunityScreen(kind: EntryKind.group),
          ),
          GoRoute(
            path: '/memories',
            builder: (_, _) => const CommunityScreen(kind: EntryKind.album),
          ),
          GoRoute(
            path: '/friends',
            builder: (_, _) => const CommunityScreen(kind: EntryKind.friend),
          ),
          GoRoute(
            path: '/events',
            builder: (_, _) => const CommunityScreen(kind: EntryKind.event),
          ),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          for (final kind in EntryKind.values)
            GoRoute(
              path: '/${kind.name}/:id',
              builder: (_, state) =>
                  CommunityScreen(kind: kind, id: state.pathParameters['id']),
            ),
        ],
      ),
    ],
    errorBuilder: (context, _) => Scaffold(
      body: Notice(
        title: 'Page unavailable',
        message: 'Return to your circle.',
        action: TextButton(
          onPressed: () => context.go('/feed'),
          child: const Text('Go home'),
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

class CircleApp extends ConsumerWidget {
  const CircleApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'CIRCLE',
    debugShowCheckedModeBanner: false,
    theme: circleTheme(Brightness.light),
    darkTheme: circleTheme(Brightness.dark),
    themeMode: ref.watch(themeProvider),
    routerConfig: ref.watch(routerProvider),
  );
}

class CircleShell extends StatelessWidget {
  const CircleShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;
  static const _paths = [
    '/feed',
    '/groups',
    '/memories',
    '/friends',
    '/events',
  ];
  @override
  Widget build(BuildContext context) {
    final selected = path.startsWith('/group')
        ? 1
        : path.startsWith('/album') || path == '/memories'
        ? 2
        : path.startsWith('/friend')
        ? 3
        : path.startsWith('/event')
        ? 4
        : 0;
    final detail =
        path == '/create' ||
        path.startsWith('/post/') ||
        EntryKind.values.any((kind) => path.startsWith('/${kind.name}/'));
    return Scaffold(
      appBar: AppBar(
        title: Text(path == '/create' ? 'Share a memory' : 'CIRCLE'),
        leading: detail
            ? BackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(_paths[selected]);
                  }
                },
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Profile and settings',
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) => context.go(_paths[index]),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_album_outlined),
            label: 'Memories',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            label: 'Reunions',
          ),
        ],
      ),
    );
  }
}
