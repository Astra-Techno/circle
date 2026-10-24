<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Core\Database;

final class MembershipTest extends ApiTestCase
{
    public function testInvitePreviewAndAutoJoin(): void
    {
        $owner = $this->user();
        $joiner = $this->user();
        $gid = $this->createGroup($owner, 'Family');
        $token = $this->inviteToken($owner, $gid);

        $preview = $this->request('GET', "/api/v1/invites/{$token}");
        self::assertSame(200, $preview->status());
        self::assertSame('Family', $preview->data()['group_name']);
        self::assertFalse($preview->data()['approval_required']);
        self::assertSame(1, $preview->data()['member_count']);

        $join = $this->request('POST', "/api/v1/invites/{$token}/join", [], $joiner['token']);
        self::assertSame(200, $join->status());
        self::assertSame('joined', $join->data()['status']);
        self::assertSame(200, $this->request('GET', "/api/v1/groups/{$gid}", [], $joiner['token'])->status());

        $again = $this->request('POST', "/api/v1/invites/{$token}/join", [], $joiner['token']);
        self::assertSame(409, $again->status());
        self::assertSame('already_member', $again->errorCode());
    }

    public function testInviteDefaultsToSevenDaysAndValidatesRanges(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $r = $this->request('POST', "/api/v1/groups/{$gid}/invite-links", [], $owner['token']);
        self::assertSame(201, $r->status());
        $row = Database::queryOne('SELECT TIMESTAMPDIFF(HOUR, NOW(), expires_at) AS h FROM invite_links WHERE id = :id', ['id' => $r->data()['id']]);
        self::assertContains((int) ($row['h'] ?? 0), [167, 168]);

        foreach ([['max_uses' => 0], ['max_uses' => -5], ['expires_in_hours' => 0], ['expires_in_hours' => 100000], ['max_uses' => 'abc']] as $bad) {
            self::assertSame(422, $this->request('POST', "/api/v1/groups/{$gid}/invite-links", $bad, $owner['token'])->status(), (string) json_encode($bad));
        }
    }

    public function testOnlyAdminsCreateLinksWhenLinkSharingIsAdmins(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $member, $gid);

