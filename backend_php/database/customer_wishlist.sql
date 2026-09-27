USE harvesthub;

CREATE TABLE IF NOT EXISTS customer_wishlist (
  user_id VARCHAR(50) NOT NULL,
  product_id VARCHAR(50) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, product_id),
  INDEX idx_customer_wishlist_product (product_id),
  CONSTRAINT fk_customer_wishlist_user
    FOREIGN KEY (user_id) REFERENCES users (uid) ON DELETE CASCADE,
  CONSTRAINT fk_customer_wishlist_product
    FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @reviews_unique_index_sql = IF(
  (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'reviews'
      AND index_name = 'uq_reviews_order_product_user'
  ) = 0,
  'ALTER TABLE reviews ADD UNIQUE KEY uq_reviews_order_product_user (order_id, product_id, user_id)',
  'SELECT 1'
);
PREPARE reviews_unique_index_statement FROM @reviews_unique_index_sql;
EXECUTE reviews_unique_index_statement;
DEALLOCATE PREPARE reviews_unique_index_statement;
