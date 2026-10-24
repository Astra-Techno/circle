-- 006: private media (milestone M4, ADR 0007). Additive; 001-005 stay unchanged.
--
-- The old `memory_media` table from 003 (raw storage_path, never used by any
-- endpoint) is superseded by `media_assets` + `memory_media_assets` and is left
-- in place untouched; it can be dropped in a later migration.

-- One row per uploaded photo. `id` is the public media id (UUID v4).
-- `storage_key` is a separate random prefix (media/{group_id}/{uuid}) that never
-- leaves the server. Only re-encoded variants are stored, never the original.
CREATE TABLE IF NOT EXISTS media_assets (
    id CHAR(36) NOT NULL PRIMARY KEY,
    group_id BIGINT UNSIGNED NOT NULL,
    uploader_id BIGINT UNSIGNED NOT NULL,
    client_upload_id CHAR(36) NOT NULL,
    kind ENUM('image') NOT NULL DEFAULT 'image',
    status ENUM('pending', 'ready', 'failed', 'deleted') NOT NULL DEFAULT 'pending',
    declared_mime VARCHAR(50) NOT NULL,
    declared_size INT UNSIGNED NOT NULL,
    declared_sha256 CHAR(64) NOT NULL,
    mime_type VARCHAR(50) NULL COMMENT 'Stored (re-encoded) type, set when ready',
    byte_size INT UNSIGNED NULL COMMENT 'Bytes of the stored full variant',
    width INT UNSIGNED NULL,
    height INT UNSIGNED NULL,
    storage_key VARCHAR(255) NULL,
    variants TEXT NULL COMMENT 'JSON: size => {width, height, bytes, ext}',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ticket_expires_at TIMESTAMP NULL DEFAULT NULL,
    ready_at TIMESTAMP NULL DEFAULT NULL,
    attached_at TIMESTAMP NULL DEFAULT NULL,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    purged_at TIMESTAMP NULL DEFAULT NULL COMMENT 'Files removed from storage',
    hidden_at TIMESTAMP NULL DEFAULT NULL COMMENT 'Moderation hook: hidden media is never served',
    UNIQUE KEY uq_media_client_upload (uploader_id, client_upload_id),
    FOREIGN KEY (group_id) REFERENCES `groups`(id),
    FOREIGN KEY (uploader_id) REFERENCES users(id),
    INDEX idx_media_group (group_id),
    INDEX idx_media_uploader_status (uploader_id, status, attached_at),
    INDEX idx_media_cleanup (status, attached_at, created_at),
    INDEX idx_media_purge (status, purged_at, deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Photos of a Memory, in order. UNIQUE(media_id): an asset is attached at most once.
CREATE TABLE IF NOT EXISTS memory_media_assets (
    memory_id BIGINT UNSIGNED NOT NULL,
    media_id CHAR(36) NOT NULL,
    sort_order TINYINT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (memory_id, media_id),
    UNIQUE KEY uq_mma_media (media_id),
    FOREIGN KEY (memory_id) REFERENCES memories(id) ON DELETE CASCADE,
    FOREIGN KEY (media_id) REFERENCES media_assets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
