USE harvesthub;

-- Run once after confirming there is no more than one admin and no user_uid
-- is attached to multiple farmer profiles.
ALTER TABLE farmers
  ADD COLUMN address VARCHAR(500) NULL,
  DROP INDEX idx_farmers_user_uid,
  ADD UNIQUE KEY uq_farmers_user_uid (user_uid);

ALTER TABLE users
  ADD COLUMN admin_slot TINYINT
    GENERATED ALWAYS AS (CASE WHEN role = 'admin' THEN 1 ELSE NULL END) STORED,
  ADD UNIQUE KEY uq_users_single_admin (admin_slot);
