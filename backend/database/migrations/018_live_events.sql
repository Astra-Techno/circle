ALTER TABLE events ADD COLUMN client_id VARCHAR(100) CHARACTER SET ascii COLLATE ascii_bin NULL,
 ADD COLUMN version INT UNSIGNED NOT NULL DEFAULT 1,
 ADD UNIQUE KEY event_retry(created_by,client_id);
ALTER TABLE notification_outbox
 MODIFY COLUMN kind ENUM('memory.created','comment.created','comment.reply','group.invitation','group.report','chat.message','event.created','event.updated','event.cancelled','event.rsvp','event.reminder') NOT NULL,
 ADD COLUMN event_id BIGINT UNSIGNED NULL,
 ADD COLUMN event_version INT UNSIGNED NULL,
 ADD CONSTRAINT event_outbox_fk FOREIGN KEY(event_id) REFERENCES events(id) ON DELETE CASCADE;
