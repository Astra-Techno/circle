import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/groups/domain/circle_group.dart';
import 'package:mobile/features/groups/domain/group_tree.dart';
import 'package:mobile/features/groups/domain/membership_rules.dart';

CircleGroup makeGroup(
  String id,
  Map<String, CircleRole> roles, {
  String? parent,
  int depth = 1,
  bool hidden = false,
  String? name,
  int order = 0,
  InvitePolicy policy = InvitePolicy.adminsOnly,
}) => CircleGroup(
  id: id,
  name: name ?? id,
  type: CircleType.other,
  depth: depth,
  parentId: parent,
  roles: roles,
  settings: GroupSettings(hidden: hidden, invitePolicy: policy),
  order: order,
);

const owner = CircleRole.owner, admin = CircleRole.admin;
const member = CircleRole.member;

void main() {
  final root = makeGroup('root', {
    'o': owner,
    'a': admin,
    'm': member,
    'x': member,
  });
  final child = makeGroup(
    'child',
    {'m': owner, 'a': member, 'x': member},
    parent: 'root',
    depth: 2,
  );
  final grandchild = makeGroup(
    'grand',
    {'x': member, 'm': owner},
    parent: 'child',
    depth: 3,
    hidden: true,
  );
  final groups = {
    for (final g in [root, child, grandchild]) g.id: g,
  };

  group('roles', () {
    test('admins promote; only the owner demotes; owner is protected', () {
      expect(
        MembershipRules.canChangeRole(root, 'a', 'm', admin).allowed,
        isTrue,
      );
      expect(
        MembershipRules.canChangeRole(root, 'm', 'x', admin).allowed,
        isFalse,
      );
      expect(
        MembershipRules.canChangeRole(root, 'a', 'a', member).allowed,
        isFalse,
      );
      final twoAdmins = root.copyWith(
        roles: {...root.roles, 'm': CircleRole.admin},
      );
      expect(
        MembershipRules.canChangeRole(twoAdmins, 'a', 'm', member).allowed,
        isFalse,
      );
      expect(
        MembershipRules.canChangeRole(twoAdmins, 'o', 'm', member).allowed,
        isTrue,
      );
      expect(
        MembershipRules.canChangeRole(root, 'a', 'o', member).allowed,
        isFalse,
      );
      expect(
        MembershipRules.canChangeRole(root, 'o', 'm', owner).allowed,
        isFalse,
        reason: 'ownership moves only through transfer',
      );
    });

    test('removal protects the owner, self and admins from non-owners', () {
      expect(MembershipRules.canRemove(root, 'a', 'x').allowed, isTrue);
      expect(MembershipRules.canRemove(root, 'a', 'o').allowed, isFalse);
      expect(MembershipRules.canRemove(root, 'o', 'o').allowed, isFalse);
      expect(MembershipRules.canRemove(root, 'a', 'a').allowed, isFalse);
      expect(MembershipRules.canRemove(root, 'o', 'a').allowed, isTrue);
      expect(MembershipRules.canRemove(root, 'm', 'x').allowed, isFalse);
      expect(
        MembershipRules.canRemove(
          root,
          'o',
          'm',
          ownedDescendants: const ['child'],
        ).reason,
        contains('child'),
      );
    });

    test('only the owner transfers, and only to a member', () {
      expect(
        MembershipRules.canTransferOwnership(root, 'o', 'm').allowed,
        isTrue,
      );
      expect(
        MembershipRules.canTransferOwnership(root, 'a', 'm').allowed,
        isFalse,
      );
      expect(
        MembershipRules.canTransferOwnership(root, 'o', 'stranger').allowed,
        isFalse,
      );
      expect(
        MembershipRules.canTransferOwnership(root, 'o', 'o').allowed,
        isFalse,
      );
    });

    test('invite policy: admins only by default, members when allowed', () {
      expect(MembershipRules.canInvite(root, 'a').allowed, isTrue);
      expect(MembershipRules.canInvite(root, 'm').allowed, isFalse);
      expect(MembershipRules.canInvite(root, 'stranger').allowed, isFalse);
      final open = root.copyWith(
        settings: root.settings.copyWith(invitePolicy: InvitePolicy.allMembers),
      );
      expect(MembershipRules.canInvite(open, 'm').allowed, isTrue);
      expect(MembershipRules.canManageLink(open, 'm').allowed, isFalse);
    });

    test('member actions reflect the rules for the UI', () {
      final forMember = MemberActions(root, 'o', 'm');
      expect(forMember.promote && forMember.remove && forMember.transfer, true);
      expect(forMember.demote, isFalse);
      expect(MemberActions(root, 'm', 'x').any, isFalse);
      expect(MemberActions(root, 'a', 'o').any, isFalse);
    });
  });

  group('leaving and cascade', () {
    test('cascade lists the group and every descendant the person is in', () {
      expect(MembershipRules.cascade(groups, 'root', 'x').map((g) => g.id), [
        'root',
        'child',
        'grand',
      ]);
      expect(MembershipRules.cascade(groups, 'root', 'a').map((g) => g.id), [
        'root',
        'child',
      ]);
      expect(MembershipRules.cascade(groups, 'root', 'nobody'), isEmpty);
    });

    test('owner cannot leave; last admin cannot leave', () {
      expect(
        MembershipRules.canLeave(root, 'o', [root]).reason,
        contains('Transfer ownership'),
      );
      final noOwner = makeGroup('n', {'a': admin, 'm': member});
      expect(MembershipRules.isLastAdmin(noOwner, 'a'), isTrue);
      expect(
        MembershipRules.canLeave(noOwner, 'a', [noOwner]).reason,
        contains('only admin'),
      );
      expect(MembershipRules.canLeave(root, 'a', [root]).allowed, isTrue);
    });

    test('leaving is blocked while owning a descendant', () {
      final cascade = MembershipRules.cascade(groups, 'root', 'm');
      final result = MembershipRules.canLeave(root, 'm', cascade);
      expect(result.allowed, isFalse);
      expect(result.reason, contains('child'));
      expect(MembershipRules.ownedDescendants(groups, 'root', 'm'), [
        'child',
        'grand',
      ]);
    });
  });

  group('joining and discovery', () {
    test('subgroups require active membership of the direct parent', () {
      expect(MembershipRules.canJoin(child, 'o', groups).allowed, isTrue);
      expect(
        MembershipRules.canJoin(child, 'stranger', groups).reason,
        contains('Join root first'),
      );
      expect(
        MembershipRules.canJoin(grandchild, 'o', groups).allowed,
        isFalse,
        reason: 'parent of grand is child, not root',
      );
      expect(MembershipRules.canJoin(child, 'a', groups).allowed, isFalse);
    });

    test('hidden subgroups and root groups are never listed', () {
      expect(MembershipRules.isDiscoverable(child, 'o', groups), isTrue);
      expect(MembershipRules.isDiscoverable(child, 'stranger', groups), false);
      expect(MembershipRules.isDiscoverable(child, 'm', groups), isFalse);
      final outsider = makeGroup('grand-o', {}, parent: 'child', depth: 3);
      expect(
        MembershipRules.isDiscoverable(outsider, 'a', {
          ...groups,
          'g': outsider,
        }),
        isTrue,
      );
      expect(MembershipRules.isDiscoverable(grandchild, 'a', groups), isFalse);
      expect(MembershipRules.isDiscoverable(root, 'stranger', groups), false);
    });

    test('depth: level ten may exist, level eleven may not be created', () {
      final level10 = makeGroup('ten', {'p': owner}, depth: 10);
      final level9 = makeGroup('nine', {'p': owner}, depth: 9);
      expect(
        MembershipRules.canCreateGroup(person: 'p', parent: level9).allowed,
        isTrue,
      );
      expect(
        MembershipRules.canCreateGroup(person: 'p', parent: level10).allowed,
        isFalse,
      );
      expect(
        MembershipRules.canCreateGroup(person: 'q', parent: level9).allowed,
        isFalse,
      );
    });
  });

  group('group tree', () {
    test('orders parents before children, siblings by name, any depth', () {
      final items = [
        makeGroup('b', {}, name: 'Beta', order: 1),
        makeGroup('a2', {}, name: 'Zed', parent: 'a', depth: 2, order: 2),
        makeGroup('a', {}, name: 'Alpha', order: 3),
        makeGroup('a1', {}, name: 'Mid', parent: 'a', depth: 2, order: 4),
        makeGroup('a11', {}, name: 'Deep', parent: 'a1', depth: 3, order: 5),
        makeGroup('orphan', {}, name: 'Orphan', parent: 'gone', depth: 4),
      ];
      final tree = buildGroupTree(items);
      expect(tree.map((e) => e.group.id), [
        'a',
        'a1',
        'a11',
        'a2',
        'b',
        'orphan',
      ]);
      expect(tree.map((e) => e.level), [0, 1, 2, 1, 0, 0]);
      expect(tree[2].path, ['Alpha', 'Mid']);
      expect(tree.first.hasChildren, isTrue);
      final collapsed = buildGroupTree(items, collapsed: {'a'});
      expect(collapsed.map((e) => e.group.id), ['a', 'b', 'orphan']);
      expect(collapsed.first.expanded, isFalse);
    });

    test('a ten-level chain keeps every level distinct', () {
      final chain = [
        for (var i = 1; i <= 10; i++)
          makeGroup(
            'l$i',
            {},
            name: 'Level $i',
            depth: i,
            parent: i == 1 ? null : 'l${i - 1}',
          ),
      ];
      final tree = buildGroupTree(chain.reversed);
      expect(tree.map((e) => e.level), List.generate(10, (i) => i));
      expect(
        groupLineage(chain.last, {for (final g in chain) g.id: g}).length,
        10,
      );
    });
  });
}
