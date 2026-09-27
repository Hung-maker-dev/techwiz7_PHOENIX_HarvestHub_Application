SET NAMES utf8mb4;
USE harvesthub;

INSERT INTO farmers_market
  (id, name, address, latitude, longitude, open_hours, is_active)
VALUES
  ('m_cantho_cho_anhoa', 'Chợ An Hòa', 'Cần Thơ', 10.0495793, 105.7727998, '05:00 - 12:00', 1),
  ('m_cantho_cho_cairang', 'Chợ nổi Cái Răng', 'Cái Răng, Cần Thơ', 10.0024853, 105.7451729, '05:00 - 09:00', 1),
  ('m_cantho_chobabo', 'Chợ Bà Bộ', 'Cần Thơ', 10.0367957, 105.7448494, '05:00 - 12:00', 1),
  ('m_cantho_choankhanh', 'Chợ An Khánh', 'Cần Thơ', 10.0389585, 105.7544153, '05:00 - 12:00', 1)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  address = VALUES(address),
  latitude = VALUES(latitude),
  longitude = VALUES(longitude),
  open_hours = VALUES(open_hours),
  is_active = VALUES(is_active);