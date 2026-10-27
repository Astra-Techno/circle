ALTER TABLE notification_outbox
    MODIFY COLUMN kind ENUM('memory.created', 'comment.created', 'comment.reply', 'group.invitation') NOT NULL,
    MODIFY COLUMN memory_id BIGINT UNSIGNED NULL,
    ADD COLUMN invitation_id BIGINT UNSIGNED NULL AFTER comment_id,
    ADD CONSTRAINT notification_invitation_fk FOREIGN KEY (invitation_id) REFERENCES group_invitations(id) ON DELETE CASCADE;
