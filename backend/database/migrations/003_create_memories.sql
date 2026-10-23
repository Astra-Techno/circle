CREATE TABLE IF NOT EXISTS memories (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    group_id BIGINT UNSIGNED NOT NULL,
    author_id BIGINT UNSIGNED NOT NULL,
    body TEXT NOT NULL,
    memory_date DATE NULL COMMENT 'Optional: when the memory happened',
    place VARCHAR(255) NULL,
    status ENUM('active', 'hidden', 'removed') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES users(id),
    INDEX idx_memories_group_time (group_id, created_at DESC),
    INDEX idx_memories_author (author_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS memory_media (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    memory_id BIGINT UNSIGNED NOT NULL,
    media_type ENUM('image', 'video') NOT NULL DEFAULT 'image',
    storage_path VARCHAR(500) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    file_size INT UNSIGNED NOT NULL DEFAULT 0,
    width INT UNSIGNED NULL,
    height INT UNSIGNED NULL,
    sort_order TINYINT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (memory_id) REFERENCES memories(id) ON DELETE CASCADE,
    INDEX idx_mm_memory (memory_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS comments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    memory_id BIGINT UNSIGNED NOT NULL,
    parent_id BIGINT UNSIGNED NULL COMMENT 'For threaded replies',
    author_id BIGINT UNSIGNED NOT NULL,
    body VARCHAR(2000) NOT NULL,
    status ENUM('active', 'hidden', 'removed') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (memory_id) REFERENCES memories(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES comments(id) ON DELETE SET NULL,
    FOREIGN KEY (author_id) REFERENCES users(id),
    INDEX idx_comments_memory (memory_id, created_at),
    INDEX idx_comments_parent (parent_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS reactions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    memory_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    emoji VARCHAR(10) NOT NULL DEFAULT '❤️',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_reaction (memory_id, user_id),
    FOREIGN KEY (memory_id) REFERENCES memories(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_reactions_memory (memory_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS saves (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    memory_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_save (memory_id, user_id),
    FOREIGN KEY (memory_id) REFERENCES memories(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
