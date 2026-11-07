-- Event publications share existing Memory pagination, author filters and saves.
-- Deleting a publication does not delete the event or its attendance history.
ALTER TABLE memories ADD COLUMN source_event_id BIGINT UNSIGNED NULL,
    ADD UNIQUE KEY uq_memory_source_event (source_event_id),
    ADD CONSTRAINT memory_source_event_fk FOREIGN KEY (source_event_id) REFERENCES events(id) ON DELETE CASCADE;

INSERT INTO memories (group_id, author_id, body, created_at, updated_at, source_event_id)
SELECT e.group_id, e.created_by, e.title, e.created_at, e.created_at, e.id
FROM events e WHERE NOT EXISTS (SELECT 1 FROM memories m WHERE m.source_event_id = e.id);
