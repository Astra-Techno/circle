class CircleMemory {
  const CircleMemory({
    required this.id,
    required this.groupId,
    required this.author,
    required this.text,
    required this.createdAt,
    this.illustration,
    this.loved = false,
    this.saved = false,
    this.comments = const [],
  });
  final String id, groupId, author, text;
  final DateTime createdAt;
  final String? illustration;
  final bool loved, saved;
  final List<String> comments;
  CircleMemory copyWith({bool? loved, bool? saved, List<String>? comments}) =>
      CircleMemory(
        id: id,
        groupId: groupId,
        author: author,
        text: text,
        createdAt: createdAt,
        illustration: illustration,
        loved: loved ?? this.loved,
        saved: saved ?? this.saved,
        comments: List.unmodifiable(comments ?? this.comments),
      );
}
