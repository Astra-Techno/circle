import '../domain/circle_repository.dart';
import '../../memories/domain/circle_memory.dart';

class MockCircleRepository implements CircleRepository {
  MockCircleRepository({bool showcase = false, DateTime Function()? now})
    : _now = now ?? DateTime.now {
    reset(showcase: showcase);
  }
  final DateTime Function() _now;
  List<CircleGroup> _groups = [];
  List<CircleMemory> _memories = [];
  List<CircleEvent> _events = [];
  int _sequence = 0;
  @override
  void reset({required bool showcase}) {
    final seedTime = _now().toUtc();
    _sequence = 0;
    _groups = showcase
        ? [
            CircleGroup(
              id: 'family',
              name: 'The Sunday table',
              type: CircleType.family,
              depth: 1,
              roles: {
                'you': CircleRole.owner,
                'mira': CircleRole.member,
                'dev': CircleRole.member,
              },
            ),
            CircleGroup(
              id: 'college',
              name: 'Northbank 2009',
              type: CircleType.college,
              depth: 1,
              roles: {
                'mira': CircleRole.owner,
                'you': CircleRole.admin,
                'dev': CircleRole.member,
              },
            ),
            CircleGroup(
              id: 'cse',
              name: 'Computer science',
              type: CircleType.college,
              depth: 2,
              parentId: 'college',
              roles: {'dev': CircleRole.owner, 'you': CircleRole.member},
            ),
            CircleGroup(
              id: 'section',
              name: 'Section A',
              type: CircleType.college,
              depth: 3,
              parentId: 'cse',
              roles: {'dev': CircleRole.owner, 'you': CircleRole.member},
            ),
            CircleGroup(
              id: 'friends',
              name: 'The window-seat crew',
              type: CircleType.friends,
              depth: 4,
              parentId: 'section',
              hidden: true,
              roles: {'dev': CircleRole.owner, 'you': CircleRole.member},
            ),
            CircleGroup(
              id: 'work',
              name: 'Studio North',
              type: CircleType.office,
              depth: 1,
              roles: {'dev': CircleRole.owner, 'you': CircleRole.member},
            ),
            CircleGroup(
              id: 'club',
              name: 'Sunday miles',
              type: CircleType.club,
              depth: 1,
              roles: {'you': CircleRole.owner, 'mira': CircleRole.member},
            ),
            CircleGroup(
              id: 'private-plans',
              name: 'Surprise planners',
              type: CircleType.family,
              depth: 2,
              parentId: 'family',
              hidden: true,
              roles: {'mira': CircleRole.owner},
            ),
          ]
        : [];
    _memories = showcase
        ? [
            CircleMemory(
              id: 'table',
              groupId: 'family',
              author: 'Mira',
              text:
                  'Same table, a few new stories. Sunday lunch is still my favourite way to bring everyone together.',
              createdAt: seedTime.subtract(const Duration(hours: 1)),
              illustration: 'Room for one more',
              comments: const ['Dev: I’m bringing dessert next time.'],
            ),
            CircleMemory(
              id: 'ride',
              groupId: 'club',
              author: 'Dev',
              text:
                  'A slow ride, a long breakfast, and absolutely no one checking the time.',
              createdAt: seedTime.subtract(const Duration(days: 1)),
              illustration: 'The scenic route',
            ),
            CircleMemory(
              id: 'old-days',
              groupId: 'friends',
              author: 'Mira',
              text:
                  'Found our old project notes. The ideas were ambitious. The handwriting, less so.',
              createdAt: seedTime.subtract(const Duration(days: 2)),
            ),
            CircleMemory(
              id: 'private-memory',
              groupId: 'private-plans',
              author: 'Mira',
              text: 'A private planning note.',
              createdAt: seedTime.subtract(const Duration(minutes: 30)),
            ),
          ]
        : [];
    _events = showcase
        ? const [
            CircleEvent(
              id: 'lunch',
              groupId: 'family',
              title: 'A Sunday well spent',
              when: '25 Oct · 12:30 PM IST',
              where: 'The family table · Fictional venue',
            ),
            CircleEvent(
              id: 'cycling',
              groupId: 'club',
              title: 'Take the long way home',
              when: '1 Nov · 6:30 AM IST',
              where: 'Lakeside meeting point · Fictional venue',
            ),
          ]
        : [];
  }

