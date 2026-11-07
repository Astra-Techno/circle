-- Stable publication identity makes existing standalone polls visible in the
-- same cursor-paginated Memories stream, without duplicate retry publications.
ALTER TABLE memories ADD COLUMN source_poll_id BIGINT UNSIGNED NULL,
    ADD UNIQUE KEY uq_memory_source_poll (source_poll_id);

INSERT INTO memories (group_id, author_id, body, created_at, updated_at, source_poll_id)
SELECT p.group_id, p.created_by, p.question, p.created_at, p.created_at, p.id
FROM polls p WHERE p.memory_id IS NULL
AND NOT EXISTS (SELECT 1 FROM memories m WHERE m.source_poll_id = p.id);

UPDATE polls p JOIN memories m ON m.source_poll_id = p.id AND m.group_id = p.group_id
SET p.memory_id = m.id WHERE p.memory_id IS NULL;
