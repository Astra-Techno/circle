import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../chat/application/chat_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../domain/search_rules.dart';

export '../domain/search_rules.dart';

/// What search may look at for the current viewer. Rebuilt whenever the
/// workspace or chats change.
final searchCorpusProvider = FutureProvider<SearchCorpus>((ref) async {
  ref.watch(chatControllerProvider);
  final workspace = await ref.watch(circleWorkspaceProvider.future);
  // Chat isn't on the server yet: search only what the workspace holds.
  if (!ref.watch(circleFeaturesProvider).has(CircleFeature.chat)) {
    return SearchCorpus(workspace: workspace, messages: const []);
  }
  final viewer = ref.watch(circleViewerProvider);
  final chat = ref.watch(chatRepositoryProvider);
  final privacy = await chat.privacy(viewer);
  return SearchCorpus(
    workspace: workspace,
    messages: await chat.readableMessages(viewer),
    blocked: privacy.settings.blocked,
  );
});

/// Recent searches for this session only (newest first, at most 5).
final recentSearchesProvider = NotifierProvider<RecentSearches, List<String>>(
  RecentSearches.new,
);

class RecentSearches extends Notifier<List<String>> {
  @override
  List<String> build() {
    ref.watch(circlePreviewSessionProvider);
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
