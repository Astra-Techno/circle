<?php

declare(strict_types=1);

namespace Circle\Tests;

use Circle\Controllers\GroupInvitationController;
use Circle\Core\Database;

final class GroupInvitationTest extends ApiTestCase
{
    public function testConsentRecipientPrivacyAndReplay(): void
    {
        $owner = $this->user('Fictional Host');
        $recipient = $this->user('Fictional Guest');
        $outsider = $this->user();
        $gid = $this->createGroup($owner, 'Hidden Circle', null, ['visibility' => 'hidden']);
        $first = $this->invite($owner, $recipient['mobile'], $gid);
        self::assertSame(200, $first->status());
        self::assertSame('invited', $first->data()['outcome']);
        $id = $first->data()['invitation_id'];
        self::assertNull($this->membership($gid, $recipient['id']));
        self::assertTrue(GroupInvitationController::eligible($id, $recipient['id']));
        self::assertFalse(GroupInvitationController::eligible($id, $outsider['id']));
        self::assertSame(403, $this->request('GET', "/api/v1/groups/{$gid}", [], $recipient['token'])->status());
        $detail = $this->request('GET', "/api/v1/group-invitations/{$id}", [], $recipient['token']);
        self::assertSame($recipient['id'], $detail->data()['invitation']['recipient_id']);
        self::assertSame('Hidden Circle', $detail->data()['invitation']['group_name']);
        self::assertSame('Fictional Host', $detail->data()['invitation']['inviter_name']);
        self::assertStringNotContainsString($recipient['mobile'], json_encode($detail->json()) ?: '');
        self::assertStringNotContainsString($owner['mobile'], json_encode($detail->json()) ?: '');
        $other = $this->request('GET', "/api/v1/group-invitations/{$id}", [], $outsider['token']);
        self::assertSame(404, $other->status());
        self::assertSame($other->json(), $this->request('GET', '/api/v1/group-invitations/999999', [], $outsider['token'])->json());
        self::assertSame(404, $this->action($owner, $id, 'accept')->status());
        self::assertSame(401, $this->request('GET', '/api/v1/me/group-invitations')->status());
        $list = $this->request('GET', '/api/v1/me/group-invitations?limit=1&offset=0', [], $recipient['token']);
        self::assertCount(1, $list->data());
        self::assertSame(1, $list->json()['pagination']['total']);
        self::assertSame([], $this->request('GET', '/api/v1/me/group-invitations', [], $outsider['token'])->data());
        self::assertSame('joined', $this->action($recipient, $id, 'accept')->data()['status']);
        self::assertSame('active', $this->membership($gid, $recipient['id'])['status']);
        self::assertFalse(GroupInvitationController::eligible($id, $recipient['id']));
        self::assertSame('accepted', $this->action($recipient, $id, 'accept')->data()['status']);
        $this->request('DELETE', "/api/v1/groups/{$gid}/members/{$recipient['id']}", [], $owner['token']);
        self::assertSame('accepted', $this->action($recipient, $id, 'accept')->data()['status']);
        self::assertSame('removed', $this->membership($gid, $recipient['id'])['status']);
    }

    public function testDeduplicationAndUnknownInactiveFallback(): void
    {
        $owner = $this->user();
        $recipient = $this->user();
        $gid = $this->createGroup($owner);
        $first = $this->invite($owner, $recipient['mobile'], $gid)->data();
        self::assertSame(['outcome' => 'already_pending', 'invitation_id' => $first['invitation_id']], $this->invite($owner, $recipient['mobile'], $gid)->data());
        self::assertSame(['outcome' => 'share_link'], $this->invite($owner, $this->nextMobile(), $gid)->data());
        Database::execute("UPDATE users SET status = 'suspended' WHERE id = :id", ['id' => $recipient['id']]);
        self::assertSame(['outcome' => 'share_link'], $this->invite($owner, $recipient['mobile'], $gid)->data());
        self::assertSame(['outcome' => 'already_member'], $this->invite($owner, $owner['mobile'], $gid)->data());
    }

