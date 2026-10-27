<?php
declare(strict_types=1);
namespace Circle\Tests;
use Circle\Core\Database;
use Circle\Media\ImageProcessingException;
use Circle\Media\MediaServices;
use Circle\Tests\Support\ImageFixtures;
final class GroupPhotoTest extends MediaTestCase
{
    public function testAdminUploadsBothKindsMembersReadAndMetadataTracksReplaceRemove(): void
    {
        $owner = $this->user('Owner'); $member = $this->user('Member'); $other = $this->user('Other');
        $gid = $this->createGroup($owner);
        Database::execute("INSERT INTO group_members (group_id,user_id,role,status) VALUES (:gid,:uid,'member','active')", ['gid' => $gid, 'uid' => $member['id']]);
        foreach (['avatar','cover'] as $kind) {
            $r = $this->requestRaw('PUT', "/api/v1/groups/$gid/photos/$kind", ImageFixtures::png(), $owner['token'], 'image/png');
            self::assertSame(200,$r->status()); self::assertMatchesRegularExpression('/^[a-f0-9-]{36}$/', $r->data()[$kind . '_version']);
            self::assertNull($r->data()['cover_path']);
            self::assertStringNotContainsString('storage_prefix', json_encode($r->json(), JSON_THROW_ON_ERROR));
            foreach (['thumb','medium','full'] as $size) {
                $read = $this->request('GET', "/api/v1/groups/$gid/photos/$kind?size=$size", [], $member['token']);
                self::assertSame(200,$read->status()); self::assertSame('private, no-store',$read->header('Cache-Control'));
                self::assertStringContainsString('FAKE-WEBP',$read->rawBody() ?? '');
            }
            self::assertSame(404,$this->request('GET', "/api/v1/groups/$gid/photos/$kind", [], $other['token'])->status());
            self::assertSame(403,$this->requestRaw('PUT', "/api/v1/groups/$gid/photos/$kind", ImageFixtures::png(), $member['token'], 'image/png')->status());
            self::assertSame(403,$this->request('DELETE', "/api/v1/groups/$gid/photos/$kind", [], $member['token'])->status());
        }
        self::assertCount(6,$this->storedFiles());
        $before=$this->request('GET',"/api/v1/groups/$gid",[],$owner['token'])->data()['avatar_version'];
        $new=$this->requestRaw('PUT',"/api/v1/groups/$gid/photos/avatar",ImageFixtures::png(),$owner['token'],'image/png')->data()['avatar_version'];
        self::assertNotSame($before,$new); self::assertCount(6,$this->storedFiles());
        $summary=$this->request('GET','/api/v1/groups',[],$member['token'])->data()[0]; self::assertSame($new,$summary['avatar_version']);
        foreach (['avatar','cover'] as $kind) {
            $removed=$this->request('DELETE',"/api/v1/groups/$gid/photos/$kind",[],$owner['token']); self::assertSame(200,$removed->status()); self::assertNull($removed->data()[$kind.'_version']);
            self::assertSame(404,$this->request('GET',"/api/v1/groups/$gid/photos/$kind",[],$member['token'])->status());
            self::assertSame(200,$this->request('DELETE',"/api/v1/groups/$gid/photos/$kind",[],$owner['token'])->status());
        }
        self::assertCount(0,$this->storedFiles());
    }
    public function testParentOnlyRemovedAndLoggedOutSessionsCannotAccessGroupBranding(): void
    {
        $owner=$this->user(); $parentMember=$this->user('Parent member');
        $parent=$this->createGroup($owner); $child=$this->createGroup($owner,'Child',$parent);
        Database::execute("INSERT INTO group_members (group_id,user_id,role,status) VALUES (:gid,:uid,'member','active')",['gid'=>$parent,'uid'=>$parentMember['id']]);
        self::assertSame(200,$this->requestRaw('PUT',"/api/v1/groups/$child/photos/avatar",ImageFixtures::png(),$owner['token'],'image/png')->status());
        self::assertSame(404,$this->request('GET',"/api/v1/groups/$child/photos/avatar",[],$parentMember['token'])->status());
        self::assertSame(403,$this->requestRaw('PUT',"/api/v1/groups/$child/photos/cover",ImageFixtures::png(),$parentMember['token'],'image/png')->status());
        Database::execute("INSERT INTO group_members (group_id,user_id,role,status) VALUES (:gid,:uid,'admin','active')",['gid'=>$child,'uid'=>$parentMember['id']]);
        self::assertSame(200,$this->requestRaw('PUT',"/api/v1/groups/$child/photos/cover",ImageFixtures::png(),$parentMember['token'],'image/png')->status());
        Database::execute("UPDATE group_members SET status='removed' WHERE group_id=:gid AND user_id=:uid",['gid'=>$child,'uid'=>$parentMember['id']]);
        self::assertSame(404,$this->request('GET',"/api/v1/groups/$child/photos/cover",[],$parentMember['token'])->status());
        self::assertSame(403,$this->request('DELETE',"/api/v1/groups/$child/photos/cover",[],$parentMember['token'])->status());
        $this->request('POST','/api/v1/auth/logout',[],$owner['token']);
        self::assertSame(401,$this->requestRaw('PUT',"/api/v1/groups/$child/photos/cover",ImageFixtures::png(),$owner['token'],'image/png')->status());
    }
    public function testPermissionLostDuringProcessingCannotReplaceCommittedPhoto(): void
    {
        $owner=$this->user(); $gid=$this->createGroup($owner);
        $path="/api/v1/groups/$gid/photos/avatar";
        $old=$this->requestRaw('PUT',$path,ImageFixtures::png(),$owner['token'],'image/png')->data()['avatar_version'];
        MediaServices::setProcessor(new class($this->processor, $gid, $owner['id']) implements \Circle\Media\ImageProcessor {
            public function __construct(private \Circle\Media\ImageProcessor $delegate, private int $group, private int $user) {}
            public function supports(string $mimeType): bool { return $this->delegate->supports($mimeType); }
            public function process(string $sourcePath, string $mimeType, array $targets, string $workDir): \Circle\Media\ProcessedImage {
                $image=$this->delegate->process($sourcePath,$mimeType,$targets,$workDir);
                Database::execute("UPDATE group_members SET role='member' WHERE group_id=:g AND user_id=:u", ['g'=>$this->group,'u'=>$this->user]);
                return $image;
            }
        });
        self::assertSame(403,$this->requestRaw('PUT',$path,ImageFixtures::png(),$owner['token'],'image/png')->status());
        self::assertSame($old,$this->request('GET',"/api/v1/groups/$gid",[],$owner['token'])->data()['avatar_version']);
        self::assertCount(3,$this->storedFiles());
    }
    public function testInvalidImageOrProcessingFailureKeepsPreviousGroupImage(): void
    {
        $owner=$this->user(); $gid=$this->createGroup($owner);
        $path="/api/v1/groups/$gid/photos/avatar";
        $old=$this->requestRaw('PUT',$path,ImageFixtures::png(),$owner['token'],'image/png')->data()['avatar_version'];
        foreach ([['invalid','image/png',415],[ImageFixtures::png(),'image/jpeg',422],[str_repeat('x',5242881),'image/png',413]] as [$bytes,$mime,$status]) self::assertSame($status,$this->requestRaw('PUT',$path,$bytes,$owner['token'],$mime)->status());
        $this->processor->failWith=new ImageProcessingException('Fictional processor failure');
        self::assertSame(422,$this->requestRaw('PUT',$path,ImageFixtures::png(),$owner['token'],'image/png')->status());
        self::assertSame($old,$this->request('GET',"/api/v1/groups/$gid",[],$owner['token'])->data()['avatar_version']); self::assertCount(3,$this->storedFiles());
        MediaServices::setProcessor(null); self::assertSame(503,$this->requestRaw('PUT',$path,ImageFixtures::png(),$owner['token'],'image/png')->status());
    }
}
