-- New rows default on. Preserve every existing global/category opt-out.
-- The controller always initializes the full effective category map explicitly.
ALTER TABLE notification_preferences ALTER COLUMN enabled SET DEFAULT TRUE;
