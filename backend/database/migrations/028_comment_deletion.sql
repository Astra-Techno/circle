-- Allow comment authors and group admins to delete (soft-hide) comments.
-- The status column already exists with 'active'/'hidden'; no schema change
-- needed. This migration is a no-op placeholder for the migration sequence.
-- The controller logic handles the DELETE /memories/{id}/comments/{commentId} route.
SELECT 1;
