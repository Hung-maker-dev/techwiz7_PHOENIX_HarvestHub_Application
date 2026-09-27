USE harvesthub;

CREATE TABLE IF NOT EXISTS farmer_followers (
  farmer_id VARCHAR(50) NOT NULL,
  user_id VARCHAR(50) NOT NULL,
  followed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (farmer_id, user_id),
  INDEX idx_farmer_followers_user_followed (user_id, followed_at),
  CONSTRAINT fk_farmer_followers_farmer
    FOREIGN KEY (farmer_id) REFERENCES farmers (id) ON DELETE CASCADE,
  CONSTRAINT fk_farmer_followers_user
    FOREIGN KEY (user_id) REFERENCES users (uid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

UPDATE farmers f
SET follower_count = (
  SELECT COUNT(*)
  FROM farmer_followers ff
  WHERE ff.farmer_id = f.id
);

CREATE TABLE IF NOT EXISTS user_fcm_tokens (
  token_hash CHAR(64) NOT NULL,
  user_id VARCHAR(50) NOT NULL,
  token TEXT NOT NULL,
  platform VARCHAR(20) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (token_hash),
  INDEX idx_user_fcm_tokens_user (user_id),
  CONSTRAINT fk_user_fcm_tokens_user
    FOREIGN KEY (user_id) REFERENCES users (uid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
