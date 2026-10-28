ALTER TABLE events ADD COLUMN reminder_scanned_at DATETIME(6) NULL,
 ADD INDEX event_reminder_scan(status,start_at,reminder_scanned_at);
