USE harvesthub;

CREATE TABLE IF NOT EXISTS customer_cart_items (
  customer_id VARCHAR(50) NOT NULL,
  product_id VARCHAR(50) NOT NULL,
  quantity INT NOT NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (customer_id, product_id),
  CONSTRAINT fk_customer_cart_user
    FOREIGN KEY (customer_id) REFERENCES users (uid) ON DELETE CASCADE,
  CONSTRAINT fk_customer_cart_product
    FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS customer_order_details (
  order_id VARCHAR(64) NOT NULL PRIMARY KEY,
  recipient_name VARCHAR(150) NOT NULL,
  phone VARCHAR(30) NOT NULL,
  address VARCHAR(500) NOT NULL,
  note VARCHAR(1000) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS customer_order_requests (
  customer_id VARCHAR(50) NOT NULL,
  client_order_id VARCHAR(100) NOT NULL,
  farmer_id VARCHAR(50) NOT NULL,
  order_id VARCHAR(64) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (customer_id, client_order_id, farmer_id),
  UNIQUE KEY uq_customer_order_request_order (order_id),
  CONSTRAINT fk_customer_order_request_user
    FOREIGN KEY (customer_id) REFERENCES users (uid) ON DELETE CASCADE,
  CONSTRAINT fk_customer_order_request_farmer
    FOREIGN KEY (farmer_id) REFERENCES farmers (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