  @override
  CircleGroup readGroup(String viewer, String groupId) {
    final group = _groups.where((group) => group.id == groupId).firstOrNull;
    if (group == null || !group.roles.containsKey(viewer)) {
      throw const CircleFailure('This group is not shared with you.');
    }
    return group;
  }

  @override
  Future<CircleWorkspace> load(String viewer) async {
    final groups = _groups
        .where((group) => group.roles.containsKey(viewer))
        .toList();
    final ids = groups.map((group) => group.id).toSet();
    final memories =
        _memories.where((memory) => ids.contains(memory.groupId)).toList()
          ..sort((a, b) {
            final order = b.createdAt.compareTo(a.createdAt);
            return order == 0 ? b.id.compareTo(a.id) : order;
          });
    return CircleWorkspace(
      groups: groups,
      memories: memories,
      events: _events.where((event) => ids.contains(event.groupId)).toList(),
    );
  }

  @override
  CircleGroup createGroup(
    String viewer,
    String name,
    CircleType type, {
    String? parentId,
  }) {
    if (viewer.trim().isEmpty) {
      throw const CircleFailure('Enter the local preview first.');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.runes.length > 60) {
      throw const CircleFailure('Use a group name with 1–60 characters.');
    }
    final parent = parentId == null ? null : readGroup(viewer, parentId);
    final depth = (parent?.depth ?? 0) + 1;
    if (depth > 10) {
      throw const CircleFailure('This group is already at the 10-level limit.');
    }
    final group = CircleGroup(
      id: 'local-${++_sequence}',
      name: trimmed,
      type: type,
      depth: depth,
      parentId: parentId,
      roles: {viewer: CircleRole.owner},
    );
    _groups = [..._groups, group];
    return group;
  }

  String _text(String input) {
    final value = input.trim();
    if (value.isEmpty || value.runes.length > 2000) {
      throw const CircleFailure('Write 1–2000 characters before sharing.');
    }
    return value;
  }

  @override
  void createMemory(String viewer, String groupId, String text) {
    readGroup(viewer, groupId);
    final value = _text(text);
    _memories = [
      CircleMemory(
        id: 'local-memory-${(++_sequence).toString().padLeft(8, '0')}',
        groupId: groupId,
        author: 'You',
        text: value,
        createdAt: _now().toUtc(),
      ),
      ..._memories,
    ];
  }

  void _change(
    String viewer,
    String id,
    CircleMemory Function(CircleMemory) change,
  ) {
    final memory = _memories.where((memory) => memory.id == id).firstOrNull;
    if (memory == null) {
      throw const CircleFailure('This Memory is unavailable.');
    }
    readGroup(viewer, memory.groupId);
    _memories = [
      for (final item in _memories)
        if (item.id == id) change(item) else item,
    ];
  }

  @override
  void loveMemory(String viewer, String memoryId) => _change(
    viewer,
    memoryId,
    (memory) => memory.copyWith(loved: !memory.loved),
  );
  @override
  void saveMemory(String viewer, String memoryId) => _change(
    viewer,
    memoryId,
    (memory) => memory.copyWith(saved: !memory.saved),
  );
  @override
  void comment(String viewer, String memoryId, String text) => _change(
    viewer,
    memoryId,
    (memory) =>
        memory.copyWith(comments: [...memory.comments, 'You: ${_text(text)}']),
  );
  @override
  void rsvp(String viewer, String eventId, Attendance choice) {
    final event = _events.where((event) => event.id == eventId).firstOrNull;
    if (event == null) throw const CircleFailure('This event is unavailable.');
    readGroup(viewer, event.groupId);
    _events = [
      for (final item in _events)
        if (item.id == eventId) item.respond(choice) else item,
    ];
  }
}
