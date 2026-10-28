CREATE TABLE conversations (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 kind ENUM('group','direct') NOT NULL,
 group_id BIGINT UNSIGNED NULL,
 pair_low BIGINT UNSIGNED NULL,
 pair_high BIGINT UNSIGNED NULL,
 requested_by BIGINT UNSIGNED NULL,
 request_state ENUM('pending','accepted','declined') NOT NULL DEFAULT 'accepted',
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 UNIQUE KEY group_conversation(group_id),
 UNIQUE KEY direct_pair(pair_low,pair_high),
 FOREIGN KEY(group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
 FOREIGN KEY(pair_low) REFERENCES users(id),
 FOREIGN KEY(pair_high) REFERENCES users(id)
) ENGINE=InnoDB;
INSERT INTO conversations(kind,group_id) SELECT 'group',id FROM `groups`;
CREATE TABLE chat_messages (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 conversation_id BIGINT UNSIGNED NOT NULL,
 author_id BIGINT UNSIGNED NOT NULL,
 client_id VARCHAR(100) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 request_hash CHAR(64) NOT NULL,
 reply_to_id BIGINT UNSIGNED NULL,
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 UNIQUE KEY message_retry(author_id,client_id),
 INDEX chat_history(conversation_id,id),
 INDEX chat_rate(author_id,created_at),
 FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
 FOREIGN KEY(author_id) REFERENCES users(id)
) ENGINE=InnoDB;
CREATE TABLE chat_versions (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 message_id BIGINT UNSIGNED NOT NULL,
 body TEXT NOT NULL,
 removed TINYINT(1) NOT NULL DEFAULT 0,
 edited TINYINT(1) NOT NULL DEFAULT 0,
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 INDEX message_version(message_id,id),
 FOREIGN KEY(message_id) REFERENCES chat_messages(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE chat_states (
 user_id BIGINT UNSIGNED NOT NULL,
 conversation_id BIGINT UNSIGNED NOT NULL,
 read_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
 muted TINYINT(1) NOT NULL DEFAULT 0,
 pinned TINYINT(1) NOT NULL DEFAULT 0,
 archived TINYINT(1) NOT NULL DEFAULT 0,
 PRIMARY KEY(user_id,conversation_id),
 FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
 FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE chat_reactions (
 message_id BIGINT UNSIGNED NOT NULL,
 user_id BIGINT UNSIGNED NOT NULL,
 emoji VARCHAR(16) NOT NULL,
 PRIMARY KEY(message_id,user_id),
 FOREIGN KEY(message_id) REFERENCES chat_messages(id) ON DELETE CASCADE,
 FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE chat_privacy (
 user_id BIGINT UNSIGNED PRIMARY KEY,
 who_can_message ENUM('all','existing','none') NOT NULL DEFAULT 'all',
 FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
ALTER TABLE group_members ADD COLUMN chat_frozen_id BIGINT UNSIGNED NULL;
UPDATE group_members SET chat_frozen_id=0 WHERE status<>'active';
ALTER TABLE notification_outbox
 MODIFY COLUMN kind ENUM('memory.created','comment.created','comment.reply','group.invitation','group.report','chat.message') NOT NULL,
 ADD COLUMN chat_message_id BIGINT UNSIGNED NULL,
 ADD CONSTRAINT chat_outbox_fk FOREIGN KEY(chat_message_id) REFERENCES chat_messages(id) ON DELETE CASCADE;
