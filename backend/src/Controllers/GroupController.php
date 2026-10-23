<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Core\Validator;
use Circle\Repositories\GroupRepository;
use Circle\Repositories\MemberRepository;

final class GroupController
{
    private const TYPES = ['family', 'friends', 'school', 'college', 'office', 'club', 'other'];
    private const MAX_DEPTH = 10;

    public static function index(Request $request): void
    {
        $userId = $request->attr('user_id');
        $groups = GroupRepository::findByUser((int) $userId);

        Response::ok($groups);
    }

    public static function show(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $groupId = (int) $request->param('id');

        MemberRepository::requireActiveMember($groupId, $userId);

        $group = GroupRepository::findById($groupId);
        if ($group === null) {
            Response::notFound('Group not found.');
        }

        $group['member_count'] = MemberRepository::countActive($groupId);
        $group['my_role'] = MemberRepository::getRole($groupId, $userId);
        $group['ancestors'] = GroupRepository::getAncestors($groupId);

        Response::ok($group);
    }

    public static function create(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $name = $request->string('name');
        $type = $request->string('type', 'other');
        $description = $request->string('description');
        $parentId = $request->input('parent_id');
        $visibility = $request->string('visibility', 'listed');
        $approvalMode = $request->string('approval_mode', 'auto');

        $v = new Validator();
        $v->required('name', $name)->string('name', $name, 1, 100);
        $v->enum('type', $type, self::TYPES);
        $v->string('description', $description, 0, 1000, 'Description');
        $v->enum('visibility', $visibility, ['listed', 'hidden']);
        $v->enum('approval_mode', $approvalMode, ['auto', 'manual']);
        $v->bail();

        $depth = 1;
        $rootId = null;
        $parentIdInt = null;

        if ($parentId !== null && $parentId !== '') {
            $parentIdInt = (int) $parentId;

            // Must be a member of the parent group
            MemberRepository::requireActiveMember($parentIdInt, $userId);

            $parent = GroupRepository::findById($parentIdInt);
            if ($parent === null) {
                Response::notFound('Parent group not found.');
            }

            $depth = (int) $parent['depth'] + 1;
            if ($depth > self::MAX_DEPTH) {
                Response::error('depth_limit', 'Maximum nesting depth of ' . self::MAX_DEPTH . ' levels reached.', 422);
            }

            $rootId = $parent['root_id'] ?? $parent['id'];
        }

        Database::beginTransaction();
        try {
            Database::execute(
                'INSERT INTO `groups` (parent_id, root_id, depth, `type`, name, description, visibility, approval_mode, owner_user_id)
                 VALUES (:parent, :root, :depth, :type, :name, :desc, :vis, :approval, :owner)',
                [
                    'parent' => $parentIdInt,
                    'root' => $rootId,
                    'depth' => $depth,
                    'type' => $type,
                    'name' => $name,
                    'desc' => $description,
                    'vis' => $visibility,
                    'approval' => $approvalMode,
                    'owner' => $userId,
                ]
            );

            $groupId = (int) Database::lastInsertId();

            // Set root_id for root groups (self-referencing)
            if ($rootId === null) {
                Database::execute(
                    'UPDATE `groups` SET root_id = :id WHERE id = :id',
                    ['id' => $groupId]
                );
                $rootId = $groupId;
            }

            // Insert closure table entries
            // Self-reference
            Database::execute(
                'INSERT INTO group_closure (ancestor_id, descendant_id, distance) VALUES (:id, :id2, 0)',
                ['id' => $groupId, 'id2' => $groupId]
            );

            // Copy ancestor entries from parent
            if ($parentIdInt !== null) {
                Database::execute(
                    'INSERT INTO group_closure (ancestor_id, descendant_id, distance)
                     SELECT ancestor_id, :desc, distance + 1
                     FROM group_closure WHERE descendant_id = :parent',
                    ['desc' => $groupId, 'parent' => $parentIdInt]
                );
            }

            // Add creator as owner (admin role)
            MemberRepository::addMember($groupId, $userId, 'admin', 'active');

            Database::commit();

            $group = GroupRepository::findById($groupId);
            Response::created($group, 'Group created.');

        } catch (\Throwable $e) {
            Database::rollback();
            Response::serverError('Failed to create group.');
        }
    }

