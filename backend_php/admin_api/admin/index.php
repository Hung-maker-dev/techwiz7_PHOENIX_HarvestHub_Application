<?php
require_once __DIR__ . '/common.php';

$db = database();
$method = $_SERVER['REQUEST_METHOD'];
$path = admin_resolve_path();
$parts = $path;

try {
    if ($parts === ['users'] && $method === 'GET') {
        $rows = $db->query("SELECT uid AS id, full_name AS name, email, role FROM users ORDER BY full_name ASC")->fetchAll();
        admin_json($rows);
    }

    if ($parts === ['accounts'] && $method === 'GET') {
        $query = trim((string) ($_GET['q'] ?? ''));
        $type = (string) ($_GET['type'] ?? 'all');
        $status = (string) ($_GET['status'] ?? 'all');
        if (!in_array($type, ['all', 'customer', 'farmer'], true)) {
            admin_error('Unsupported account type.', 422);
        }
        if (!in_array($status, ['all', 'pending', 'approved', 'rejected', 'not_applicable'], true)) {
            admin_error('Unsupported application status.', 422);
        }

        $phone = admin_column_exists($db, 'users', 'phone') ? 'u.phone' : 'NULL';
        $locked = admin_column_exists($db, 'users', 'is_locked') ? 'u.is_locked' : '0';
        $farmOwner = admin_column_exists($db, 'farmers', 'user_uid') ? 'f.user_uid' : 'f.id';
        $hasFarmStatus = admin_column_exists($db, 'farmers', 'status');
        $hasFarmDetails = admin_column_exists($db, 'farmers', 'farm_name');
        $hasFarmMarket = admin_column_exists($db, 'farmers', 'market_id');
        $hasFarmAddress = admin_column_exists($db, 'farmers', 'address');
        $hasFarmLatitude = admin_column_exists($db, 'farmers', 'latitude');
        $hasFarmLongitude = admin_column_exists($db, 'farmers', 'longitude');
        $hasMarkets = admin_column_exists($db, 'farmers_market', 'id');
        $farmJoin = $hasFarmStatus
            ? " LEFT JOIN farmers f ON COALESCE(NULLIF({$farmOwner}, ''), f.id)=u.uid "
            : '';
        $farmName = $farmJoin && $hasFarmDetails ? 'f.farm_name' : 'NULL';
        $farmerId = $farmJoin ? 'f.id' : 'NULL';
        $farmStatus = $farmJoin && $hasFarmStatus ? 'f.status' : 'NULL';
        $farmMarketId = $farmJoin && $hasFarmMarket ? 'f.market_id' : 'NULL';
        $farmAddress = $farmJoin && $hasFarmAddress ? 'f.address' : 'NULL';
        $farmLatitude = $farmJoin && $hasFarmLatitude ? 'f.latitude' : 'NULL';
        $farmLongitude = $farmJoin && $hasFarmLongitude ? 'f.longitude' : 'NULL';
        $marketJoin = $farmJoin && $hasMarkets && $hasFarmMarket
            ? ' LEFT JOIN farmers_market m ON m.id=f.market_id '
            : '';
        $marketName = $marketJoin ? 'm.name' : 'NULL';
        $accountType = $farmJoin
            ? "CASE WHEN f.id IS NOT NULL OR u.role='farmer' THEN 'farmer' ELSE 'customer' END"
            : "CASE WHEN u.role='farmer' THEN 'farmer' ELSE 'customer' END";
        $applicationStatus = $farmJoin
            ? "CASE WHEN f.status IS NOT NULL THEN f.status WHEN u.role='farmer' THEN 'approved' ELSE 'not_applicable' END"
            : "CASE WHEN u.role='farmer' THEN 'approved' ELSE 'not_applicable' END";

        $sql = "SELECT u.uid AS id, u.full_name AS name, u.email, {$phone} AS phone,
                       u.role, {$locked} AS is_locked, u.created_at,
                       {$accountType} AS account_type, {$applicationStatus} AS application_status,
                       {$farmerId} AS farmer_id, {$farmName} AS farm_name, {$farmMarketId} AS market_id,
                       {$marketName} AS market_name, {$farmAddress} AS farm_address,
                       {$farmLatitude} AS latitude, {$farmLongitude} AS longitude
                FROM users u {$farmJoin} {$marketJoin}
                WHERE u.role IN ('customer', 'farmer')";
        $params = [];
        if ($type === 'farmer') {
            $sql .= $farmJoin
                ? " AND (f.id IS NOT NULL OR u.role='farmer')"
                : " AND u.role='farmer'";
        } elseif ($type === 'customer') {
            $sql .= $farmJoin
                ? " AND f.id IS NULL AND u.role='customer'"
                : " AND u.role='customer'";
        }
        if ($status === 'not_applicable') {
            $sql .= $farmJoin
                ? " AND f.status IS NULL AND u.role='customer'"
                : " AND u.role='customer'";
        } elseif ($status !== 'all') {
            $sql .= $farmJoin
                ? " AND f.status=:application_status"
                : " AND u.role=:role_status";
            if ($farmJoin) {
                $params['application_status'] = $status;
            } else {
                $params['role_status'] = $status === 'approved' ? 'farmer' : '';
            }
        }
        if ($query !== '') {
            $sql .= " AND (u.full_name LIKE :name_query OR u.email LIKE :email_query "
                . "OR {$phone} LIKE :phone_query OR {$farmName} LIKE :farm_query)";
            $params['name_query'] = '%' . $query . '%';
            $params['email_query'] = '%' . $query . '%';
            $params['phone_query'] = '%' . $query . '%';
            $params['farm_query'] = '%' . $query . '%';
        }
        $sql .= ' ORDER BY u.created_at DESC';
        $statement = $db->prepare($sql);
        $statement->execute($params);
        $rows = $statement->fetchAll();
        foreach ($rows as &$row) {
            $row['is_locked'] = (bool) (int) $row['is_locked'];
        }
        admin_json($rows);
    }

    if ($parts === ['customers'] && $method === 'GET') {
        $q = trim((string) ($_GET['q'] ?? ''));
        $lockExpr = admin_expr($db, 'users', 'is_locked', '0');
        $avatarExpr = admin_expr($db, 'users', 'avatar_url', 'NULL');
        $phoneExpr = admin_expr($db, 'users', 'phone', 'NULL');
        $providerExpr = admin_expr($db, 'users', 'auth_provider', "'password'");
        $langExpr = admin_expr($db, 'users', 'preferred_language', "'vi'");
        $sql = "SELECT uid AS id, full_name AS name, email, {$phoneExpr} AS phone, {$avatarExpr} AS avatar_url,
                       {$providerExpr} AS auth_provider, {$langExpr} AS preferred_language,
                   created_at, {$lockExpr} AS is_locked,
                   (SELECT COUNT(*) FROM orders o WHERE o.customer_id = users.uid) AS order_count,
                   (SELECT COALESCE(SUM(o.total), 0) FROM orders o WHERE o.customer_id = users.uid) AS total_spent
                FROM users WHERE role = 'customer'";
        $params = [];
        if ($q !== '') {
            $sql .= ' AND (full_name LIKE :name_query OR email LIKE :email_query)';
            $params['name_query'] = '%' . $q . '%';
            $params['email_query'] = '%' . $q . '%';
        }
        $sql .= ' ORDER BY created_at DESC';
        $stmt = $db->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();
        foreach ($rows as &$r) {
            $r['is_locked'] = (bool) (int) $r['is_locked'];
        }
        admin_json($rows);
    }

    if (count($parts) === 2 && $parts[0] === 'customers' && $method === 'GET') {
        $id = $parts[1];
        $lockExpr = admin_expr($db, 'users', 'is_locked', '0');
        $avatarExpr = admin_expr($db, 'users', 'avatar_url', 'NULL');
        $phoneExpr = admin_expr($db, 'users', 'phone', 'NULL');
        $providerExpr = admin_expr($db, 'users', 'auth_provider', "'password'");
        $langExpr = admin_expr($db, 'users', 'preferred_language', "'vi'");
        $stmt = $db->prepare("SELECT uid AS id, full_name AS name, email, {$phoneExpr} AS phone, {$avatarExpr} AS avatar_url,
                {$providerExpr} AS auth_provider, {$langExpr} AS preferred_language,
                created_at, {$lockExpr} AS is_locked
                FROM users WHERE uid = :id AND role = 'customer' LIMIT 1");
        $stmt->execute(['id' => $id]);
        $row = $stmt->fetch();
        if (!$row)
            admin_error('Customer not found.', 404);

        $row['is_locked'] = (bool) (int) $row['is_locked'];
        $row['order_count'] = 0;
        $row['total_spent'] = 0;
        if (admin_column_exists($db, 'orders', 'customer_id')) {
            $s = $db->prepare('SELECT COUNT(*) order_count, COALESCE(SUM(total),0) total_spent FROM orders WHERE customer_id=:id');
            $s->execute(['id' => $id]);
            $stats = $s->fetch() ?: [];
            $row['order_count'] = (int) ($stats['order_count'] ?? 0);
            $row['total_spent'] = (float) ($stats['total_spent'] ?? 0);
        }
        admin_json($row);
    }

    if ($parts === ['farmers'] && $method === 'GET') {
        $status = $_GET['status'] ?? null;
        $marketJoin = admin_column_exists($db, 'farmers_market', 'id') && admin_column_exists($db, 'farmers', 'market_id')
            ? ' LEFT JOIN farmers_market m ON m.id=f.market_id ' : '';
        $marketName = $marketJoin ? 'm.name' : 'NULL';
        $marketId = admin_expr($db, 'farmers', 'market_id', 'NULL');
        $locked = admin_expr($db, 'farmers', 'is_locked', '0');
        $rating = admin_expr($db, 'farmers', 'rating', '0');
        $ratingCount = admin_expr($db, 'farmers', 'rating_count', '0');
        $followers = admin_expr($db, 'farmers', 'follower_count', '0');
        $desc = admin_expr($db, 'farmers', 'description', 'NULL');
        $avatar = admin_expr($db, 'farmers', 'avatar_url', 'NULL');
        $address = admin_column_exists($db, 'farmers', 'address') ? 'f.address' : 'NULL';
        $latitude = admin_column_exists($db, 'farmers', 'latitude') ? 'f.latitude' : 'NULL';
        $longitude = admin_column_exists($db, 'farmers', 'longitude') ? 'f.longitude' : 'NULL';
        $ownerId = admin_column_exists($db, 'farmers', 'user_uid') ? 'f.user_uid' :
            (admin_column_exists($db, 'farmers', 'user_id') ? 'f.user_id' :
                (admin_column_exists($db, 'farmers', 'owner_id') ? 'f.owner_id' : 'NULL'));
        $ownerJoin = $ownerId !== 'NULL' ? ' LEFT JOIN users u ON u.uid=' . $ownerId . ' ' : '';
        $ownerName = $ownerJoin ? 'u.full_name' : 'NULL';
        $ownerEmail = $ownerJoin ? 'u.email' : 'NULL';
        $ownerPhone = $ownerJoin && admin_column_exists($db, 'users', 'phone')
            ? 'u.phone' : 'NULL';
        $sql = "SELECT f.id, f.farm_name, {$marketId} market_id, {$marketName} market_name,
                f.status, {$locked} is_locked, {$rating} rating, {$ratingCount} rating_count,
                {$followers} follower_count, {$desc} description, {$avatar} avatar_url,
                {$address} address, {$latitude} latitude, {$longitude} longitude,
                {$ownerName} owner_name, {$ownerEmail} owner_email, {$ownerPhone} owner_phone,
                f.created_at
                FROM farmers f {$marketJoin} {$ownerJoin}";
        $params = [];
        if ($status !== null && in_array($status, ['pending', 'approved', 'rejected'], true)) {
            $sql .= ' WHERE f.status=:status';
            $params['status'] = $status;
        }
        $sql .= ' ORDER BY f.created_at DESC';
        $stmt = $db->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();
        foreach ($rows as &$r) {
            $r['is_locked'] = (bool) (int) $r['is_locked'];
            $r['rating'] = (float) $r['rating'];
            $r['rating_count'] = (int) $r['rating_count'];
            $r['follower_count'] = (int) $r['follower_count'];
        }
        admin_json($rows);
    }

    if (count($parts) === 3 && $parts[0] === 'farmers' && $method === 'PATCH') {
        $id = $parts[1];
        $action = $parts[2];
        $emailNotificationSent = false;
        if (!in_array($action, ['approve', 'reject', 'lock'], true))
            admin_error('Unsupported farmer action.', 404);
        if ($action === 'lock') {
            $body = admin_body();
            $locked = !empty($body['locked']);
            if (!admin_column_exists($db, 'farmers', 'is_locked'))
                admin_error('Column farmers.is_locked is missing.', 409);
            $s = $db->prepare('UPDATE farmers SET is_locked=:locked WHERE id=:id');
            $s->execute(['locked' => $locked ? 1 : 0, 'id' => $id]);
            admin_audit($db, 'farmer_lock', 'farmer', $id, 'locked=' . ($locked ? '1' : '0'));
        } else {
            $new = $action === 'approve' ? 'approved' : 'rejected';
            $s = $db->prepare('UPDATE farmers SET status=:status WHERE id=:id');
            $s->execute(['status' => $new, 'id' => $id]);
            if (admin_column_exists($db, 'farmers', 'user_uid')) {
                $role = $action === 'approve' ? 'farmer' : 'customer';
                $roleUpdate = $db->prepare(
                    'UPDATE users SET role=:role WHERE uid = '
                    . '(SELECT COALESCE(NULLIF(user_uid, \'\'), id) FROM farmers WHERE id=:id) '
                    . 'AND role IN (:current_role, :pending_role)'
                );
                $roleUpdate->execute([
                    'role' => $role,
                    'id' => $id,
                    'current_role' => $action === 'approve' ? 'customer' : 'farmer',
                    'pending_role' => $action === 'approve' ? 'farmer' : 'customer',
                ]);
            }
            if ($action === 'approve') {
                try {
                    $emailNotificationSent = admin_send_farmer_approval_email($db, $id);
                } catch (Throwable $emailError) {
                    error_log('Farmer approval email failed: ' . $emailError->getMessage());
                }
            }
            admin_audit($db, 'farmer_' . $action, 'farmer', $id);
        }
        $response = [
            'id' => $id,
            'updated' => true,
        ];
        if ($action === 'approve') {
            $response['email_notification_sent'] = $emailNotificationSent;
        }
        admin_json($response);
    }

    if ($parts === ['products'] && $method === 'GET') {
        $farmer = $_GET['farmer'] ?? null;
        $category = $_GET['category'] ?? null;
        $status = $_GET['status'] ?? null;
        $catJoin = admin_column_exists($db, 'categories', 'id') ? ' LEFT JOIN categories c ON c.id=p.category_id ' : '';
        $marketJoin = admin_column_exists($db, 'farmers_market', 'id') && admin_column_exists($db, 'products', 'market_id') ? ' LEFT JOIN farmers_market m ON m.id=p.market_id ' : '';
        $farmerJoin = admin_column_exists($db, 'farmers', 'id') ? ' LEFT JOIN farmers f ON f.id=p.farmer_id ' : '';
        $catName = $catJoin ? 'c.name' : 'NULL';
        $marketName = $marketJoin ? 'm.name' : 'NULL';
        $farmerName = $farmerJoin ? 'f.farm_name' : 'NULL';
        $nameEn = admin_column_exists($db, 'products', 'name_en') ? 'p.name_en' : 'NULL';
        $image = admin_column_exists($db, 'products', 'image_url') ? 'p.image_url' : 'NULL';
        $marketId = admin_column_exists($db, 'products', 'market_id') ? 'p.market_id' : 'NULL';
        $active = admin_column_exists($db, 'products', 'is_active') ? 'p.is_active' : '1';
        $hidden = admin_column_exists($db, 'products', 'is_hidden') ? 'p.is_hidden' : '0';
        $reason = admin_column_exists($db, 'products', 'hide_reason') ? 'p.hide_reason' : 'NULL';
        $updated = admin_column_exists($db, 'products', 'updated_at') ? 'p.updated_at' : 'NOW()';
        $sql = "SELECT p.id,p.name,{$nameEn} name_en,p.category_id,{$catName} category_name,p.price,p.unit,p.stock,
              {$image} image_url,p.farmer_id,{$farmerName} farmer_name,{$marketId} market_id,{$marketName} market_name,
              {$active} is_active,{$hidden} is_hidden,{$reason} hide_reason,{$updated} updated_at
              FROM products p {$catJoin}{$marketJoin}{$farmerJoin}";
        $where = [];
        $params = [];
        if ($farmer) {
            $where[] = 'p.farmer_id=:farmer';
            $params['farmer'] = $farmer;
        }
        if ($category) {
            $where[] = 'p.category_id=:category';
            $params['category'] = $category;
        }
        if ($status === 'active') {
            $where[] = "{$active}=1";
        }
        if ($status === 'hidden') {
            $where[] = "{$hidden}=1";
        }
        if ($where)
            $sql .= ' WHERE ' . implode(' AND ', $where);
        $sql .= ' ORDER BY ' . ($updated !== 'NOW()' ? 'p.updated_at' : 'p.id') . ' DESC';
        $stmt = $db->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();
        foreach ($rows as &$r) {
            $r['price'] = (float) $r['price'];
            $r['stock'] = (int) $r['stock'];
            $r['is_active'] = (bool) (int) $r['is_active'];
            $r['is_hidden'] = (bool) (int) $r['is_hidden'];
        }
        admin_json($rows);
    }

    if (count($parts) === 3 && $parts[0] === 'products' && $parts[2] === 'hide' && $method === 'PATCH') {
        $id = $parts[1];
        $body = admin_body();
        $reason = trim((string) ($body['reason'] ?? ''));
        if ($reason === '')
            admin_error('Hide reason is required.');
        if (!admin_column_exists($db, 'products', 'is_hidden'))
            admin_error('Column products.is_hidden is missing.', 409);
        $sets = ['is_hidden=1'];
        $params = ['id' => $id, 'reason' => $reason];
        if (admin_column_exists($db, 'products', 'hide_reason'))
            $sets[] = 'hide_reason=:reason';
        if (admin_column_exists($db, 'products', 'updated_at'))
            $sets[] = 'updated_at=NOW()';
        $s = $db->prepare('UPDATE products SET ' . implode(',', $sets) . ' WHERE id=:id');
        $s->execute($params);
        admin_audit($db, 'product_hide', 'product', $id, $reason);
        admin_json(['id' => $id, 'hidden' => true]);
    }

    if ($parts === ['categories'] && $method === 'GET') {
        $s = $db->query('SELECT id,name,name_en,display_order,is_active FROM categories ORDER BY display_order ASC,id ASC');
        $rows = $s->fetchAll();
        foreach ($rows as &$r) {
            $r['display_order'] = (int) $r['display_order'];
            $r['is_active'] = (bool) (int) $r['is_active'];
        }
        admin_json($rows);
    }
    if ($parts === ['categories'] && $method === 'POST') {
        $b = admin_body();
        $name = trim((string) ($b['name'] ?? ''));
        if ($name === '')
            admin_error('Category name is required.');
        $id = admin_id('CAT');
        $nameEn = $b['nameEn'] ?? null;
        $order = (int) ($b['displayOrder'] ?? 0);
        $active = !isset($b['isActive']) || $b['isActive'];
        $s = $db->prepare('INSERT INTO categories (id,name,name_en,display_order,is_active) VALUES (:id,:name,:name_en,:display_order,:is_active)');
        $s->execute(['id' => $id, 'name' => $name, 'name_en' => $nameEn, 'display_order' => $order, 'is_active' => $active ? 1 : 0]);
        admin_audit($db, 'category_create', 'category', $id);
        $s = $db->prepare('SELECT id,name,name_en,display_order,is_active FROM categories WHERE id=:id');
        $s->execute(['id' => $id]);
        $r = $s->fetch();
        $r['display_order'] = (int) $r['display_order'];
        $r['is_active'] = (bool) (int) $r['is_active'];
        admin_json($r, 201);
    }
    if (count($parts) === 2 && $parts[0] === 'categories' && $method === 'PATCH') {
        $id = $parts[1];
        $b = admin_body();
        $sets = [];
        $params = ['id' => $id];
        foreach (['name' => 'name', 'nameEn' => 'name_en', 'displayOrder' => 'display_order', 'isActive' => 'is_active'] as $in => $col) {
            if (array_key_exists($in, $b)) {
                $sets[] = "$col=:$col";
                $params[$col] = $in === 'isActive' ? ($b[$in] ? 1 : 0) : $b[$in];
            }
        }
        if (!$sets)
            admin_error('Nothing to update.');
        $s = $db->prepare('UPDATE categories SET ' . implode(',', $sets) . ' WHERE id=:id');
        $s->execute($params);
        admin_audit($db, 'category_update', 'category', $id);
        admin_json(['id' => $id, 'updated' => true]);
    }
    if (count($parts) === 2 && $parts[0] === 'categories' && $method === 'DELETE') {
        $id = $parts[1];
        $s = $db->prepare('DELETE FROM categories WHERE id=:id');
        $s->execute(['id' => $id]);
        admin_audit($db, 'category_delete', 'category', $id);
        admin_json(['id' => $id, 'deleted' => true]);
    }
    if ($parts === ['categories', 'reorder'] && $method === 'PATCH') {
        $b = admin_body();
        $ids = $b['orderedIds'] ?? [];
        if (!is_array($ids))
            admin_error('orderedIds must be an array.');
        $db->beginTransaction();
        $s = $db->prepare('UPDATE categories SET display_order=:n WHERE id=:id');
        foreach (array_values($ids) as $i => $id)
            $s->execute(['n' => $i, 'id' => $id]);
        $db->commit();
        admin_audit($db, 'category_reorder', 'category', 'bulk');
        admin_json(['updated' => true]);
    }

    if ($parts === ['markets'] && $method === 'GET') {
        $farmerCount = admin_column_exists($db, 'farmers', 'market_id') ? '(SELECT COUNT(*) FROM farmers f WHERE f.market_id=m.id)' : '0';
        $s = $db->query("SELECT m.id,m.name,m.name_en,m.address,m.latitude,m.longitude,m.geohash,m.open_hours,m.is_active,
            {$farmerCount} farmer_count FROM farmers_market m ORDER BY m.name ASC");
        $rows = $s->fetchAll();
        foreach ($rows as &$r) {
            $r['is_active'] = (bool) (int) $r['is_active'];
            $r['farmer_count'] = (int) $r['farmer_count'];
        }
        admin_json($rows);
    }
    if ($parts === ['markets'] && $method === 'POST') {
        $b = admin_body();
        $name = trim((string) ($b['name'] ?? ''));
        if ($name === '')
            admin_error('Market name is required.');
        $id = admin_id('MKT');
        $s = $db->prepare('INSERT INTO farmers_market (id,name,name_en,address,latitude,longitude,geohash,open_hours,is_active) VALUES (:id,:name,:name_en,:address,:lat,:lng,:geohash,:hours,:active)');
        $s->execute(['id' => $id, 'name' => $name, 'name_en' => $b['nameEn'] ?? null, 'address' => $b['address'] ?? null, 'lat' => $b['latitude'] ?? null, 'lng' => $b['longitude'] ?? null, 'geohash' => $b['geohash'] ?? null, 'hours' => $b['openHours'] ?? null, 'active' => !isset($b['isActive']) || $b['isActive'] ? 1 : 0]);
        admin_audit($db, 'market_create', 'market', $id);
        $s = $db->prepare('SELECT id,name,name_en,address,latitude,longitude,geohash,open_hours,is_active FROM farmers_market WHERE id=:id');
        $s->execute(['id' => $id]);
        $r = $s->fetch();
        $r['is_active'] = (bool) (int) $r['is_active'];
        $r['farmer_count'] = 0;
        admin_json($r, 201);
    }
    if (count($parts) === 2 && $parts[0] === 'markets' && $method === 'PATCH') {
        $id = $parts[1];
        $b = admin_body();
        $map = ['name' => 'name', 'nameEn' => 'name_en', 'address' => 'address', 'latitude' => 'latitude', 'longitude' => 'longitude', 'geohash' => 'geohash', 'openHours' => 'open_hours', 'isActive' => 'is_active'];
        $sets = [];
        $params = ['id' => $id];
        foreach ($map as $in => $col)
            if (array_key_exists($in, $b)) {
                $sets[] = "$col=:$col";
                $params[$col] = $in === 'isActive' ? ($b[$in] ? 1 : 0) : $b[$in];
            }
        if (!$sets)
            admin_error('Nothing to update.');
        $s = $db->prepare('UPDATE farmers_market SET ' . implode(',', $sets) . ' WHERE id=:id');
        $s->execute($params);
        admin_audit($db, 'market_update', 'market', $id);
        admin_json(['id' => $id, 'updated' => true]);
    }
    if (count($parts) === 2 && $parts[0] === 'markets' && $method === 'DELETE') {
        $id = $parts[1];
        $s = $db->prepare('DELETE FROM farmers_market WHERE id=:id');
        $s->execute(['id' => $id]);
        admin_audit($db, 'market_delete', 'market', $id);
        admin_json(['id' => $id, 'deleted' => true]);
    }

    if ($parts === ['orders'] && $method === 'GET') {
        $sql = "SELECT o.id,o.client_order_id,o.source,o.status,o.market_id,
                " . (admin_column_exists($db, 'farmers_market', 'id') ? 'm.name' : 'NULL') . " market_name,
                " . (admin_column_exists($db, 'users', 'uid') ? 'u.full_name' : 'NULL') . " customer_name,
                o.total total_amount,o.created_at
              FROM orders o " .
            (admin_column_exists($db, 'farmers_market', 'id') ? 'LEFT JOIN farmers_market m ON m.id=o.market_id ' : '') .
            (admin_column_exists($db, 'users', 'uid') && admin_column_exists($db, 'orders', 'customer_id') ? "LEFT JOIN users u ON u.uid=o.customer_id " : '');
        $where = [];
        $params = [];
        if (isset($_GET['status']) && $_GET['status'] !== '') {
            $where[] = 'o.status=:status';
            $statusMap = [
                'pending' => 'Pending',
                'confirmed' => 'Confirmed',
                'ready_for_pickup' => 'Ready for Pickup',
                'completed' => 'Completed',
                'cancelled' => 'Cancelled',
            ];
            $requestedStatus = (string) $_GET['status'];
            if (!isset($statusMap[$requestedStatus])) {
                admin_error('Unsupported order status filter.');
            }
            $params['status'] = $statusMap[$requestedStatus];
        }
        if (isset($_GET['market']) && $_GET['market'] !== '') {
            $where[] = 'o.market_id=:market';
            $params['market'] = $_GET['market'];
        }
        if (isset($_GET['from']) && $_GET['from'] !== '') {
            $where[] = 'o.created_at>=:from';
            $params['from'] = $_GET['from'];
        }
        if (isset($_GET['to']) && $_GET['to'] !== '') {
            $where[] = 'o.created_at<=:to';
            $params['to'] = $_GET['to'];
        }
        if ($where)
            $sql .= ' WHERE ' . implode(' AND ', $where);
        $sql .= ' ORDER BY o.created_at DESC';
        $s = $db->prepare($sql);
        $s->execute($params);
        $rows = $s->fetchAll();
        foreach ($rows as &$r)
            $r['total_amount'] = (float) $r['total_amount'];
        admin_json($rows);
    }

    if ($parts === ['contact-messages'] && $method === 'GET') {
        $status = $_GET['status'] ?? null;
        $sql = 'SELECT id,name,email,message AS subject,message,status,created_at FROM contact_messages';
        $params = [];
        if ($status === 'pending' || $status === 'new') {
            $sql .= " WHERE status IN ('read','new')";
        } elseif ($status === 'resolved') {
            $sql .= " WHERE status='resolved'";
        }
        $sql .= ' ORDER BY created_at DESC';
        $s = $db->prepare($sql);
        $s->execute($params);
        admin_json($s->fetchAll());
    }
    if (count($parts) === 3 && $parts[0] === 'contact-messages' && $parts[2] === 'resolve' && $method === 'PATCH') {
        $id = $parts[1];
        $s = $db->prepare("UPDATE contact_messages SET status='resolved' WHERE id=:id");
        $s->execute(['id' => $id]);
        admin_audit($db, 'contact_resolve', 'contact_message', $id);
        admin_json(['id' => $id, 'resolved' => true]);
    }

    if ($parts === ['audit-log'] && $method === 'GET') {
        $sql = "SELECT a.id,a.actor_id,a.action,'system' AS entity_type,a.id AS entity_id,a.detail AS details,a.created_at,
              " . (admin_column_exists($db, 'users', 'uid') ? 'u.full_name' : 'NULL') . " actor_name
              FROM audit_logs a " . (admin_column_exists($db, 'users', 'uid') && admin_column_exists($db, 'audit_logs', 'actor_id') ? 'LEFT JOIN users u ON u.uid=a.actor_id ' : '');
        $where = [];
        $params = [];
        if (!empty($_GET['actor'])) {
            $where[] = 'a.actor_id=:actor';
            $params['actor'] = $_GET['actor'];
        }
        if (!empty($_GET['from'])) {
            $where[] = 'a.created_at>=:from';
            $params['from'] = $_GET['from'];
        }
        if (!empty($_GET['to'])) {
            $where[] = 'a.created_at<=:to';
            $params['to'] = $_GET['to'];
        }
        if ($where)
            $sql .= ' WHERE ' . implode(' AND ', $where);
        $sql .= ' ORDER BY a.created_at DESC LIMIT 500';
        $s = $db->prepare($sql);
        $s->execute($params);
        admin_json($s->fetchAll());
    }

    admin_error('Admin endpoint not found.', 404);
} catch (Throwable $e) {
    error_log('Admin API: ' . $e->getMessage());
    admin_error('Không thể xử lý yêu cầu admin. Kiểm tra tên bảng/cột trong database.', 500);
}
