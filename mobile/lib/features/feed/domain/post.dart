class Post {
  const Post({
    required this.id,
    required this.communityId,
    required this.author,
    required this.body,
    required this.date,
    this.archive = false,
    this.liked = false,
    this.saved = false,
    this.comments = const [],
  });
  final String id, communityId, author, body, date;
  final bool archive, liked, saved;
  final List<String> comments;
  Post copyWith({bool? liked, bool? saved, List<String>? comments}) => Post(
    id: id,
    communityId: communityId,
    author: author,
    body: body,
    date: date,
    archive: archive,
    liked: liked ?? this.liked,
    saved: saved ?? this.saved,
    comments: List.unmodifiable(comments ?? this.comments),
  );
}

abstract interface class FeedRepository {
  Future<List<Post>> load(String communityId);
  List<Post> react(String communityId, String id);
  List<Post> save(String communityId, String id);
  List<Post> comment(String communityId, String id, String text);
  List<Post> create(String communityId, String text);
  void reset();
}