    public static function update(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $groupId = (int) $request->param('id');

        MemberRepository::requireAdmin($groupId, $userId);

        $sets = [];
        $params = ['id' => $groupId];

        $name = $request->string('name');
        if ($name !== '') {
            (new Validator())->string('name', $name, 1, 100)->bail();
            $sets[] = 'name = :name';
            $params['name'] = $name;
        }

        $desc = $request->string('description');
        if ($desc !== '') {
            $sets[] = 'description = :desc';
            $params['desc'] = $desc;
        }

        $type = $request->string('type');
        if ($type !== '') {
            (new Validator())->enum('type', $type, self::TYPES)->bail();
            $sets[] = '`type` = :type';
            $params['type'] = $type;
        }

        $approval = $request->string('approval_mode');
        if ($approval !== '') {
            (new Validator())->enum('approval_mode', $approval, ['auto', 'manual'])->bail();
            $sets[] = 'approval_mode = :approval';
            $params['approval'] = $approval;
        }

        $visibility = $request->string('visibility');
        if ($visibility !== '') {
            (new Validator())->enum('visibility', $visibility, ['listed', 'hidden'])->bail();
            $sets[] = 'visibility = :vis';
            $params['vis'] = $visibility;
        }

        $linkSharing = $request->string('link_sharing');
        if ($linkSharing !== '') {
            (new Validator())->enum('link_sharing', $linkSharing, ['admins', 'members'])->bail();
            $sets[] = 'link_sharing = :ls';
            $params['ls'] = $linkSharing;
        }

        if ($sets === []) {
            Response::validationError('No fields to update.');
        }

        Database::execute(
            'UPDATE `groups` SET ' . implode(', ', $sets) . ' WHERE id = :id',
            $params
        );

        $group = GroupRepository::findById($groupId);
        Response::ok($group, 'Group updated.');
    }

    public static function subgroups(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $groupId = (int) $request->param('id');

        MemberRepository::requireActiveMember($groupId, $userId);

        $subgroups = GroupRepository::getDirectChildren($groupId, $userId);
        Response::ok($subgroups);
    }

    public static function leave(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $groupId = (int) $request->param('id');

        $group = GroupRepository::findById($groupId);
        if ($group === null) {
            Response::notFound('Group not found.');
        }

        // Owner cannot leave without transferring ownership
        if ((int) $group['owner_user_id'] === $userId) {
            Response::error('owner_protected', 'Transfer ownership before leaving.', 422);
        }

        // Last admin cannot leave
        $role = MemberRepository::getRole($groupId, $userId);
        if ($role === 'admin') {
            $adminCount = MemberRepository::countAdmins($groupId);
            if ($adminCount <= 1) {
                Response::error('last_admin', 'Promote another admin before leaving.', 422);
            }
        }

        // Cascade: leave this group and all descendant groups
        Database::beginTransaction();
        try {
            $descendantIds = GroupRepository::getDescendantIds($groupId);
            $allGroupIds = array_merge([$groupId], $descendantIds);

            foreach ($allGroupIds as $gid) {
                MemberRepository::removeMember($gid, $userId, 'left');
            }

            Database::commit();

            $affectedGroups = array_map(fn($id) => ['group_id' => $id], $allGroupIds);
            Response::ok(['left_groups' => $affectedGroups], 'Left group and all subgroups.');

        } catch (\Throwable $e) {
            Database::rollback();
            Response::serverError('Failed to leave group.');
        }
    }

    public static function transferOwnership(Request $request): void
    {
        $userId = (int) $request->attr('user_id');
        $groupId = (int) $request->param('id');
        $newOwnerId = $request->int('new_owner_id');

        $group = GroupRepository::findById($groupId);
        if ($group === null) {
            Response::notFound('Group not found.');
        }

        if ((int) $group['owner_user_id'] !== $userId) {
            Response::forbidden('Only the owner can transfer ownership.');
        }

        MemberRepository::requireActiveMember($groupId, $newOwnerId);

        Database::beginTransaction();
        try {
            Database::execute(
                'UPDATE `groups` SET owner_user_id = :new WHERE id = :id',
                ['new' => $newOwnerId, 'id' => $groupId]
            );

            // Ensure new owner is admin
            MemberRepository::ensureAdmin($groupId, $newOwnerId);

            Database::commit();
            Response::ok(null, 'Ownership transferred.');

        } catch (\Throwable $e) {
            Database::rollback();
            Response::serverError('Failed to transfer ownership.');
        }
    }
}
