-- Memory Capsules: time-locked group content unlocked on a future date.
CREATE TABLE capsules (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    group_id BIGINT UNSIGNED NOT NULL,
    creator_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(60) NOT NULL,
    message VARCHAR(500) NOT NULL DEFAULT '',
    unlock_at TIMESTAMP NOT NULL,
    sealed_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT capsules_group_fk FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    CONSTRAINT capsules_creator_fk FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX capsules_group(group_id, created_at),
    INDEX capsules_unlock(unlock_at, sealed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE capsule_entries (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    capsule_id BIGINT UNSIGNED NOT NULL,
    author_id BIGINT UNSIGNED NOT NULL,
    body VARCHAR(500) NOT NULL DEFAULT '',
    added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT capsule_entries_capsule_fk FOREIGN KEY (capsule_id) REFERENCES capsules(id) ON DELETE CASCADE,
    CONSTRAINT capsule_entries_author_fk FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX capsule_entries_capsule(capsule_id, added_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
