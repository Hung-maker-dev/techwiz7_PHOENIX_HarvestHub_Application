CREATE TABLE products (
  id TEXT PRIMARY KEY,
  farmer_id TEXT NOT NULL,
  farmer_name TEXT,
  name TEXT NOT NULL,
  description TEXT,
  price REAL NOT NULL,
  unit TEXT NOT NULL,
  stock INTEGER NOT NULL,
  min_stock INTEGER NOT NULL DEFAULT 0,
  category_id TEXT NOT NULL,
  category_name TEXT,
  market_id TEXT,
  market_name TEXT,
  image_url TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  sold_count INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX idx_local_products_category ON products(category_id);
CREATE INDEX idx_local_products_farmer ON products(farmer_id);
CREATE TABLE cached_categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  name_en TEXT,
  display_order INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE cached_markets (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  name_en TEXT,
  address TEXT,
  latitude REAL,
  longitude REAL
);
CREATE TABLE cart_items (
  user_uid TEXT NOT NULL,
  product_id TEXT NOT NULL,
  name TEXT NOT NULL,
  price REAL NOT NULL,
  unit TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK(quantity > 0),
  stock INTEGER NOT NULL,
  farmer_id TEXT NOT NULL,
  farmer_name TEXT,
  image_url TEXT,
  updated_at TEXT NOT NULL,
  is_dirty INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY(user_uid, product_id)
);
CREATE TABLE outbox (
  id TEXT PRIMARY KEY,
  user_uid TEXT NOT NULL,
  action_type TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  retry_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT
);
CREATE INDEX idx_local_outbox_user_status
  ON outbox(user_uid, status, created_at);
CREATE TABLE sync_meta (
  table_name TEXT PRIMARY KEY,
  last_synced_at TEXT NOT NULL
);
CREATE TABLE cached_pickup_slots (
  id TEXT PRIMARY KEY,
  farmer_id TEXT NOT NULL,
  farmer_name TEXT,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  capacity INTEGER NOT NULL,
  booked_count INTEGER NOT NULL,
  is_open INTEGER NOT NULL
);
CREATE INDEX idx_cached_pickup_farmer_time
  ON cached_pickup_slots(farmer_id, start_time);
