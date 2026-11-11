-- Activity inbox: persistent read-model of notifications delivered to a user.
-- Complements the transient push outbox with a paginated activity stream.
CREATE TABLE activity_items (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    kind ENUM('memory.created','comment.created','comment.reply','reaction','group.invitation','group.join','event.created','event.updated','event.cancelled','event.rsvp','poll.created','poll.closed','role.changed','capsule.unlocked') NOT NULL,
    group_id BIGINT UNSIGNED NULL,
    actor_id BIGINT UNSIGNED NULL,
    memory_id BIGINT UNSIGNED NULL,
    comment_id BIGINT UNSIGNED NULL,
    event_id BIGINT UNSIGNED NULL,
    poll_id BIGINT UNSIGNED NULL,
    capsule_id BIGINT UNSIGNED NULL,
    invitation_id BIGINT UNSIGNED NULL,
    summary VARCHAR(500) NOT NULL DEFAULT '',
    is_read TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX activity_user(user_id, created_at DESC),
    INDEX activity_user_unread(user_id, is_read, created_at DESC),
    CONSTRAINT activity_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
