import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/groups/data/mock_circle_repository.dart';
import 'package:mobile/features/groups/domain/circle_repository.dart';

void main() {
  test('new Memories sort first even with a fixed clock', () async {
    final repository = MockCircleRepository(
      showcase: true,
      now: () => DateTime.utc(2026, 1, 1),
    );
    repository.createMemory('you', 'family', 'First new Memory');
    repository.createMemory('you', 'family', 'Second new Memory');
    final memories = (await repository.load('you')).memories;
    expect(memories.take(2).map((memory) => memory.text), [
      'Second new Memory',
      'First new Memory',
    ]);
  });
  test(
    'registration preview starts empty; showcase is an explicit choice',
    () async {
      final repository = MockCircleRepository();
      expect((await repository.load('you')).groups, isEmpty);
      repository.reset(showcase: true);
      final workspace = await repository.load('you');
      expect(workspace.groups.length, 7);
      expect(workspace.groups.any((group) => group.depth == 4), true);
      expect(workspace.memories.map((memory) => memory.id), [
        'table',
        'ride',
        'old-days',
      ]);
      expect(
        workspace.groups.any((group) => group.id == 'private-plans'),
        false,
      );
    },
  );
  test(
    'parent owner does not inherit private child membership or content access',
    () {
      final repository = MockCircleRepository(showcase: true);
      expect(
        repository.readGroup('you', 'family').roles['you'],
        CircleRole.owner,
      );
      expect(
        () => repository.readGroup('you', 'private-plans'),
        throwsA(isA<CircleFailure>()),
      );
      expect(
        () => repository.createMemory('you', 'private-plans', 'test'),
        throwsA(isA<CircleFailure>()),
      );
      expect(
        () => repository.loveMemory('you', 'private-memory'),
        throwsA(isA<CircleFailure>()),
      );
      expect(
        () => repository.saveMemory('you', 'private-memory'),
        throwsA(isA<CircleFailure>()),
      );
      expect(
        () => repository.comment('you', 'private-memory', 'test'),
        throwsA(isA<CircleFailure>()),
      );
      expect(
        () => repository.createGroup(
          'you',
          'A child',
          CircleType.family,
          parentId: 'private-plans',
        ),
        throwsA(isA<CircleFailure>()),
      );
    },
  );
  test(
    'roles are exact-group and any direct-parent member may create a subgroup',
    () {
      final repository = MockCircleRepository(showcase: true);
      expect(
        repository.readGroup('you', 'college').roles['you'],
        CircleRole.admin,
      );
      expect(
        repository.readGroup('you', 'cse').roles['you'],
        CircleRole.member,
      );
      final child = repository.createGroup(
        'you',
        'A smaller group',
        CircleType.friends,
        parentId: 'cse',
      );
      expect(child.depth, 3);
      expect(child.roles, {'you': CircleRole.owner});
      expect(
        () => child.roles['other'] = CircleRole.admin,
        throwsUnsupportedError,
      );
    },
  );
  test(
    'root is level one; level ten is allowed and level eleven is denied',
    () {
      final repository = MockCircleRepository();
      var group = repository.createGroup('you', 'Root', CircleType.other);
      expect(group.depth, 1);
      for (var depth = 2; depth <= 10; depth++) {
        group = repository.createGroup(
          'you',
          'Level $depth',
          CircleType.other,
          parentId: group.id,
        );
        expect(group.depth, depth);
      }
      expect(
        () => repository.createGroup(
          'you',
          'Too deep',
          CircleType.other,
          parentId: group.id,
        ),
        throwsA(isA<CircleFailure>()),
      );
      expect(
        () => repository.createGroup(
          'outsider',
          'Back door',
          CircleType.other,
          parentId: group.id,
        ),
        throwsA(isA<CircleFailure>()),
      );
    },
  );
  test('name and content boundaries reject empty/oversized input', () {
    final repository = MockCircleRepository(showcase: true);
    for (final name in ['  ', 'x' * 61]) {
      expect(
        () => repository.createGroup('you', name, CircleType.other),
        throwsA(isA<CircleFailure>()),
      );
    }
    for (final text in ['  ', 'x' * 2001]) {
      expect(
        () => repository.createMemory('you', 'family', text),
        throwsA(isA<CircleFailure>()),
      );
      expect(
        () => repository.comment('you', 'table', text),
        throwsA(isA<CircleFailure>()),
      );
    }
  });
  test(
    'mutations persist locally, scope to memberships and reset cleanly',
    () async {
      final repository = MockCircleRepository(showcase: true);
      repository.loveMemory('you', 'table');
      repository.saveMemory('you', 'table');
      repository.comment('you', 'table', ' A wonderful Sunday ');
      var workspace = await repository.load('you');
      expect(workspace.memories.first.loved, true);
      expect(workspace.memories.first.saved, true);
      expect(workspace.memories.first.comments.last, 'You: A wonderful Sunday');
      repository.createMemory('you', 'work', 'A small win');
      workspace = await repository.load('you');
      expect(workspace.memories.first.text, 'A small win');
      expect(workspace.memories.first.groupId, 'work');
      expect(
        () => repository.createMemory('stranger', 'work', 'test'),
        throwsA(isA<CircleFailure>()),
      );
      repository.reset(showcase: false);
      expect((await repository.load('you')).groups, isEmpty);
      expect((await repository.load('you')).memories, isEmpty);
    },
  );
  test(
    'event RSVP requires exact-group membership and retains a local choice',
    () async {
      final repository = MockCircleRepository(showcase: true);
      expect(
        () => repository.rsvp('stranger', 'lunch', Attendance.going),
        throwsA(isA<CircleFailure>()),
      );
      repository.rsvp('you', 'lunch', Attendance.maybe);
      expect(
        (await repository.load('you')).events.first.attendance,
        Attendance.maybe,
      );
      expect(
        () => repository.rsvp('you', 'missing', Attendance.going),
        throwsA(isA<CircleFailure>()),
      );
    },
  );
}
