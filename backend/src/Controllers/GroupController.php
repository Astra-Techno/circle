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
    public const MAX_DEPTH = 10;

    public static function index(Request $request): void
    {
        Response::ok(GroupPhotoController::attachVersions(GroupRepository::findByUser($request->userId())));
    }

    public static function show(Request $request): void
    {
        $userId = $request->userId();
        $groupId = (int) $request->param('id');

        MemberRepository::requireActiveMember($groupId, $userId);

        $group = GroupRepository::findById($groupId);
        if ($group === null) {
            Response::error('not_member', 'You are not a member of this group.', 403);
        }

        $group = GroupPhotoController::attachVersions([$group])[0];
        $group['member_count'] = MemberRepository::countActive($groupId);
        $group['my_role'] = MemberRepository::getRole($groupId, $userId);
        $group['ancestors'] = GroupRepository::getAncestors($groupId);

        Response::ok($group);
    }

    /**
     * Any user may create a root group; any active member of a group may create
     * a subgroup inside it. The creator becomes owner and admin.
     */
    public static function create(Request $request): void
    {
        $userId = $request->userId();
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
            if (!is_int($parentId) && !(is_string($parentId) && ctype_digit($parentId))) {
                Response::validationError('parent_id must be a group id.');
            }
            $parentIdInt = (int) $parentId;

            // Must be an active member of the (exact) parent group.
            MemberRepository::requireActiveMember($parentIdInt, $userId);

            $parent = GroupRepository::findById($parentIdInt);
            if ($parent === null) {
                Response::error('not_member', 'You are not a member of this group.', 403);
            }

            $depth = (int) $parent['depth'] + 1;
            if ($depth > self::MAX_DEPTH) {
                Response::error('depth_limit', 'Maximum nesting depth of ' . self::MAX_DEPTH . ' levels reached.', 422);
            }

            $rootId = $parent['root_id'] ?? $parent['id'];
        }

        $groupId = Database::transaction(static function () use (
            $parentIdInt, $rootId, $depth, $type, $name, $description, $visibility, $approvalMode, $userId
        ): int {
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

            $groupId = Database::lastInsertId();

            // Root groups reference themselves as root.
            if ($rootId === null) {
                Database::execute(
                    'UPDATE `groups` SET root_id = :root WHERE id = :id',
                    ['root' => $groupId, 'id' => $groupId]
                );
            }

            // Closure table: self-reference plus a copy of the parent's ancestors.
            Database::execute(
                'INSERT INTO group_closure (ancestor_id, descendant_id, distance) VALUES (:id, :id2, 0)',
                ['id' => $groupId, 'id2' => $groupId]
            );

            if ($parentIdInt !== null) {
                Database::execute(
                    'INSERT INTO group_closure (ancestor_id, descendant_id, distance)
                     SELECT ancestor_id, :desc, distance + 1
                     FROM group_closure WHERE descendant_id = :parent',
                    ['desc' => $groupId, 'parent' => $parentIdInt]
                );
            }

            MemberRepository::addMember($groupId, $userId, 'admin', $userId);

            return $groupId;
        });

        Response::created(GroupRepository::findById($groupId), 'Group created.');
    }

    public static function update(Request $request): void
    {
        $userId = $request->userId();
        $groupId = (int) $request->param('id');

        MemberRepository::requireAdmin($groupId, $userId);

        $sets = [];
        $params = ['id' => $groupId];

        if ($request->has('name')) {
            $name = $request->string('name');
            (new Validator())->string('name', $name, 1, 100)->bail();
            $sets[] = 'name = :name';
            $params['name'] = $name;
        }

        if ($request->has('description')) {
            $desc = $request->string('description');
            (new Validator())->string('description', $desc, 0, 1000, 'Description')->bail();
            $sets[] = 'description = :desc';
            $params['desc'] = $desc;
        }

        $enums = [
            'type' => ['`type`', self::TYPES],
            'approval_mode' => ['approval_mode', ['auto', 'manual']],
            'visibility' => ['visibility', ['listed', 'hidden']],
            'link_sharing' => ['link_sharing', ['admins', 'members']],
        ];
        foreach ($enums as $field => [$column, $allowed]) {
            if ($request->has($field)) {
                $value = $request->string($field);
                (new Validator())->enum($field, $value, $allowed)->bail();
                $sets[] = "{$column} = :{$field}";
                $params[$field] = $value;
            }
        }

        if ($sets === []) {
            Response::validationError('No fields to update.');
        }

        Database::execute(
            'UPDATE `groups` SET ' . implode(', ', $sets) . ' WHERE id = :id',
            $params
        );

        Response::ok(GroupRepository::findById($groupId), 'Group updated.');
    }

    public static function subgroups(Request $request): void
    {
        $userId = $request->userId();
        $groupId = (int) $request->param('id');

        MemberRepository::requireActiveMember($groupId, $userId);

        Response::ok(GroupRepository::getDirectChildren($groupId, $userId));
    }

    /**
     * Leaving cascades to every descendant group. It is refused while the
     * person owns, or is the last admin of, this group or any descendant they
     * belong to: ownership/admin must be handed over first (no orphan groups).
     */
    public static function leave(Request $request): void
    {
        $userId = $request->userId();
        $groupId = (int) $request->param('id');

        MemberRepository::requireActiveMember($groupId, $userId);

        $group = GroupRepository::findById($groupId);
        if ($group === null) {
            Response::error('not_member', 'You are not a member of this group.', 403);
        }

        if ((int) $group['owner_user_id'] === $userId) {
            Response::error('owner_protected', 'Transfer ownership before leaving.', 422);
        }

        $blockers = MemberRepository::exitBlockers($groupId, $userId);
        foreach ($blockers as $b) {
            if ($b['id'] === $groupId && $b['reason'] === 'last_admin') {
                Response::error('last_admin', 'Promote another admin before leaving.', 422);
            }
        }
        if ($blockers !== []) {
            Response::error(
                'subgroup_handover_required',
                'You own or are the only admin of subgroups inside this group. Transfer ownership or promote another admin there first.',
                409,
                ['groups' => $blockers]
            );
        }

        $left = Database::transaction(
            static fn (): array => MemberRepository::cascadeExit($groupId, $userId, 'left')
        );

        Response::ok(
            ['left_groups' => array_map(static fn (int $id): array => ['group_id' => $id], $left)],
            'Left group and all subgroups.'
        );
    }

    public static function transferOwnership(Request $request): void
    {
        $userId = $request->userId();
        $groupId = (int) $request->param('id');
        $newOwnerId = $request->int('new_owner_id');

        MemberRepository::requireActiveMember($groupId, $userId);

        $group = GroupRepository::findById($groupId);
        if ($group === null || (int) $group['owner_user_id'] !== $userId) {
            Response::forbidden('Only the owner can transfer ownership.');
        }

        if ($newOwnerId === $userId) {
            Response::validationError('You already own this group.');
        }

        if (!MemberRepository::isActiveMember($groupId, $newOwnerId)) {
            Response::error('member_not_found', 'The new owner must be an active member of this group.', 422);
        }

        Database::transaction(static function () use ($groupId, $newOwnerId): void {
            Database::execute(
                'UPDATE `groups` SET owner_user_id = :new WHERE id = :id',
                ['new' => $newOwnerId, 'id' => $groupId]
            );
            // The owner is always an admin. The previous owner stays an admin.
            MemberRepository::ensureAdmin($groupId, $newOwnerId);
        });

        Response::ok(null, 'Ownership transferred.');
    }
}
