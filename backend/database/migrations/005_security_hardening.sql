-- 005: security hardening (additive; 001-004 stay unchanged).

-- Sessions: every refresh token belongs to a session. Access tokens carry the
-- session id, so logout revokes the session and its access tokens at once.
ALTER TABLE refresh_tokens
    ADD COLUMN session_id CHAR(32) NOT NULL DEFAULT '' AFTER user_id,
    ADD INDEX idx_refresh_tokens_session (user_id, session_id);

-- Join requests: allow many historical requests per user and group, but at
-- most one *pending* request (pending_key is NULL for every other status, and
-- NULLs never collide in a UNIQUE index).
ALTER TABLE join_requests
    MODIFY status ENUM('pending', 'approved', 'declined', 'cancelled') NOT NULL DEFAULT 'pending',
    ADD COLUMN pending_key TINYINT AS (IF(status = 'pending', 1, NULL)) STORED,
    ADD UNIQUE KEY uq_join_req_pending (group_id, user_id, pending_key);

ALTER TABLE join_requests
    DROP INDEX uq_join_req;

-- Removed/banned members may only come back through an invite link created
-- after their removal: links with id <= rejoin_after_link_id are refused.
ALTER TABLE group_members
    ADD COLUMN rejoin_after_link_id BIGINT UNSIGNED NULL AFTER left_at;

-- Invite links: who revoked a link (audit).
ALTER TABLE invite_links
    ADD COLUMN revoked_by BIGINT UNSIGNED NULL AFTER revoked_at;

-- Rate-limit lookups filter by bucket as well as key.
ALTER TABLE rate_limits
    ADD INDEX idx_rate_limits_key_bucket_time (ip, endpoint, created_at);

-- Memories: stable keyset pagination on (created_at, id).
ALTER TABLE memories
    ADD INDEX idx_memories_group_time_id (group_id, created_at, id);
