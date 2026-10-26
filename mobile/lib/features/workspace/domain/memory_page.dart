import 'circle_workspace.dart';

/// One independent Memory view; Home pagination never supplies these pages.
class MemoryQuery {
  const MemoryQuery({this.groupId, this.saved = false, this.text = ''});
  final String? groupId;
  final bool saved;
  final String text;
  @override
  bool operator ==(Object other) =>
      other is MemoryQuery &&
      other.groupId == groupId &&
      other.saved == saved &&
      other.text == text;
  @override
  int get hashCode => Object.hash(groupId, saved, text);
}

class MemoryPage {
  MemoryPage({
    required List<CircleMemory> items,
    this.cursor,
    this.hasMore = false,
  }) : items = List.unmodifiable(items);
  final List<CircleMemory> items;
  final String? cursor;
  final bool hasMore;
}

/// Optional paginated server capability. Preview repositories are complete.
abstract interface class MemoryQueryReader {
  Future<MemoryPage> queryMemories(
    String viewer,
    MemoryQuery query, {
    String? cursor,
  });
}
