CREATE TABLE IF NOT EXISTS events (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    group_id BIGINT UNSIGNED NOT NULL,
    created_by BIGINT UNSIGNED NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NULL,
    event_type ENUM('function', 'wedding', 'reunion', 'meetup', 'birthday', 'trip', 'online', 'other') NOT NULL DEFAULT 'other',
    cover_path VARCHAR(500) NULL,
    start_at TIMESTAMP NOT NULL,
    end_at TIMESTAMP NULL,
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
    venue VARCHAR(500) NULL,
    venue_url VARCHAR(1000) NULL,
    online_link VARCHAR(1000) NULL,
    rsvp_deadline TIMESTAMP NULL,
    max_capacity INT UNSIGNED NULL,
    status ENUM('active', 'cancelled', 'past') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id),
    INDEX idx_events_group_start (group_id, start_at),
    INDEX idx_events_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS event_rsvps (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    status ENUM('going', 'maybe', 'not_going') NOT NULL,
    guest_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
    note VARCHAR(500) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_rsvp (event_id, user_id),
    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_rsvp_event (event_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS polls (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    group_id BIGINT UNSIGNED NOT NULL,
    memory_id BIGINT UNSIGNED NULL,
    event_id BIGINT UNSIGNED NULL,
    created_by BIGINT UNSIGNED NOT NULL,
    question VARCHAR(500) NOT NULL,
    poll_type ENUM('single', 'multiple') NOT NULL DEFAULT 'single',
    anonymous TINYINT(1) NOT NULL DEFAULT 0,
    allow_add_options TINYINT(1) NOT NULL DEFAULT 0,
    results_visibility ENUM('always', 'after_voting', 'after_closing') NOT NULL DEFAULT 'always',
    allow_change_vote TINYINT(1) NOT NULL DEFAULT 1,
    closes_at TIMESTAMP NULL,
    closed_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    FOREIGN KEY (memory_id) REFERENCES memories(id) ON DELETE SET NULL,
    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE SET NULL,
    FOREIGN KEY (created_by) REFERENCES users(id),
    INDEX idx_polls_group (group_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS poll_options (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    poll_id BIGINT UNSIGNED NOT NULL,
    label VARCHAR(200) NOT NULL,
    sort_order TINYINT UNSIGNED NOT NULL DEFAULT 0,
    added_by BIGINT UNSIGNED NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (poll_id) REFERENCES polls(id) ON DELETE CASCADE,
    FOREIGN KEY (added_by) REFERENCES users(id),
    INDEX idx_po_poll (poll_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS poll_votes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    poll_id BIGINT UNSIGNED NOT NULL,
    option_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_vote_single (poll_id, option_id, user_id),
    FOREIGN KEY (poll_id) REFERENCES polls(id) ON DELETE CASCADE,
    FOREIGN KEY (option_id) REFERENCES poll_options(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_pv_poll (poll_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
