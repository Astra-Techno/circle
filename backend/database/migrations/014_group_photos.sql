CREATE TABLE group_photos (
    group_id BIGINT UNSIGNED NOT NULL,
    kind ENUM('avatar', 'cover') NOT NULL,
    version CHAR(36) NOT NULL,
    storage_prefix VARCHAR(255) NOT NULL,
    mime_type VARCHAR(30) NOT NULL,
    extension VARCHAR(5) NOT NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (group_id, kind),
    FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
