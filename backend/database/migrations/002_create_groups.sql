CREATE TABLE IF NOT EXISTS `groups` (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    parent_id BIGINT UNSIGNED NULL,
    root_id BIGINT UNSIGNED NULL,
    depth TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `type` ENUM('family', 'friends', 'school', 'college', 'office', 'club', 'other') NOT NULL DEFAULT 'other',
    name VARCHAR(100) NOT NULL,
    description VARCHAR(1000) NOT NULL DEFAULT '',
    cover_path VARCHAR(500) NULL,
    visibility ENUM('listed', 'hidden') NOT NULL DEFAULT 'listed',
    approval_mode ENUM('auto', 'manual') NOT NULL DEFAULT 'auto',
    link_sharing ENUM('admins', 'members') NOT NULL DEFAULT 'admins',
    event_creation ENUM('members', 'admins') NOT NULL DEFAULT 'members',
    owner_user_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_id) REFERENCES `groups`(id) ON DELETE SET NULL,
    FOREIGN KEY (owner_user_id) REFERENCES users(id),
    INDEX idx_groups_parent (parent_id),
    INDEX idx_groups_root (root_id),
    INDEX idx_groups_owner (owner_user_id),
    INDEX idx_groups_depth (depth)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Closure table for fast subtree queries and cascade operations
CREATE TABLE IF NOT EXISTS group_closure (
    ancestor_id BIGINT UNSIGNED NOT NULL,
    descendant_id BIGINT UNSIGNED NOT NULL,
    distance INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (ancestor_id, descendant_id),
    FOREIGN KEY (ancestor_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    FOREIGN KEY (descendant_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    INDEX idx_closure_descendant (descendant_id),
    INDEX idx_closure_distance (distance)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS group_members (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    group_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    role ENUM('admin', 'member') NOT NULL DEFAULT 'member',
    status ENUM('invited', 'pending', 'active', 'left', 'removed', 'banned') NOT NULL DEFAULT 'active',
    added_by BIGINT UNSIGNED NULL,
    approved_by BIGINT UNSIGNED NULL,
    joined_at TIMESTAMP NULL,
    left_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_group_user (group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_gm_user (user_id),
    INDEX idx_gm_status (group_id, status),
    INDEX idx_gm_role (group_id, role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS invite_links (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    group_id BIGINT UNSIGNED NOT NULL,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    created_by BIGINT UNSIGNED NOT NULL,
    expires_at TIMESTAMP NULL,
    max_uses INT UNSIGNED NULL,
    use_count INT UNSIGNED NOT NULL DEFAULT 0,
    revoked_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id),
    INDEX idx_invite_group (group_id),
    INDEX idx_invite_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS join_requests (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    group_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    status ENUM('pending', 'approved', 'declined') NOT NULL DEFAULT 'pending',
    decided_by BIGINT UNSIGNED NULL,
    message VARCHAR(500) NOT NULL DEFAULT '',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_join_req (group_id, user_id, status),
    FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_jr_status (group_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
