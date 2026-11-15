import 'circle_workspace.dart';

/// One independent Memory view; Home pagination never supplies these pages.
class MemoryQuery {
  const MemoryQuery({
    this.groupId,
    this.saved = false,
    this.text = '',
    this.year,
  });
  final String? groupId;
  final bool saved;
  final String text;

  /// Keepsake Chapters: only Memories created in this (local) calendar year.
  /// Server pages are filtered client-side, so a chapter keeps loading older
  /// pages until the year is complete.
  final int? year;
  @override
  bool operator ==(Object other) =>
      other is MemoryQuery &&
      other.groupId == groupId &&
      other.saved == saved &&
      other.text == text &&
      other.year == year;
  @override
  int get hashCode => Object.hash(groupId, saved, text, year);
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
