import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mock_feed_repository.dart';
import '../domain/post.dart';

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => MockFeedRepository(),
);
final feedProvider = AsyncNotifierProvider<FeedController, List<Post>>(
  FeedController.new,
);

class FeedController extends AsyncNotifier<List<Post>> {
  FeedRepository get _repository => ref.read(feedRepositoryProvider);
  @override
  Future<List<Post>> build() => _repository.load(demoCommunity);
  void react(String id) =>
      state = AsyncData(_repository.react(demoCommunity, id));
  void save(String id) =>
      state = AsyncData(_repository.save(demoCommunity, id));
  void comment(String id, String text) =>
      state = AsyncData(_repository.comment(demoCommunity, id, text));
  void create(String text) =>
      state = AsyncData(_repository.create(demoCommunity, text));
}
