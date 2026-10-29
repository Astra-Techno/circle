import 'package:flutter_riverpod/flutter_riverpod.dart';
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
