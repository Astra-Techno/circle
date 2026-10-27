CREATE TABLE moderation_targets (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    group_id BIGINT UNSIGNED NOT NULL,
    kind ENUM('memory','comment','member') NOT NULL,
    target_id BIGINT UNSIGNED NOT NULL,
    version INT UNSIGNED NOT NULL DEFAULT 1,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY moderation_target (group_id,kind,target_id),
    FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE reports (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    target_id BIGINT UNSIGNED NOT NULL,
    reporter_id BIGINT UNSIGNED NOT NULL,
    reason VARCHAR(30) NOT NULL,
    note VARCHAR(2000) NULL,
    dismissed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY report_once (target_id,reporter_id),
    FOREIGN KEY (target_id) REFERENCES moderation_targets(id) ON DELETE CASCADE,
    FOREIGN KEY (reporter_id) REFERENCES users(id),
    INDEX report_queue (target_id,dismissed),
    INDEX report_rate (reporter_id,created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE moderation_audit (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    group_id BIGINT UNSIGNED NOT NULL,
    target_id BIGINT UNSIGNED NOT NULL,
    actor_id BIGINT UNSIGNED NOT NULL,
    action ENUM('hide','unhide','dismiss','restore') NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    FOREIGN KEY (target_id) REFERENCES moderation_targets(id) ON DELETE CASCADE,
    FOREIGN KEY (actor_id) REFERENCES users(id),
    INDEX audit_group (group_id,id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE notification_outbox
    MODIFY COLUMN kind ENUM('memory.created','comment.created','comment.reply','group.invitation','group.report') NOT NULL,
    ADD COLUMN moderation_target_id BIGINT UNSIGNED NULL,
    ADD CONSTRAINT outbox_moderation_fk FOREIGN KEY (moderation_target_id) REFERENCES moderation_targets(id) ON DELETE CASCADE;
