import '../../memories/domain/circle_memory.dart';

enum CircleType { family, friends, school, college, office, club, other }

enum CircleRole { owner, admin, member }

enum Attendance { going, maybe, notGoing }

class CircleGroup {
  CircleGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.depth,
    required Map<String, CircleRole> roles,
    this.parentId,
    this.hidden = false,
  }) : roles = Map.unmodifiable(roles);
  final String id, name;
  final CircleType type;
  final String? parentId;
  final int depth;
  final bool hidden;
  final Map<String, CircleRole> roles;
}

class CircleEvent {
  const CircleEvent({
    required this.id,
    required this.groupId,
    required this.title,
    required this.when,
    required this.where,
    this.attendance,
  });
  final String id, groupId, title, when, where;
  final Attendance? attendance;
  CircleEvent respond(Attendance choice) => CircleEvent(
    id: id,
    groupId: groupId,
    title: title,
    when: when,
    where: where,
    attendance: choice,
  );
}

class CircleWorkspace {
  CircleWorkspace({
    required List<CircleGroup> groups,
    required List<CircleMemory> memories,
    required List<CircleEvent> events,
  }) : groups = List.unmodifiable(groups),
       memories = List.unmodifiable(memories),
       events = List.unmodifiable(events);
  final List<CircleGroup> groups;
  final List<CircleMemory> memories;
  final List<CircleEvent> events;
}

class CircleFailure implements Exception {
  const CircleFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class CircleRepository {
  Future<CircleWorkspace> load(String viewer);
  CircleGroup readGroup(String viewer, String groupId);
  CircleGroup createGroup(
    String viewer,
    String name,
    CircleType type, {
    String? parentId,
  });
  void createMemory(String viewer, String groupId, String text);
  void loveMemory(String viewer, String memoryId);
  void saveMemory(String viewer, String memoryId);
  void comment(String viewer, String memoryId, String text);
  void rsvp(String viewer, String eventId, Attendance choice);
  void reset({required bool showcase});
}
