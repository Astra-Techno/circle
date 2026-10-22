enum EntryKind { group, album, friend, event }

class CircleEntry {
  const CircleEntry(
    this.id,
    this.kind,
    this.title,
    this.subtitle,
    this.description,
  );
  final String id, title, subtitle, description;
  final EntryKind kind;
}

abstract interface class CommunityRepository {
  List<CircleEntry> entries(String communityId, EntryKind kind);
}
