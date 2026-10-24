import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

export 'api_client.dart';

/// The server chosen at build time (`--dart-define=CIRCLE_API_BASE_URL=…`),
/// or null for the fictional preview. Tests override it.
final apiConfigProvider = Provider<ApiConfig?>(
  (ref) => ApiConfig.fromEnvironment(),
);

/// Secure token storage. Tests override it with [MemoryTokenStore].
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// Tests replace the network with a fake adapter; null uses the platform.
final apiHttpAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

/// The app's single API client, or null in preview builds.
final apiClientProvider = Provider<ApiClient?>((ref) {
  final config = ref.watch(apiConfigProvider);
  if (config == null) return null;
  final client = ApiClient(
    config: config,
    tokens: ref.watch(tokenStoreProvider),
    adapter: ref.watch(apiHttpAdapterProvider),
  );
  ref.onDispose(() => client.dio.close(force: true));
  return client;
});
