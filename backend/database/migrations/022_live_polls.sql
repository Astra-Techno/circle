ALTER TABLE polls
 ADD client_id VARCHAR(100) NULL,
 ADD request_hash CHAR(64) NULL,
 ADD close_notified_at TIMESTAMP NULL,
 ADD UNIQUE KEY polls_client(created_by,client_id),
 ADD INDEX polls_due(closed_at,closes_at,close_notified_at);
ALTER TABLE notification_outbox
 MODIFY kind ENUM('memory.created','comment.created','comment.reply','group.invitation','group.report','chat.message','event.created','event.updated','event.cancelled','event.rsvp','event.reminder','poll.created','poll.closed') NOT NULL,
 ADD poll_id BIGINT UNSIGNED NULL,
 ADD INDEX notifications_poll(poll_id);
