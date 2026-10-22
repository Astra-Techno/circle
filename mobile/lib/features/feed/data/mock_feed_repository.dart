import '../domain/post.dart';

const demoCommunity = 'marigold-2006';

class MockFeedRepository implements FeedRepository {
  List<Post> _posts = _seed();
  int _sequence = 0;
  static List<Post> _seed() => const [
    Post(
      id: 'courtyard',
      communityId: demoCommunity,
      author: 'Mira Sen',
      date: '22 Oct · 9:15 AM',
      archive: true,
      body:
          'Does anyone else remember the courtyard after the first rain? We would miss the bus just to stay a little longer. Some places never really leave you.',
      comments: ['Arun: And the tea stall was always our next stop.'],
    ),
    Post(
      id: 'reunion',
      communityId: demoCommunity,
      author: 'Dev Rao',
      date: '21 Oct · 6:40 PM',
      body:
          'Twenty years, a hundred stories. Let’s bring a favourite college memory to the reunion. Mine involves a very ambitious theatre rehearsal.',
    ),
  ];
  void _authorize(String communityId) {
    if (communityId != demoCommunity) {
      throw StateError('Community access denied');
    }
  }

  List<Post> _snapshot() => List.unmodifiable(_posts);
  @override
  Future<List<Post>> load(String communityId) async {
    _authorize(communityId);
    return _snapshot();
  }

  List<Post> _update(
    String communityId,
    String id,
    Post Function(Post) change,
  ) {
    _authorize(communityId);
    if (!_posts.any((post) => post.id == id)) {
      throw StateError('Post unavailable');
    }
    _posts = [
      for (final post in _posts)
        if (post.id == id) change(post) else post,
    ];
    return _snapshot();
  }

  @override
  List<Post> react(String communityId, String id) =>
      _update(communityId, id, (post) => post.copyWith(liked: !post.liked));
  @override
  List<Post> save(String communityId, String id) =>
      _update(communityId, id, (post) => post.copyWith(saved: !post.saved));
  static String validateText(String text) {
    final value = text.trim();
    if (value.isEmpty || value.length > 2000) {
      throw ArgumentError('Enter 1–2000 characters.');
    }
    return value;
  }

  @override
  List<Post> comment(String communityId, String id, String text) => _update(
    communityId,
    id,
    (post) => post.copyWith(
      comments: [...post.comments, 'You: ${validateText(text)}'],
    ),
  );
  @override
  List<Post> create(String communityId, String text) {
    _authorize(communityId);
    final body = validateText(text);
    _posts = [
      Post(
        id: 'local-${++_sequence}',
        communityId: communityId,
        author: 'You',
        body: body,
        date: 'Just now · local demo',
      ),
      ..._posts,
    ];
    return _snapshot();
  }

  @override
  void reset() {
    _posts = _seed();
    _sequence = 0;
  }
}
