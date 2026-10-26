-- Old unscoped registrations must opt in again from an authenticated session.
ALTER TABLE device_tokens
    MODIFY fcm_token VARCHAR(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
    ADD COLUMN session_id CHAR(36) NULL,
    ADD INDEX idx_device_tokens_session (user_id, session_id);

CREATE TABLE notification_preferences (
    user_id BIGINT UNSIGNED PRIMARY KEY,
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    categories JSON NOT NULL,
    quiet_hours BOOLEAN NOT NULL DEFAULT TRUE,
    quiet_start SMALLINT UNSIGNED NOT NULL DEFAULT 1320,
    quiet_end SMALLINT UNSIGNED NOT NULL DEFAULT 420,
    timezone VARCHAR(64) NOT NULL DEFAULT 'UTC',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
