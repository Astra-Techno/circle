-- Private chat photos and event covers; original files are never retained.
CREATE TABLE feature_media (
 id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
 scope_kind ENUM('chat','event') NOT NULL,
 scope_id BIGINT UNSIGNED NOT NULL,
 uploader_id BIGINT UNSIGNED NOT NULL,
 request_sha CHAR(64) NOT NULL,
 storage_prefix VARCHAR(255) NOT NULL,
 mime_type VARCHAR(64) NOT NULL,
 extension VARCHAR(8) NOT NULL,
 message_id BIGINT UNSIGNED NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX feature_media_message(message_id),
 INDEX feature_media_orphan(created_at),
 FOREIGN KEY(uploader_id) REFERENCES users(id) ON DELETE CASCADE,
 FOREIGN KEY(message_id) REFERENCES chat_messages(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
ALTER TABLE events ADD cover_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL;
