# Decisions

1. Original Material 3 design because no approved Figma frames exist. Local icon illustrations avoid external media and licensing ambiguity.
2. In-memory repository and explicit demo invitation instead of simulated production accounts. No password is requested or stored. Sign-in/sign-up production forms are deferred; the Phase 1 startup prompt prioritizes mock invitation access.
3. Shared typed community catalogue supports functional supporting screens without artificial repository layers for each static fixture. Feed has its own domain/data/presentation boundary and async state.
4. No Dio dependency until networking exists, as permitted by the startup prompt. No backend or cloud configuration.

Dependency guidance was checked against the primary package documentation: [Riverpod](https://pub.dev/packages/flutter_riverpod), [go_router](https://pub.dev/packages/go_router) and its [API reference](https://pub.dev/documentation/go_router/latest/). The installed SDK resolved compatible versions; pubspec.lock records them. Context7 was unavailable.
