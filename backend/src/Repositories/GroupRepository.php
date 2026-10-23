<?php

declare(strict_types=1);

namespace Circle\Repositories;

use Circle\Core\Database;

final class GroupRepository
{
    /** @return array<string, mixed>|null */
    public static function findById(int $id): ?array
    {
        $group = Database::queryOne(
            'SELECT id, parent_id, root_id, depth, `type`, name, description, cover_path,
                    visibility, approval_mode, link_sharing, event_creation, owner_user_id,
                    created_at, updated_at
             FROM `groups` WHERE id = :id',
            ['id' => $id]
        );

        if ($group === null) {
            return null;
        }

        $group['id'] = (int) $group['id'];
        $group['parent_id'] = $group['parent_id'] !== null ? (int) $group['parent_id'] : null;
        $group['root_id'] = $group['root_id'] !== null ? (int) $group['root_id'] : null;
        $group['depth'] = (int) $group['depth'];
        $group['owner_user_id'] = (int) $group['owner_user_id'];

        return $group;
    }

    /**
     * Get all groups where user is an active member.
     * @return array<int, array<string, mixed>>
     */
    public static function findByUser(int $userId): array
    {
        $rows = Database::query(
            'SELECT g.id, g.parent_id, g.root_id, g.depth, g.`type`, g.name, g.description,
                    g.visibility, g.approval_mode, g.owner_user_id, g.created_at,
                    gm.role
             FROM `groups` g
             JOIN group_members gm ON g.id = gm.group_id
             WHERE gm.user_id = :uid AND gm.status = :s
             ORDER BY g.root_id, g.depth, g.name',
            ['uid' => $userId, 's' => 'active']
        );

        return array_map(fn($row) => [
            ...$row,
            'id' => (int) $row['id'],
            'parent_id' => $row['parent_id'] !== null ? (int) $row['parent_id'] : null,
            'root_id' => $row['root_id'] !== null ? (int) $row['root_id'] : null,
            'depth' => (int) $row['depth'],
            'owner_user_id' => (int) $row['owner_user_id'],
        ], $rows);
    }

    /**
     * Get direct child groups, respecting visibility for non-members.
     * @return array<int, array<string, mixed>>
     */
    public static function getDirectChildren(int $groupId, int $viewerUserId): array
    {
        return Database::query(
            'SELECT g.id, g.depth, g.`type`, g.name, g.description, g.visibility, g.approval_mode,
                    g.owner_user_id, g.created_at,
                    CASE WHEN gm.user_id IS NOT NULL THEN gm.role ELSE NULL END AS my_role,
                    (SELECT COUNT(*) FROM group_members WHERE group_id = g.id AND status = :s) AS member_count
             FROM `groups` g
             LEFT JOIN group_members gm ON g.id = gm.group_id AND gm.user_id = :uid AND gm.status = :s
             WHERE g.parent_id = :pid
               AND (g.visibility = :listed OR gm.user_id IS NOT NULL)
             ORDER BY g.name',
            ['pid' => $groupId, 'uid' => $viewerUserId, 's' => 'active', 'listed' => 'listed']
        );
    }

    /**
     * Get ancestor breadcrumb path for a group.
     * @return array<int, array{id: int, name: string, depth: int}>
     */
    public static function getAncestors(int $groupId): array
    {
        return Database::query(
            'SELECT g.id, g.name, g.depth
             FROM group_closure gc
             JOIN `groups` g ON gc.ancestor_id = g.id
             WHERE gc.descendant_id = :id AND gc.distance > 0
             ORDER BY gc.distance DESC',
            ['id' => $groupId]
        );
    }

    /**
     * Get all descendant group IDs (for cascade operations).
     * @return int[]
     */
    public static function getDescendantIds(int $groupId): array
    {
        $rows = Database::query(
            'SELECT descendant_id FROM group_closure WHERE ancestor_id = :id AND distance > 0',
            ['id' => $groupId]
        );
        return array_map(fn($r) => (int) $r['descendant_id'], $rows);
    }
}
