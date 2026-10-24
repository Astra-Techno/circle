<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Core\Database;

final class GroupTest extends ApiTestCase
{
    public function testAnyUserCreatesRootGroupAsOwnerAndAdmin(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner, 'AKCE 2009');

        $r = $this->request('GET', "/api/v1/groups/{$gid}", [], $owner['token']);
        self::assertSame(200, $r->status());
        self::assertSame(1, $r->data()['depth']);
        self::assertSame($gid, $r->data()['root_id']);
        self::assertSame($owner['id'], $r->data()['owner_user_id']);
        self::assertSame('admin', $r->data()['my_role']);
    }

    public function testAnyActiveMemberCanCreateSubgroup(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $root = $this->createGroup($owner, 'Root');
        $this->join($owner, $member, $root);

        $child = $this->createGroup($member, 'Dept', $root);
        $r = $this->request('GET', "/api/v1/groups/{$child}", [], $member['token']);
        self::assertSame(2, $r->data()['depth']);
        self::assertSame($root, $r->data()['parent_id']);
        self::assertSame($member['id'], $r->data()['owner_user_id']);
        self::assertSame('admin', $r->data()['my_role']);
        self::assertSame([['id' => $root, 'name' => 'Root', 'depth' => 1]], $r->data()['ancestors']);
    }

    public function testNonMemberCannotCreateSubgroup(): void
    {
        $owner = $this->user();
        $outsider = $this->user();
        $root = $this->createGroup($owner);

        $r = $this->request('POST', '/api/v1/groups', ['name' => 'Sneaky', 'parent_id' => $root], $outsider['token']);
        self::assertSame(403, $r->status());
        self::assertSame('not_member', $r->errorCode());
    }

    public function testDepthTenAllowedElevenRejected(): void
    {
        $owner = $this->user();
        $parent = $this->createGroup($owner, 'Level 1');
        for ($level = 2; $level <= 10; $level++) {
            $parent = $this->createGroup($owner, "Level {$level}", $parent);
        }
        $r = $this->request('GET', "/api/v1/groups/{$parent}", [], $owner['token']);
        self::assertSame(10, $r->data()['depth']);
        self::assertCount(9, $r->data()['ancestors']);

        $tooDeep = $this->request('POST', '/api/v1/groups', ['name' => 'Level 11', 'parent_id' => $parent], $owner['token']);
        self::assertSame(422, $tooDeep->status());
        self::assertSame('depth_limit', $tooDeep->errorCode());
    }

    public function testNonMemberCannotReadGroupAndMissingGroupLooksTheSame(): void
    {
        $owner = $this->user();
        $outsider = $this->user();
        $gid = $this->createGroup($owner);

        $existing = $this->request('GET', "/api/v1/groups/{$gid}", [], $outsider['token']);
        $missing = $this->request('GET', '/api/v1/groups/999999', [], $outsider['token']);
        self::assertSame(403, $existing->status());
        self::assertSame($existing->json(), $missing->json());

        foreach (['members', 'subgroups', 'join-requests', 'invite-links'] as $sub) {
            self::assertSame(403, $this->request('GET', "/api/v1/groups/{$gid}/{$sub}", [], $outsider['token'])->status(), $sub);
        }
    }

    public function testMembershipIsNotInherited(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $root = $this->createGroup($owner);
        $child = $this->createGroup($owner, 'Child', $root);
        $this->join($owner, $member, $root);

        // Member of the parent is not a member of the child...
        self::assertSame(403, $this->request('GET', "/api/v1/groups/{$child}", [], $member['token'])->status());

        // ...and a member of only the child (legacy/inconsistent data) is not a member of the parent.
        $childOnly = $this->user();
        Database::execute(
            "INSERT INTO group_members (group_id, user_id, role, status, joined_at) VALUES (:g, :u, 'member', 'active', NOW())",
            ['g' => $child, 'u' => $childOnly['id']]
        );
        self::assertSame(200, $this->request('GET', "/api/v1/groups/{$child}", [], $childOnly['token'])->status());
        self::assertSame(403, $this->request('GET', "/api/v1/groups/{$root}", [], $childOnly['token'])->status());
    }

    public function testHiddenSubgroupNotListedToParentMembersListedOneIs(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $root = $this->createGroup($owner);
        $listed = $this->createGroup($owner, 'Listed', $root, ['visibility' => 'listed']);
        $hidden = $this->createGroup($owner, 'Hidden', $root, ['visibility' => 'hidden']);
        $this->join($owner, $member, $root);

        $memberView = $this->request('GET', "/api/v1/groups/{$root}/subgroups", [], $member['token']);
        self::assertSame(200, $memberView->status());
        self::assertSame([$listed], array_column($memberView->data(), 'id'));

        $ownerView = $this->request('GET', "/api/v1/groups/{$root}/subgroups", [], $owner['token']);
        $ids = array_column($ownerView->data(), 'id');
        sort($ids);
        self::assertSame([$listed, $hidden], $ids);
    }

    public function testOnlyAdminsUpdateGroup(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $member, $gid);

        self::assertSame(403, $this->request('PATCH', "/api/v1/groups/{$gid}", ['name' => 'X'], $member['token'])->status());
        $ok = $this->request('PATCH', "/api/v1/groups/{$gid}", ['name' => 'Renamed', 'approval_mode' => 'manual', 'description' => ''], $owner['token']);
        self::assertSame(200, $ok->status());
        self::assertSame('Renamed', $ok->data()['name']);
        self::assertSame('manual', $ok->data()['approval_mode']);
        self::assertSame(422, $this->request('PATCH', "/api/v1/groups/{$gid}", ['visibility' => 'secret'], $owner['token'])->status());
    }

    public function testOwnerCannotLeaveButCanTransfer(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $member, $gid);

        $leave = $this->request('POST', "/api/v1/groups/{$gid}/leave", [], $owner['token']);
        self::assertSame(422, $leave->status());
        self::assertSame('owner_protected', $leave->errorCode());

        self::assertSame(422, $this->request('PATCH', "/api/v1/groups/{$gid}/members/{$owner['id']}", ['role' => 'member'], $owner['token'])->status());

        $transfer = $this->request('POST', "/api/v1/groups/{$gid}/transfer-ownership", ['new_owner_id' => $member['id']], $owner['token']);
        self::assertSame(200, $transfer->status());

        $show = $this->request('GET', "/api/v1/groups/{$gid}", [], $member['token']);
        self::assertSame($member['id'], $show->data()['owner_user_id']);
        self::assertSame('admin', $show->data()['my_role']);

        self::assertSame(200, $this->request('POST', "/api/v1/groups/{$gid}/leave", [], $owner['token'])->status());
    }

    public function testTransferRequiresActiveMemberTarget(): void
    {
        $owner = $this->user();
        $outsider = $this->user();
        $gid = $this->createGroup($owner);
        $r = $this->request('POST', "/api/v1/groups/{$gid}/transfer-ownership", ['new_owner_id' => $outsider['id']], $owner['token']);
        self::assertSame(422, $r->status());
        self::assertSame('member_not_found', $r->errorCode());
    }

    public function testLastAdminCannotLeave(): void
    {
        $owner = $this->user();
        $admin = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $admin, $gid);
        $this->request('PATCH', "/api/v1/groups/{$gid}/members/{$admin['id']}", ['role' => 'admin'], $owner['token']);

        // Owner and admin are both admins: the non-owner admin may leave.
        // Simulate legacy data where the owner's membership is no longer active,
        // leaving $admin as the only admin.
        Database::execute("UPDATE group_members SET status = 'left' WHERE group_id = :g AND user_id = :u", ['g' => $gid, 'u' => $owner['id']]);

        $r = $this->request('POST', "/api/v1/groups/{$gid}/leave", [], $admin['token']);
        self::assertSame(422, $r->status());
        self::assertSame('last_admin', $r->errorCode());

        $demote = $this->request('PATCH', "/api/v1/groups/{$gid}/members/{$admin['id']}", ['role' => 'member'], $admin['token']);
        self::assertSame(422, $demote->status());
        self::assertSame('last_admin', $demote->errorCode());
    }

    public function testCascadeLeaveRemovesDescendants(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $root = $this->createGroup($owner, 'Root');
        $child = $this->createGroup($owner, 'Child', $root);
        $grandchild = $this->createGroup($owner, 'Grandchild', $child);
        $this->join($owner, $member, $root);
        $this->join($owner, $member, $child);
        $this->join($owner, $member, $grandchild);

        $r = $this->request('POST', "/api/v1/groups/{$root}/leave", [], $member['token']);
        self::assertSame(200, $r->status());
        self::assertSame([$root, $child, $grandchild], array_column($r->data()['left_groups'], 'group_id'));

        foreach ([$root, $child, $grandchild] as $gid) {
            self::assertSame(403, $this->request('GET', "/api/v1/groups/{$gid}", [], $member['token'])->status());
        }
    }

    public function testLeaveWithoutMembershipLeaksNothing(): void
    {
        $owner = $this->user();
        $outsider = $this->user();
        $gid = $this->createGroup($owner);
        $this->createGroup($owner, 'Child', $gid);

        $r = $this->request('POST', "/api/v1/groups/{$gid}/leave", [], $outsider['token']);
        self::assertSame(403, $r->status());
        self::assertSame('not_member', $r->errorCode());
        self::assertArrayNotHasKey('data', $r->json());
    }

    public function testOrphanProtectionBlocksLeaveWhileOwningSubgroup(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $root = $this->createGroup($owner, 'Root');
        $this->join($owner, $member, $root);
        $owned = $this->createGroup($member, 'Member-owned', $root);

        $r = $this->request('POST', "/api/v1/groups/{$root}/leave", [], $member['token']);
        self::assertSame(409, $r->status());
        self::assertSame('subgroup_handover_required', $r->errorCode());
        self::assertSame([['id' => $owned, 'name' => 'Member-owned', 'reason' => 'owner']], $r->json()['error']['details']['groups']);

        // Admin removal is blocked too, and does not name the subgroup.
        $remove = $this->request('DELETE', "/api/v1/groups/{$root}/members/{$member['id']}", [], $owner['token']);
        self::assertSame(409, $remove->status());
        self::assertSame('subgroup_handover_required', $remove->errorCode());
        self::assertArrayNotHasKey('details', $remove->json()['error']);

        // After handing over the subgroup, leaving works.
        $this->join($member, $owner, $owned);
        self::assertSame(200, $this->request('POST', "/api/v1/groups/{$owned}/transfer-ownership", ['new_owner_id' => $owner['id']], $member['token'])->status());
        self::assertSame(200, $this->request('POST', "/api/v1/groups/{$root}/leave", [], $member['token'])->status());

        $sub = $this->request('GET', "/api/v1/groups/{$owned}", [], $owner['token']);
        self::assertSame($owner['id'], $sub->data()['owner_user_id']);
    }

    public function testOrphanProtectionLastAdminOfDescendant(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $root = $this->createGroup($owner, 'Root');
        $this->join($owner, $member, $root);
        $child = $this->createGroup($owner, 'Child', $root);
        $this->join($owner, $member, $child);
        $this->request('PATCH', "/api/v1/groups/{$child}/members/{$member['id']}", ['role' => 'admin'], $owner['token']);
        // Simulate the owner's child membership being inactive (legacy data): member is the only admin.
        Database::execute("UPDATE group_members SET status = 'left' WHERE group_id = :g AND user_id = :u", ['g' => $child, 'u' => $owner['id']]);
        Database::execute('UPDATE `groups` SET owner_user_id = :u WHERE id = :g', ['u' => $owner['id'], 'g' => $child]);

        $r = $this->request('POST', "/api/v1/groups/{$root}/leave", [], $member['token']);
        self::assertSame(409, $r->status());
        self::assertSame('last_admin', $r->json()['error']['details']['groups'][0]['reason']);
    }

    public function testIndexListsOnlyMyActiveGroups(): void
    {
        $a = $this->user();
        $b = $this->user();
        $ga = $this->createGroup($a, 'A');
        $this->createGroup($b, 'B');
        $r = $this->request('GET', '/api/v1/groups', [], $a['token']);
        self::assertSame([$ga], array_column($r->data(), 'id'));
    }
}
