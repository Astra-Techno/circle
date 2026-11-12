-- General Circle links keep NULL; selected-contact links are single-use and
-- bound to a keyed digest of the canonical account number (never raw contacts).
ALTER TABLE invite_links ADD COLUMN recipient_mobile_hash CHAR(64) NULL DEFAULT NULL;
