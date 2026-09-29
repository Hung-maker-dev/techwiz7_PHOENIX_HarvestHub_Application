USE harvesthub;

CREATE TABLE IF NOT EXISTS password_reset_otps (
  email_hash CHAR(64) NOT NULL PRIMARY KEY,
  user_uid VARCHAR(50) NULL,
  code_hash VARCHAR(255) NULL,
  code_expires_at DATETIME NULL,
  attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  reset_token_hash CHAR(64) NULL,
  reset_token_expires_at DATETIME NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_password_reset_expiry (code_expires_at, reset_token_expires_at),
  CONSTRAINT fk_password_reset_user
    FOREIGN KEY (user_uid) REFERENCES users (uid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS password_reset_rate_limits (
  bucket_hash CHAR(64) NOT NULL PRIMARY KEY,
  window_started_at DATETIME NOT NULL,
  request_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  last_requested_at DATETIME NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
