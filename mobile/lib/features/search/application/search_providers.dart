import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/scoped_api.dart';
import '../data/server_search.dart';
import '../../workspace/application/workspace_providers.dart';
import '../domain/search_rules.dart';

export '../domain/search_rules.dart';

/// What search may look at for the current viewer: the groups, members
/// and Memories in the workspace. Rebuilt whenever the workspace changes.
final searchCorpusProvider = FutureProvider<SearchCorpus>((ref) async {
  final workspace = await ref.watch(circleWorkspaceProvider.future);
  return SearchCorpus(workspace: workspace, messages: const []);
});

/// Recent searches for this session only (newest first, at most 5).
final recentSearchesProvider = NotifierProvider<RecentSearches, List<String>>(
  RecentSearches.new,
);

class RecentSearches extends Notifier<List<String>> {
  @override
  List<String> build() {
    ref.watch(circleViewerProvider);
    return const [];
  }

  void remember(String query) {
    final value = query.trim();
    if (!SearchRules.ready(value)) return;
    state = [
      value,
      for (final item in state)
        if (item.toLowerCase() != value.toLowerCase()) item,
    ].take(5).toList();
  }

  void clear() => state = const [];
}

final serverSearchApiProvider = Provider<ServerSearch>((ref) {
  final api = ref.watch(apiClientProvider);
  final account = ref.watch(serverAccountProvider)?.id;
  if (api == null || account == null) {
    throw const CircleFailure('Sign in to search.');
  }
  return ServerSearch(
    ScopedApi(
      api,
      account,
      api.sessionRevision,
      () =>
          ref.mounted &&
          identical(ref.read(apiClientProvider), api) &&
          ref.read(serverAccountProvider)?.id == account,
    ),
  );
});
final serverSearchProvider = FutureProvider.autoDispose
    .family<ServerSearchPage, ({String query, int pages})>(
      (ref, request) =>
          ref.watch(serverSearchApiProvider).find(request.query, request.pages),
      retry: (_, _) => null,
    );
