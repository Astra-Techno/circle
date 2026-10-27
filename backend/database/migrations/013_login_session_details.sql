CREATE TABLE login_sessions (
    public_id CHAR(32) PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    session_id CHAR(32) NOT NULL,
    device_label VARCHAR(120) NOT NULL DEFAULT 'Unknown device',
    os_version VARCHAR(80) NOT NULL DEFAULT '',
    app_version VARCHAR(40) NOT NULL DEFAULT '',
    last_ip VARCHAR(45) NOT NULL DEFAULT '',
    location_label VARCHAR(160) NULL,
    location_updated_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY login_session_identity (user_id, session_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Metadata only; existing credentials and expiry are unchanged. Public handles
-- are separate from JWT session identifiers and never confer authorization.
INSERT INTO login_sessions (public_id, user_id, session_id, created_at, last_seen_at)
SELECT LOWER(REPLACE(UUID(), '-', '')), user_id, session_id, MIN(created_at), MAX(created_at)
FROM refresh_tokens WHERE revoked_at IS NULL AND expires_at > NOW() AND session_id <> ''
GROUP BY user_id, session_id;