        self::assertSame(403, $this->request('POST', "/api/v1/groups/{$gid}/invite-links", [], $member['token'])->status());
        $this->request('PATCH', "/api/v1/groups/{$gid}", ['link_sharing' => 'members'], $owner['token']);
        self::assertSame(201, $this->request('POST', "/api/v1/groups/{$gid}/invite-links", [], $member['token'])->status());
    }

    public function testExpiredLinkFails(): void
    {
        $owner = $this->user();
        $joiner = $this->user();
        $gid = $this->createGroup($owner);
        $token = $this->inviteToken($owner, $gid);
        Database::execute('UPDATE invite_links SET expires_at = DATE_SUB(NOW(), INTERVAL 1 MINUTE)');

        $r = $this->request('POST', "/api/v1/invites/{$token}/join", [], $joiner['token']);
        self::assertSame(410, $r->status());
        self::assertSame('link_expired', $r->errorCode());
    }

    public function testUnknownLinkIsNotFound(): void
    {
        $r = $this->request('GET', '/api/v1/invites/' . str_repeat('a', 43));
        self::assertSame(404, $r->status());
    }

    public function testManualApprovalFlow(): void
    {
        $owner = $this->user();
        $joiner = $this->user('Ravi');
        $gid = $this->createGroup($owner, 'Club', null, ['approval_mode' => 'manual']);
        $token = $this->inviteToken($owner, $gid);

        $join = $this->request('POST', "/api/v1/invites/{$token}/join", [], $joiner['token']);
        self::assertSame(200, $join->status());
        self::assertSame('pending_approval', $join->data()['status']);
        self::assertSame(403, $this->request('GET', "/api/v1/groups/{$gid}", [], $joiner['token'])->status());

        // Re-requesting while pending is idempotent.
        self::assertSame('pending_approval', $this->request('POST', "/api/v1/invites/{$token}/join", [], $joiner['token'])->data()['status']);

        $list = $this->request('GET', "/api/v1/groups/{$gid}/join-requests", [], $owner['token']);
        self::assertSame(200, $list->status());
        self::assertCount(1, $list->data());
        self::assertSame('Ravi', $list->data()[0]['display_name']);
        self::assertArrayNotHasKey('mobile', $list->data()[0], 'Admins must not see requester mobile numbers');

        $rid = $list->data()[0]['id'];
        self::assertSame(200, $this->request('POST', "/api/v1/groups/{$gid}/join-requests/{$rid}/approve", [], $owner['token'])->status());
        self::assertSame(200, $this->request('GET', "/api/v1/groups/{$gid}", [], $joiner['token'])->status());
        self::assertSame(404, $this->request('POST', "/api/v1/groups/{$gid}/join-requests/{$rid}/approve", [], $owner['token'])->status());
    }

    public function testDeclineThenRequestAgain(): void
    {
        $owner = $this->user();
        $joiner = $this->user();
        $gid = $this->createGroup($owner, 'Club', null, ['approval_mode' => 'manual']);
        $token = $this->inviteToken($owner, $gid);

        for ($round = 0; $round < 2; $round++) {
            self::assertSame('pending_approval', $this->request('POST', "/api/v1/invites/{$token}/join", [], $joiner['token'])->data()['status']);
            $rid = $this->request('GET', "/api/v1/groups/{$gid}/join-requests", [], $owner['token'])->data()[0]['id'];
            self::assertSame(200, $this->request('POST', "/api/v1/groups/{$gid}/join-requests/{$rid}/decline", [], $owner['token'])->status());
        }
        $row = Database::queryOne("SELECT COUNT(*) AS c FROM join_requests WHERE status = 'declined'");
        self::assertSame(2, (int) ($row['c'] ?? 0));
    }

    public function testNonAdminCannotApprove(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $joiner = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $member, $gid);
        $this->request('PATCH', "/api/v1/groups/{$gid}", ['approval_mode' => 'manual'], $owner['token']);
        $token = $this->inviteToken($owner, $gid);
        $this->request('POST', "/api/v1/invites/{$token}/join", [], $joiner['token']);
        $rid = $this->request('GET', "/api/v1/groups/{$gid}/join-requests", [], $owner['token'])->data()[0]['id'];

        self::assertSame(403, $this->request('POST', "/api/v1/groups/{$gid}/join-requests/{$rid}/approve", [], $member['token'])->status());
    }

    public function testSubgroupLinkRequiresDirectParentMembership(): void
    {
        $owner = $this->user();
        $outsider = $this->user();
        $root = $this->createGroup($owner, 'Root');
        $child = $this->createGroup($owner, 'Child', $root);
        $grandchild = $this->createGroup($owner, 'Grandchild', $child);

        $r = $this->request('POST', '/api/v1/invites/' . $this->inviteToken($owner, $child) . '/join', [], $outsider['token']);
        self::assertSame(403, $r->status());
        self::assertSame('not_parent_member', $r->errorCode());

        // Member of the root but not of the direct parent (child) cannot join the grandchild.
        $this->join($owner, $outsider, $root);
        $r2 = $this->request('POST', '/api/v1/invites/' . $this->inviteToken($owner, $grandchild) . '/join', [], $outsider['token']);
        self::assertSame(403, $r2->status());
        self::assertSame('not_parent_member', $r2->errorCode());

        $this->join($owner, $outsider, $child);
        $this->join($owner, $outsider, $grandchild);
    }

    public function testApprovalRechecksParentMembership(): void
    {
        $owner = $this->user();
        $joiner = $this->user();
        $root = $this->createGroup($owner, 'Root');
        $child = $this->createGroup($owner, 'Child', $root, ['approval_mode' => 'manual']);
        $this->join($owner, $joiner, $root);

        $token = $this->inviteToken($owner, $child);
        self::assertSame('pending_approval', $this->request('POST', "/api/v1/invites/{$token}/join", [], $joiner['token'])->data()['status']);
        $rid = (int) $this->request('GET', "/api/v1/groups/{$child}/join-requests", [], $owner['token'])->data()[0]['id'];

        // Parent membership ends without going through leave (e.g. direct data change).
        Database::execute("UPDATE group_members SET status = 'left' WHERE group_id = :g AND user_id = :u", ['g' => $root, 'u' => $joiner['id']]);

        $r = $this->request('POST', "/api/v1/groups/{$child}/join-requests/{$rid}/approve", [], $owner['token']);
        self::assertSame(409, $r->status());
        self::assertSame('not_parent_member', $r->errorCode());
        self::assertSame(403, $this->request('GET', "/api/v1/groups/{$child}", [], $joiner['token'])->status());
        $row = Database::queryOne('SELECT status FROM join_requests WHERE id = :id', ['id' => $rid]);
        self::assertSame('cancelled', $row['status'] ?? null);
    }

    public function testLeavingParentCancelsPendingDescendantRequests(): void
    {
        $owner = $this->user();
        $joiner = $this->user();
        $root = $this->createGroup($owner, 'Root');
        $child = $this->createGroup($owner, 'Child', $root, ['approval_mode' => 'manual']);
        $this->join($owner, $joiner, $root);
        $this->request('POST', '/api/v1/invites/' . $this->inviteToken($owner, $child) . '/join', [], $joiner['token']);

        self::assertSame(200, $this->request('POST', "/api/v1/groups/{$root}/leave", [], $joiner['token'])->status());
        self::assertSame([], $this->request('GET', "/api/v1/groups/{$child}/join-requests", [], $owner['token'])->data());
    }

    public function testRevokedLinkFails(): void
    {
        $owner = $this->user();
        $joiner = $this->user();
        $gid = $this->createGroup($owner);
        $token = $this->inviteToken($owner, $gid);
        $links = $this->request('GET', "/api/v1/groups/{$gid}/invite-links", [], $owner['token']);
        self::assertSame(200, $links->status());
        self::assertSame('active', $links->data()[0]['status']);
        self::assertArrayNotHasKey('token', $links->data()[0]);
        $linkId = $links->data()[0]['id'];

        self::assertSame(200, $this->request('DELETE', "/api/v1/groups/{$gid}/invite-links/{$linkId}", [], $owner['token'])->status());

        $preview = $this->request('GET', "/api/v1/invites/{$token}");
        self::assertSame(410, $preview->status());
        self::assertSame('link_revoked', $preview->errorCode());
        self::assertSame(410, $this->request('POST', "/api/v1/invites/{$token}/join", [], $joiner['token'])->status());
        self::assertSame('revoked', $this->request('GET', "/api/v1/groups/{$gid}/invite-links", [], $owner['token'])->data()[0]['status']);
    }

    public function testResetRevokesAllAndReturnsNewLink(): void
    {
        $owner = $this->user();
        $joiner = $this->user();
        $gid = $this->createGroup($owner);
        $old1 = $this->inviteToken($owner, $gid);
        $old2 = $this->inviteToken($owner, $gid);

        $reset = $this->request('POST', "/api/v1/groups/{$gid}/invite-links/reset", [], $owner['token']);
        self::assertSame(201, $reset->status());
        self::assertSame(410, $this->request('GET', "/api/v1/invites/{$old1}")->status());
        self::assertSame(410, $this->request('GET', "/api/v1/invites/{$old2}")->status());
        self::assertSame(200, $this->request('POST', '/api/v1/invites/' . $reset->data()['token'] . '/join', [], $joiner['token'])->status());
    }

    public function testMemberCanRevokeOwnLinkButNotOthers(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $gid = $this->createGroup($owner, 'G', null);
        $this->request('PATCH', "/api/v1/groups/{$gid}", ['link_sharing' => 'members'], $owner['token']);
        $this->join($owner, $member, $gid);
        $this->inviteToken($member, $gid);
        $links = $this->request('GET', "/api/v1/groups/{$gid}/invite-links", [], $owner['token'])->data();
        $byId = [];
        foreach ($links as $l) {
            $byId[$l['created_by']][] = $l['id'];
        }
        self::assertSame(403, $this->request('DELETE', "/api/v1/groups/{$gid}/invite-links/{$byId[$owner['id']][0]}", [], $member['token'])->status());
        self::assertSame(200, $this->request('DELETE', "/api/v1/groups/{$gid}/invite-links/{$byId[$member['id']][0]}", [], $member['token'])->status());
        self::assertSame(403, $this->request('GET', "/api/v1/groups/{$gid}/invite-links", [], $member['token'])->status());
    }

    public function testMaxUsesEnforced(): void
    {
        $owner = $this->user();
        $a = $this->user();
        $b = $this->user();
        $gid = $this->createGroup($owner);
        $token = $this->inviteToken($owner, $gid, ['max_uses' => 1]);

        self::assertSame(200, $this->request('POST', "/api/v1/invites/{$token}/join", [], $a['token'])->status());
        $r = $this->request('POST', "/api/v1/invites/{$token}/join", [], $b['token']);
        self::assertSame(410, $r->status());
        self::assertSame('link_exhausted', $r->errorCode());
    }

    public function testRemovedMemberNeedsLinkCreatedAfterRemoval(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $gid = $this->createGroup($owner);
        $oldToken = $this->inviteToken($owner, $gid);
        self::assertSame(200, $this->request('POST', "/api/v1/invites/{$oldToken}/join", [], $member['token'])->status());

        self::assertSame(200, $this->request('DELETE', "/api/v1/groups/{$gid}/members/{$member['id']}", [], $owner['token'])->status());
        self::assertSame(403, $this->request('GET', "/api/v1/groups/{$gid}", [], $member['token'])->status());

        $old = $this->request('POST', "/api/v1/invites/{$oldToken}/join", [], $member['token']);
        self::assertSame(403, $old->status());
        self::assertSame('join_not_allowed', $old->errorCode());

        $newToken = $this->inviteToken($owner, $gid);
        $rejoin = $this->request('POST', "/api/v1/invites/{$newToken}/join", [], $member['token']);
        self::assertSame(200, $rejoin->status());
        // Re-joining never restores a previous admin role.
        self::assertSame('member', $this->request('GET', "/api/v1/groups/{$gid}", [], $member['token'])->data()['my_role']);
    }

    public function testLeftMemberCanRejoinWithAnyValidLink(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $gid = $this->createGroup($owner);
        $token = $this->inviteToken($owner, $gid);
        $this->request('POST', "/api/v1/invites/{$token}/join", [], $member['token']);
        $this->request('POST', "/api/v1/groups/{$gid}/leave", [], $member['token']);
        self::assertSame(200, $this->request('POST', "/api/v1/invites/{$token}/join", [], $member['token'])->status());
    }

    public function testBannedCannotRejoinEvenWithNewLinkUntilUnbanned(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $member, $gid);

        self::assertSame(200, $this->request('DELETE', "/api/v1/groups/{$gid}/members/{$member['id']}?ban=true", [], $owner['token'])->status());

        $r = $this->request('POST', '/api/v1/invites/' . $this->inviteToken($owner, $gid) . '/join', [], $member['token']);
        self::assertSame(403, $r->status());
        self::assertSame('join_not_allowed', $r->errorCode());

        // Approval cannot reactivate a banned member either.
        $this->request('PATCH', "/api/v1/groups/{$gid}", ['approval_mode' => 'manual'], $owner['token']);
        Database::execute("INSERT INTO join_requests (group_id, user_id, status) VALUES (:g, :u, 'pending')", ['g' => $gid, 'u' => $member['id']]);
        $rid = Database::lastInsertId();
        $approve = $this->request('POST', "/api/v1/groups/{$gid}/join-requests/{$rid}/approve", [], $owner['token']);
        self::assertSame(409, $approve->status());
        self::assertSame(403, $this->request('GET', "/api/v1/groups/{$gid}", [], $member['token'])->status());

        self::assertSame(200, $this->request('POST', "/api/v1/groups/{$gid}/members/{$member['id']}/unban", [], $owner['token'])->status());
        $this->request('PATCH', "/api/v1/groups/{$gid}", ['approval_mode' => 'auto'], $owner['token']);
        $this->join($owner, $member, $gid);
    }

    public function testRemovalCascadesToDescendants(): void
    {
        $owner = $this->user();
        $member = $this->user();
        $root = $this->createGroup($owner);
        $child = $this->createGroup($owner, 'Child', $root);
        $this->join($owner, $member, $root);
        $this->join($owner, $member, $child);

        self::assertSame(200, $this->request('DELETE', "/api/v1/groups/{$root}/members/{$member['id']}", [], $owner['token'])->status());
        self::assertSame(403, $this->request('GET', "/api/v1/groups/{$child}", [], $member['token'])->status());
    }

    public function testRemovalErrors(): void
    {
        $owner = $this->user();
        $admin = $this->user();
        $member = $this->user();
        $outsider = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $admin, $gid);
        $this->join($owner, $member, $gid);
        $this->request('PATCH', "/api/v1/groups/{$gid}/members/{$admin['id']}", ['role' => 'admin'], $owner['token']);

        self::assertSame('owner_protected', $this->request('DELETE', "/api/v1/groups/{$gid}/members/{$owner['id']}", [], $admin['token'])->errorCode());
        self::assertSame(403, $this->request('DELETE', "/api/v1/groups/{$gid}/members/{$admin['id']}", [], $member['token'])->status());
        self::assertSame(404, $this->request('DELETE', "/api/v1/groups/{$gid}/members/{$outsider['id']}", [], $owner['token'])->status());
        self::assertSame(422, $this->request('DELETE', "/api/v1/groups/{$gid}/members/{$admin['id']}", [], $admin['token'])->status());
    }

    public function testMembersListHasNoMobileNumbers(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        $r = $this->request('GET', "/api/v1/groups/{$gid}/members?limit=-5&offset=-1", [], $owner['token']);
        self::assertSame(200, $r->status());
        self::assertSame(1, $r->json()['pagination']['limit']);
        self::assertSame(0, $r->json()['pagination']['offset']);
        self::assertArrayNotHasKey('mobile', $r->data()[0]);
        self::assertTrue($r->data()[0]['is_owner']);
    }
}
