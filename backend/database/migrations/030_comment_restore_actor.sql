-- Undo is restricted to the actor who removed the comment. Existing moderated
-- comments have no actor here and cannot be restored through the Undo endpoint.
ALTER TABLE comments ADD COLUMN hidden_by BIGINT UNSIGNED NULL DEFAULT NULL;
