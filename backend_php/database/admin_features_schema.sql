USE harvesthub;

ALTER TABLE users
  ADD COLUMN is_locked TINYINT(1) NOT NULL DEFAULT 0;

ALTER TABLE farmers
  ADD COLUMN user_uid VARCHAR(50) NULL,
  ADD COLUMN is_locked TINYINT(1) NOT NULL DEFAULT 0,
  ADD INDEX idx_farmers_user_uid (user_uid);

ALTER TABLE products
  ADD COLUMN is_hidden TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN hide_reason VARCHAR(500) NULL;

ALTER TABLE farmers_market
  ADD COLUMN name_en VARCHAR(200) NULL;

CREATE TABLE IF NOT EXISTS audit_logs (
  id VARCHAR(80) NOT NULL PRIMARY KEY,
  actor_id VARCHAR(50) NULL,
  action VARCHAR(100) NOT NULL,
  detail TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_logs_actor_created (actor_id, created_at),
  INDEX idx_audit_logs_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