    public function testExactSenderAndCurrentPolicy(): void
    {
        $owner = $this->user();
        $sender = $this->user();
        $recipient = $this->user();
        $gid = $this->createGroup($owner);
        self::assertSame(403, $this->invite($sender, $recipient['mobile'], $gid)->status());
        $this->join($owner, $sender, $gid);
        self::assertSame(403, $this->invite($sender, $recipient['mobile'], $gid)->status());
        Database::execute("UPDATE `groups` SET link_sharing = 'members' WHERE id = :id", ['id' => $gid]);
        $id = $this->invite($sender, $recipient['mobile'], $gid)->data()['invitation_id'];
        Database::execute("UPDATE `groups` SET link_sharing = 'admins' WHERE id = :id", ['id' => $gid]);
        self::assertFalse(GroupInvitationController::eligible($id, $recipient['id']));
        self::assertSame('invitation_unavailable', $this->action($recipient, $id, 'accept')->errorCode());
        $child = $this->createGroup($owner, 'Child', $gid);
        self::assertSame(403, $this->invite($sender, $recipient['mobile'], $child)->status());
    }

    public function testManualApprovalDependsOnInviterCurrentRole(): void
    {
        $owner = $this->user();
        $sender = $this->user();
        $recipient = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $sender, $gid);
        Database::execute("UPDATE `groups` SET link_sharing = 'members', approval_mode = 'manual' WHERE id = :id", ['id' => $gid]);
        $id = $this->invite($sender, $recipient['mobile'], $gid)->data()['invitation_id'];
        self::assertTrue($this->request('GET', "/api/v1/group-invitations/{$id}", [], $recipient['token'])->data()['invitation']['approval_required']);
        self::assertSame('pending_approval', $this->action($recipient, $id, 'accept')->data()['status']);
        self::assertNull($this->membership($gid, $recipient['id']));
        self::assertSame('pending', Database::queryOne('SELECT status FROM join_requests WHERE group_id = :g AND user_id = :u', ['g' => $gid, 'u' => $recipient['id']])['status']);
        $other = $this->user();
        $id = $this->invite($owner, $other['mobile'], $gid)->data()['invitation_id'];
        self::assertFalse($this->request('GET', "/api/v1/group-invitations/{$id}", [], $other['token'])->data()['invitation']['approval_required']);
        self::assertNull($this->membership($gid, $other['id']));
        self::assertSame('joined', $this->action($other, $id, 'accept')->data()['status']);
    }

    public function testParentRequiredOnCreateAndAccept(): void
    {
        $owner = $this->user();
        $recipient = $this->user();
        $parent = $this->createGroup($owner);
        $child = $this->createGroup($owner, 'Child', $parent);
        self::assertSame(['outcome' => 'unavailable'], $this->invite($owner, $recipient['mobile'], $child)->data());
        $this->join($owner, $recipient, $parent);
        $id = $this->invite($owner, $recipient['mobile'], $child)->data()['invitation_id'];
        $this->request('POST', "/api/v1/groups/{$parent}/leave", [], $recipient['token']);
        self::assertFalse(GroupInvitationController::eligible($id, $recipient['id']));
        self::assertSame(403, $this->action($recipient, $id, 'accept')->status());
        self::assertNull($this->membership($child, $recipient['id']));
    }

    public function testRemovalAndBansRequireNewAdminInvitation(): void
    {
        $owner = $this->user();
        $sender = $this->user();
        $recipient = $this->user();
        $gid = $this->createGroup($owner);
        $this->join($owner, $sender, $gid);
        Database::execute("UPDATE `groups` SET link_sharing = 'members' WHERE id = :id", ['id' => $gid]);
        $id = $this->invite($owner, $recipient['mobile'], $gid)->data()['invitation_id'];
        $this->join($owner, $recipient, $gid);
        self::assertSame(200, $this->request('DELETE', "/api/v1/groups/{$gid}/members/{$recipient['id']}", [], $owner['token'])->status());
        self::assertFalse(GroupInvitationController::eligible($id, $recipient['id']));
        self::assertSame(403, $this->action($recipient, $id, 'accept')->status());
        self::assertSame(['outcome' => 'unavailable'], $this->invite($sender, $recipient['mobile'], $gid)->data());
        Database::execute('UPDATE group_invitations SET updated_at = DATE_SUB(NOW(), INTERVAL 25 HOUR) WHERE id = :id', ['id' => $id]);
        $new = $this->invite($owner, $recipient['mobile'], $gid)->data();
        self::assertSame('invited', $new['outcome']);
        self::assertNotSame($id, $new['invitation_id']);
        Database::execute("UPDATE group_members SET status = 'banned' WHERE group_id = :g AND user_id = :u", ['g' => $gid, 'u' => $recipient['id']]);
        self::assertSame(['outcome' => 'unavailable'], $this->invite($owner, $recipient['mobile'], $gid)->data());
        self::assertSame(403, $this->action($recipient, $new['invitation_id'], 'accept')->status());
    }

    public function testDeclineCooldownAndExpiredInvitations(): void
    {
        $owner = $this->user();
        $recipient = $this->user();
        $gid = $this->createGroup($owner);
        $id = $this->invite($owner, $recipient['mobile'], $gid)->data()['invitation_id'];
        self::assertSame(422, $this->request('POST', "/api/v1/group-invitations/{$id}/decline", ['unexpected' => true], $recipient['token'])->status());
        self::assertSame('declined', $this->action($recipient, $id, 'decline')->data()['status']);
        self::assertSame('declined', $this->action($recipient, $id, 'decline')->data()['status']);
        self::assertSame(['outcome' => 'unavailable'], $this->invite($owner, $recipient['mobile'], $gid)->data());
        Database::execute('UPDATE group_invitations SET updated_at = DATE_SUB(NOW(), INTERVAL 25 HOUR) WHERE id = :id', ['id' => $id]);
        $new = $this->invite($owner, $recipient['mobile'], $gid)->data();
        self::assertSame('invited', $new['outcome']);
        self::assertNotSame($id, $new['invitation_id']);
        $newId = $new['invitation_id'];
        Database::execute('UPDATE group_invitations SET expires_at = DATE_SUB(NOW(), INTERVAL 1 SECOND) WHERE id = :id', ['id' => $newId]);
        self::assertSame('expired', $this->request('GET', "/api/v1/group-invitations/{$newId}", [], $recipient['token'])->data()['invitation']['status']);
        self::assertSame(410, $this->action($recipient, $newId, 'accept')->status());
        self::assertNull($this->membership($gid, $recipient['id']));
    }

    public function testAttemptBudgetIncludesUnknownAndDeniedLookups(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        for ($i = 0; $i < 20; $i++) {
            self::assertSame($i % 2 === 0 ? 200 : 403, $this->invite($owner, $this->nextMobile(), $i % 2 === 0 ? $gid : 999999)->status());
        }
        self::assertSame(429, $this->invite($owner, $this->nextMobile(), $gid)->status());
        self::assertSame(20, (int) Database::queryOne("SELECT COUNT(*) AS n FROM rate_limits WHERE ip = :key AND endpoint = 'contact_invitation'", ['key' => 'u:' . $owner['id']])['n']);
    }

    public function testStrictInput(): void
    {
        $owner = $this->user();
        $gid = $this->createGroup($owner);
        foreach ([[], ['mobile' => 123], ['mobile' => 'invalid'], ['mobile' => $owner['mobile'], 'user_id' => 1]] as $body) {
            self::assertSame(422, $this->request('POST', "/api/v1/groups/{$gid}/contact-invitations", $body, $owner['token'])->status());
        }
        self::assertSame(422, $this->requestRaw('POST', "/api/v1/groups/{$gid}/contact-invitations", '["not an object"]', $owner['token'], 'application/json')->status());
    }

    /** @param array{token:string} $sender */
    private function invite(array $sender, string $mobile, int $gid): TestResponse
    {
        return $this->request('POST', "/api/v1/groups/{$gid}/contact-invitations", ['mobile' => $mobile], $sender['token']);
    }

    /**
     * @param array{token:string} $recipient
     * @phpstan-impure
     */
    private function action(array $recipient, int $id, string $action): TestResponse
    {
        return $this->request('POST', "/api/v1/group-invitations/{$id}/{$action}", [], $recipient['token']);
    }

    /** @return array<string,mixed>|null */
    private function membership(int $gid, int $uid): ?array
    {
        return Database::queryOne('SELECT * FROM group_members WHERE group_id = :g AND user_id = :u', ['g' => $gid, 'u' => $uid]);
    }
}
