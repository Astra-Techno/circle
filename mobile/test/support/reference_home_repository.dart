import 'package:mobile/features/workspace/domain/circle_repository.dart';
import 'mock_circle_repository.dart';

/// Test-only matching text/counts. Photos/avatars intentionally remain fictional
/// and are excluded from visual pixel comparison, never called layout errors.
class ReferenceHomeRepository extends MockCircleRepository {
  ReferenceHomeRepository() : super(showcase: true, now: () => clock);
  static final clock = DateTime(2026, 10, 15, 14, 30);
  @override
  Future<CircleWorkspace> load(String viewer) async {
    final base = await super.load(viewer);
    final source = base.memories.firstWhere((m) => m.photos.length >= 3);
    return CircleWorkspace(
      viewer: base.viewer,
      groups: [
        for (final g in base.groups)
          g.id == source.groupId ? g.copyWith(name: 'College Friends') : g,
      ],
      people: {...base.people, source.authorId: 'Priya'},
      events: base.events,
      memories: [
        CircleMemory(
          id: source.id,
          groupId: source.groupId,
          authorId: source.authorId,
          author: 'Priya',
          text:
              'Remember our college trip? Can’t believe it’s been 10 years! ❤️',
          createdAt: clock.subtract(const Duration(hours: 2)),
          commentCount: 8,
          reactions: MemoryReactions(
            others: const {'❤️': 12, '👍': 8, '😂': 4},
          ),
          photos: [
            for (var i = 0; i < 6; i++)
              MemoryPhoto(
                id: 'reference-$i',
                scene: i == 0 ? MemoryScene.sundayLunch : MemoryScene.hillTrip,
              ),
          ],
        ),
      ],
    );
  }
}
