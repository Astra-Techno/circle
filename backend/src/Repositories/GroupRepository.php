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

        return self::normalise($group);
    }

    /**
     * @param array<string, mixed> $row
     * @return array<string, mixed>
     */
    private static function normalise(array $row): array
    {
        $row['id'] = (int) $row['id'];
        if (array_key_exists('parent_id', $row)) {
            $row['parent_id'] = $row['parent_id'] !== null ? (int) $row['parent_id'] : null;
        }
        if (array_key_exists('root_id', $row)) {
            $row['root_id'] = $row['root_id'] !== null ? (int) $row['root_id'] : null;
        }
        $row['depth'] = (int) $row['depth'];
        $row['owner_user_id'] = (int) $row['owner_user_id'];
        if (array_key_exists('member_count', $row)) {
            $row['member_count'] = (int) $row['member_count'];
        }
        return $row;
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

        return array_map(self::normalise(...), $rows);
    }

    /**
     * Direct child groups visible to a member of the parent: listed ones, plus
     * hidden ones the viewer is an active member of.
     * @return array<int, array<string, mixed>>
     */
    public static function getDirectChildren(int $groupId, int $viewerUserId): array
    {
        $rows = Database::query(
            'SELECT g.id, g.parent_id, g.depth, g.`type`, g.name, g.description, g.visibility, g.approval_mode,
                    g.owner_user_id, g.created_at,
                    gm.role AS my_role,
                    (SELECT COUNT(*) FROM group_members c WHERE c.group_id = g.id AND c.status = :s_count) AS member_count
             FROM `groups` g
             LEFT JOIN group_members gm ON g.id = gm.group_id AND gm.user_id = :uid AND gm.status = :s_join
             WHERE g.parent_id = :pid
               AND (g.visibility = :listed OR gm.user_id IS NOT NULL)
             ORDER BY g.name',
            ['s_count' => 'active', 'uid' => $viewerUserId, 's_join' => 'active', 'pid' => $groupId, 'listed' => 'listed']
        );

        return array_map(self::normalise(...), $rows);
    }

    /**
     * Get ancestor breadcrumb path for a group.
     * @return array<int, array<string, mixed>>
     */
    public static function getAncestors(int $groupId): array
    {
        $rows = Database::query(
            'SELECT g.id, g.name, g.depth
             FROM group_closure gc
             JOIN `groups` g ON gc.ancestor_id = g.id
             WHERE gc.descendant_id = :id AND gc.distance > 0
             ORDER BY gc.distance DESC',
            ['id' => $groupId]
        );
        return array_map(static fn (array $r): array => [
            'id' => (int) $r['id'],
            'name' => (string) $r['name'],
            'depth' => (int) $r['depth'],
        ], $rows);
    }

    /**
     * Get all descendant group IDs (for cascade operations), shallowest first.
     * @return int[]
     */
    public static function getDescendantIds(int $groupId): array
    {
        $rows = Database::query(
            'SELECT descendant_id FROM group_closure WHERE ancestor_id = :id AND distance > 0 ORDER BY distance',
            ['id' => $groupId]
        );
        return array_map(static fn (array $r): int => (int) $r['descendant_id'], $rows);
    }
}
