import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design.dart';
import '../core/circle_components.dart';
import '../features/auth/presentation/access_design.dart';
import '../features/groups/presentation/circle_groups.dart';
import '../features/memories/presentation/circle_memories.dart';
import 'circle_support_screens.dart';
import 'workspace_providers.dart';
import 'session.dart';

String? circleReturnDestination(String? input) {
  final uri = input == null ? null : Uri.tryParse(input);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.path.contains(r'\')) {
    return null;
  }
  final path = uri.path;
  return const {
            '/home',
            '/chats',
            '/groups',
            '/groups/new',
            '/events',
            '/you',
            '/compose',
          }.contains(path) ||
          RegExp(
            r'^/(home/memory|groups/g|chats/g)/[A-Za-z0-9_-]+$',
          ).hasMatch(path)
      ? uri.toString()
      : null;
}

final circleRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  late final GoRouter router;
  ref.listen(circlePreviewSessionProvider, (previous, entered) {
    if (previous == true && !entered) router.go('/');
    refresh.value++;
  });
  router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final entered = ref.read(circlePreviewSessionProvider);
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
        builder: (_, _) => AccessWelcome(
          onExploreDemo: () => ref
              .read(circlePreviewSessionProvider.notifier)
              .enter(showcase: true),
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => AccessForm(
          registering: true,
          onPreviewComplete: () => ref
              .read(circlePreviewSessionProvider.notifier)
              .enter(showcase: false),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => AccessForm(
          registering: false,
          onPreviewComplete: () => ref
              .read(circlePreviewSessionProvider.notifier)
              .enter(showcase: false),
        ),
      ),
      GoRoute(
        path: '/compose',
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: const Text('New Memory'),
            leading: BackButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
          ),
          body: const SafeArea(child: CircleCompose()),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => CircleAppShell(shell: shell),
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
                        CircleMemoryDetail(id: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chats',
                builder: (_, _) => const CircleChats(),
                routes: [
                  GoRoute(
                    path: 'g/:id',
                    builder: (_, state) =>
                        CircleChats(groupId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/groups',
                builder: (_, _) => const CircleGroups(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, state) => CircleCreateGroup(
                      parentId: state.uri.queryParameters['parent'],
                    ),
                  ),
                  GoRoute(
                    path: 'g/:id',
                    builder: (_, state) =>
                        CircleGroupDetail(id: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/events', builder: (_, _) => const CircleEvents()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/you', builder: (_, _) => const CircleYou()),
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

class CircleAppShell extends StatelessWidget {
  const CircleAppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final path = router.routeInformationProvider.value.uri.path;
    final detail =
        path.contains('/g/') ||
        path.contains('/memory/') ||
        path == '/groups/new';
    return Scaffold(
      appBar: AppBar(
        title: const Text('CIRCLE'),
        leading: detail
            ? BackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    shell.goBranch(shell.currentIndex, initialLocation: true);
                  }
                },
              )
            : null,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: Space.lg),
            child: Center(
              child: Text(
                'LOCAL PREVIEW',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: shell),
      floatingActionButton:
          !detail && (shell.currentIndex == 0 || shell.currentIndex == 2)
          ? FloatingActionButton.extended(
              elevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              onPressed: () => context.push(
                shell.currentIndex == 0 ? '/compose' : '/groups/new',
              ),
              icon: const Icon(Icons.add),
              label: Text(shell.currentIndex == 0 ? 'New Memory' : 'New group'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        height: MediaQuery.textScalerOf(context).scale(56) + Space.section,
        selectedIndex: shell.currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            label: 'Events',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'You'),
        ],
      ),
    );
  }
}
