import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/design.dart';
import 'features/auth/presentation/access_design.dart';

void main() => runApp(const AuthDesignPreview());

/// Isolated original design proposal; no production account/session is created.
class AuthDesignPreview extends StatefulWidget {
  const AuthDesignPreview({super.key});
  @override
  State<AuthDesignPreview> createState() => _AuthDesignPreviewState();
}

class _AuthDesignPreviewState extends State<AuthDesignPreview> {
  late final _router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const AccessWelcome()),
      GoRoute(
        path: '/register',
        builder: (_, _) => const AccessForm(registering: true),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const AccessForm(registering: false),
      ),
      GoRoute(
        path: '/complete',
        builder: (_, _) => const AccessPreviewComplete(),
      ),
    ],
  );
  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'CIRCLE · Access design',
    debugShowCheckedModeBanner: false,
    theme: circleTheme(Brightness.light),
    darkTheme: circleTheme(Brightness.dark),
    routerConfig: _router,
  );
}
