<?php

declare(strict_types=1);

namespace Circle\Controllers;

use Circle\Core\Database;
use Circle\Core\Request;
use Circle\Core\Response;

/**
 * Server-side search across the user's groups: memories, people, events and polls.
 * All results scoped to exact groups the caller is an active member of.
 */
final class SearchController
{
    public static function search(Request $r): void
    {
        $userId = $r->userId();
        $q = trim($r->query('q'));
        if ($q === '' || mb_strlen($q) > 200) {
            Response::validationError('q is required (1-200 characters).');
        }
        $limit = $r->queryInt('limit', 10, 1, 20);
        $like = '%' . self::escapeLike($q) . '%';

        // Memories
        $memories = Database::query(
            "SELECT m.id, m.group_id, g.name AS group_name, m.author_id, u.display_name AS author_name,
                    m.body, m.created_at
             FROM memories m
             JOIN group_members gm ON gm.group_id = m.group_id AND gm.user_id = :u AND gm.status = 'active'
             JOIN `groups` g ON g.id = m.group_id
             JOIN users u ON u.id = m.author_id
             WHERE m.status = 'active' AND m.body LIKE :q
             ORDER BY m.created_at DESC LIMIT :lim",
            ['u' => $userId, 'q' => $like, 'lim' => $limit]
        );

        // People (shared group members)
        $people = Database::query(
            "SELECT DISTINCT u.id, u.display_name, u.about
             FROM users u
             JOIN group_members gm ON gm.user_id = u.id AND gm.status = 'active'
             JOIN group_members my ON my.group_id = gm.group_id AND my.user_id = :u AND my.status = 'active'
             WHERE u.id != :u2 AND u.status = 'active' AND u.display_name LIKE :q
             ORDER BY u.display_name LIMIT :lim",
            ['u' => $userId, 'u2' => $userId, 'q' => $like, 'lim' => $limit]
        );

        // Events
        $events = Database::query(
            "SELECT e.id, e.group_id, g.name AS group_name, e.title, e.venue, e.start_at, e.status
             FROM events e
             JOIN group_members gm ON gm.group_id = e.group_id AND gm.user_id = :u AND gm.status = 'active'
             JOIN `groups` g ON g.id = e.group_id
             WHERE (e.title LIKE :q OR e.venue LIKE :q2 OR e.description LIKE :q3)
             ORDER BY e.start_at DESC LIMIT :lim",
            ['u' => $userId, 'q' => $like, 'q2' => $like, 'q3' => $like, 'lim' => $limit]
        );

        // Polls
        $polls = Database::query(
            "SELECT p.id, p.group_id, g.name AS group_name, p.question, p.closed_at, p.created_at
             FROM polls p
             JOIN group_members gm ON gm.group_id = p.group_id AND gm.user_id = :u AND gm.status = 'active'
             JOIN `groups` g ON g.id = p.group_id
             WHERE p.question LIKE :q
             ORDER BY p.created_at DESC LIMIT :lim",
            ['u' => $userId, 'q' => $like, 'lim' => $limit]
        );

        // Groups the user belongs to
        $groups = Database::query(
            "SELECT g.id, g.name, g.type, g.description
             FROM `groups` g
             JOIN group_members gm ON gm.group_id = g.id AND gm.user_id = :u AND gm.status = 'active'
             WHERE g.name LIKE :q
             ORDER BY g.name LIMIT :lim",
            ['u' => $userId, 'q' => $like, 'lim' => $limit]
        );

        Response::ok([
            'memories' => $memories,
            'people'   => $people,
            'events'   => $events,
            'polls'    => $polls,
            'groups'   => $groups,
        ]);
    }

    private static function escapeLike(string $s): string
    {
        return str_replace(['%', '_', '\\'], ['\\%', '\\_', '\\\\'], $s);
    }
}
