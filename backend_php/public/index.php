<?php

declare(strict_types=1);

require dirname(__DIR__) . '/vendor/autoload.php';

use Dotenv\Dotenv;

$root = dirname(__DIR__);
Dotenv::createImmutable($root)->safeLoad();
require_once dirname(__DIR__) . '/src/fcm.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Authorization, Content-Type');
header('Access-Control-Allow-Methods: GET, PATCH, POST, PUT, DELETE, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

function respond(array $payload, int $status = 200): never
{
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function database(): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $dsn = sprintf(
        'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
        $_ENV['DB_HOST'] ?? '127.0.0.1',
        $_ENV['DB_PORT'] ?? '3306',
        $_ENV['DB_NAME'] ?? 'harvesthub'
    );

    $pdo = new PDO($dsn, $_ENV['DB_USER'] ?? 'root', $_ENV['DB_PASSWORD'] ?? '', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);

    return $pdo;
}

function requestBody(): array
{
    if ($_POST !== []) {
        return $_POST;
    }

    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        return [];
    }

    $body = json_decode($raw, true);
    return is_array($body) ? $body : [];
}

function bearerToken(): string
{
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/^Bearer\\s+(.+)$/i', $header, $matches)) {
        respond(['error' => 'Missing Bearer token'], 401);
    }

    return $matches[1];
}

function firebaseUser(): array
{
    $apiKey = $_ENV['FIREBASE_WEB_API_KEY'] ?? '';
    if ($apiKey === '') {
        respond(['error' => 'Firebase Web API key is not configured'], 500);
    }

    $handle = curl_init('https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' . rawurlencode($apiKey));
    curl_setopt_array($handle, [
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode(['idToken' => bearerToken()]),
        CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 15,
    ]);

    try {
        $response = curl_exec($handle);
        $status = curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        if ($response === false || $status < 200 || $status >= 300) {
            respond(['error' => 'Invalid Firebase token'], 401);
        }

        $payload = json_decode($response, true);
        $user = $payload['users'][0] ?? null;
        if (!is_array($user) || empty($user['localId']) || empty($user['email'])) {
            respond(['error' => 'Invalid Firebase user response'], 401);
        }

        return [
            'sub' => (string) $user['localId'],
            'email' => (string) $user['email'],
            'name' => (string) ($user['displayName'] ?? ''),
            'picture' => $user['photoUrl'] ?? null,
        ];
    } catch (Throwable $error) {
        error_log($error->getMessage());
        respond(['error' => 'Firebase verification failed'], 502);
    } finally {
        curl_close($handle);
    }
}

function requireAdminUser(): array
{
    $claims = firebaseUser();
    $statement = database()->prepare('SELECT role FROM users WHERE uid = :uid LIMIT 1');
    $statement->execute([':uid' => $claims['sub']]);
    if ($statement->fetchColumn() !== 'admin') {
        respond(['error' => 'Admin access required'], 403);
    }

    $GLOBALS['admin_actor_uid'] = $claims['sub'];
    return $claims;
}

function requireCustomerUser(): array
{
    $claims = firebaseUser();
    $statement = database()->prepare(
        'SELECT role, is_locked FROM users WHERE uid = :uid LIMIT 1'
    );
    $statement->execute([':uid' => $claims['sub']]);
    $user = $statement->fetch();
    if (!$user || $user['role'] !== 'customer' || (bool) $user['is_locked']) {
        respond(['error' => 'Customer access required'], 403);
    }
    return $claims;
}

function requireActiveAppUser(): array
{
    $claims = firebaseUser();
    $statement = database()->prepare(
        'SELECT is_locked FROM users WHERE uid = :uid LIMIT 1'
    );
    $statement->execute([':uid' => $claims['sub']]);
    $isLocked = $statement->fetchColumn();
    if ($isLocked === false || (bool) $isLocked) {
        respond(['error' => 'Active account required'], 403);
    }
    return $claims;
}

function requireApprovedFarmer(): array
{
    $claims = firebaseUser();
    $pdo = database();
    $userStatement = $pdo->prepare(
        'SELECT role, is_locked FROM users WHERE uid = :uid LIMIT 1'
    );
    $userStatement->execute([':uid' => $claims['sub']]);
    $user = $userStatement->fetch();
    if (!$user || $user['role'] !== 'farmer' || (bool) $user['is_locked']) {
        respond(['error' => 'Approved farmer access required'], 403);
    }

    $farmerStatement = $pdo->prepare(
        "SELECT id, farm_name, market_id, market_name, latitude, longitude, "
        . "address, description, avatar_url, is_locked, status FROM farmers "
        . "WHERE (user_uid = :uid OR (id = :legacy_id AND (user_uid IS NULL OR user_uid = ''))) "
        . "AND deleted_at IS NULL "
        . "ORDER BY created_at DESC LIMIT 1"
    );
    $farmerStatement->execute([
        ':uid' => $claims['sub'],
        ':legacy_id' => $claims['sub'],
    ]);
    $farmer = $farmerStatement->fetch();
    if (!$farmer || $farmer['status'] !== 'approved' || (bool) $farmer['is_locked']) {
        respond(['error' => 'Approved farmer access required'], 403);
    }

    return ['claims' => $claims, 'farmer' => $farmer];
}

function normalizeFarmerProduct(array $product): array
{
    $product['id'] = (string) $product['id'];
    $product['farmer_id'] = (string) $product['farmer_id'];
    $product['category_id'] = (string) $product['category_id'];
    $product['price'] = (float) $product['price'];
    $product['stock'] = (int) $product['stock'];
    $product['min_stock'] = (int) $product['min_stock'];
    $product['is_active'] = (int) $product['is_active'];
    $product['sold_count'] = (int) $product['sold_count'];
    $product['status'] = (empty($product['is_active']) || !empty($product['is_hidden']))
        ? 'hidden'
        : ((int) $product['stock'] <= 0 ? 'out_of_stock' : 'active');
    return $product;
}

function farmerProductImage(): ?string
{
    if (!isset($_FILES['image'])) {
        return null;
    }
    $file = $_FILES['image'];
    if (!is_array($file) || ($file['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_NO_FILE) {
        return null;
    }
    if (($file['error'] ?? UPLOAD_ERR_OK) !== UPLOAD_ERR_OK ||
        !isset($file['tmp_name'], $file['size']) ||
        (int) $file['size'] < 1 || (int) $file['size'] > 5 * 1024 * 1024) {
        respond(['error' => 'Product image must be smaller than 5 MB'], 422);
    }

    $mime = (new finfo(FILEINFO_MIME_TYPE))->file($file['tmp_name']);
    $extensions = [
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
    ];
    if (!is_string($mime) || !isset($extensions[$mime])) {
        respond(['error' => 'Product image must be JPEG, PNG or WebP'], 422);
    }

    $directory = __DIR__ . '/uploads/products';
    if (!is_dir($directory) && !mkdir($directory, 0755, true) && !is_dir($directory)) {
        respond(['error' => 'Product image storage is unavailable'], 500);
    }
    $filename = bin2hex(random_bytes(20)) . '.' . $extensions[$mime];
    if (!move_uploaded_file($file['tmp_name'], $directory . '/' . $filename)) {
        respond(['error' => 'Could not store product image'], 500);
    }
    return '/uploads/products/' . $filename;
}

function routePath(): string
{
    $path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
    return rtrim($path ?: '/', '/');
}

try {
    $method = $_SERVER['REQUEST_METHOD'];
    $path = routePath();

    if ($method === 'GET' && $path === '/api/health') {
        database()->query('SELECT 1');
        respond(['ok' => true, 'service' => 'harvesthub-php-api']);
    }

    if ($path === '/api/devices/fcm-token') {
        if (!in_array($method, ['POST', 'DELETE'], true)) {
            respond(['error' => 'Method not allowed'], 405);
        }
        $claims = requireActiveAppUser();
        $body = requestBody();
        $token = trim((string) ($body['token'] ?? ''));
        if ($token === '' || strlen($token) > 4096) {
            respond(['error' => 'Valid FCM token is required'], 422);
        }
        $pdo = database();
        $tokenHash = hash('sha256', $token);
        if ($method === 'POST') {
            $platform = (string) ($body['platform'] ?? '');
            if (!in_array($platform, ['android', 'ios'], true)) {
                respond(['error' => 'Supported platform is required'], 422);
            }
            $statement = $pdo->prepare(
                'INSERT INTO user_fcm_tokens (token_hash,user_id,token,platform,created_at,updated_at) '
                . 'VALUES (:token_hash,:user_id,:token,:platform,NOW(),NOW()) '
                . 'ON DUPLICATE KEY UPDATE user_id=VALUES(user_id),token=VALUES(token),'
                . 'platform=VALUES(platform),updated_at=NOW()'
            );
            $statement->execute([
                ':token_hash' => $tokenHash,
                ':user_id' => $claims['sub'],
                ':token' => $token,
                ':platform' => $platform,
            ]);
            respond(['ok' => true]);
        }

        $statement = $pdo->prepare(
            'DELETE FROM user_fcm_tokens WHERE token_hash=:token_hash AND user_id=:user_id'
        );
        $statement->execute([
            ':token_hash' => $tokenHash,
            ':user_id' => $claims['sub'],
        ]);
        respond(['ok' => true]);
    }

    if (str_starts_with($path, '/api/farmer/')) {
        if (!in_array($method, ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'], true)) {
            respond(['error' => 'Method not allowed'], 405);
        }

        $identity = requireApprovedFarmer();
        $farmer = $identity['farmer'];
        $farmerId = (string) $farmer['id'];
        $pdo = database();

        if ($path === '/api/farmer/profile') {
            if ($method === 'GET') {
                $statement = $pdo->prepare(
                    'SELECT f.farm_name,f.address,f.description,f.market_name,'
                    . 'f.latitude,f.longitude,u.phone FROM farmers f '
                    . 'LEFT JOIN users u ON u.uid = :uid WHERE f.id = :farmer_id LIMIT 1'
                );
                $statement->execute([
                    ':uid' => $identity['claims']['sub'],
                    ':farmer_id' => $farmerId,
                ]);
                $profile = $statement->fetch();
                if (!$profile) {
                    respond(['error' => 'Farmer profile not found'], 404);
                }
                respond(['data' => $profile]);
            }
            if ($method === 'PATCH') {
                $body = requestBody();
                $farmName = trim((string) ($body['farm_name'] ?? ''));
                $address = trim((string) ($body['address'] ?? ''));
                $description = trim((string) ($body['description'] ?? ''));
                $phone = trim((string) ($body['phone'] ?? ''));
                if ($farmName === '' || mb_strlen($farmName) > 200 ||
                    $address === '' || mb_strlen($address) > 500 ||
                    mb_strlen($description) > 10000 ||
                    !preg_match('/^\+?[0-9().\-\s]{7,30}$/', $phone) ||
                    preg_match_all('/[0-9]/', $phone) < 7 ||
                    preg_match_all('/[0-9]/', $phone) > 15) {
                    respond(['error' => 'Invalid farmer profile fields'], 422);
                }
                $pdo->beginTransaction();
                try {
                    $updateFarmer = $pdo->prepare(
                        'UPDATE farmers SET farm_name=:farm_name,address=:address,'
                        . 'description=:description,updated_at=NOW() WHERE id=:farmer_id'
                    );
                    $updateFarmer->execute([
                        ':farm_name' => $farmName,
                        ':address' => $address,
                        ':description' => $description === '' ? null : $description,
                        ':farmer_id' => $farmerId,
                    ]);
                    $updateUser = $pdo->prepare(
                        'UPDATE users SET phone=:phone WHERE uid=:uid'
                    );
                    $updateUser->execute([
                        ':phone' => $phone,
                        ':uid' => $identity['claims']['sub'],
                    ]);
                    $pdo->commit();
                } catch (Throwable $error) {
                    $pdo->rollBack();
                    throw $error;
                }
                respond(['ok' => true]);
            }
            respond(['error' => 'Method not allowed'], 405);
        }

        if (preg_match('#^/api/farmer/products(?:/([^/]+))?$#', $path, $matches)) {
            $productId = $matches[1] ?? null;
            if ($method === 'GET' && $productId === null) {
                $status = $_GET['status'] ?? null;
                $whereStatus = match ($status) {
                    null, '' => '',
                    'active' => ' AND p.is_active = 1 AND p.is_hidden = 0 AND p.stock > 0',
                    'out_of_stock' => ' AND p.is_active = 1 AND p.is_hidden = 0 AND p.stock <= 0',
                    'hidden' => ' AND (p.is_active = 0 OR p.is_hidden = 1)',
                    default => null,
                };
                if ($whereStatus === null) {
                    respond(['error' => 'Invalid product status filter'], 422);
                }
                $statement = $pdo->prepare(
                    'SELECT p.*, c.name AS category_name FROM products p '
                    . 'LEFT JOIN categories c ON c.id = p.category_id '
                    . 'WHERE p.farmer_id = :farmer_id AND p.deleted_at IS NULL'
                    . $whereStatus . ' ORDER BY p.created_at DESC'
                );
                $statement->execute([':farmer_id' => $farmerId]);
                $products = array_map('normalizeFarmerProduct', $statement->fetchAll());
                respond(['data' => $products]);
            }

            if ($method === 'GET' && $productId !== null) {
                $statement = $pdo->prepare(
                    'SELECT p.*, c.name AS category_name FROM products p '
                    . 'LEFT JOIN categories c ON c.id = p.category_id '
                    . 'WHERE p.id = :id AND p.farmer_id = :farmer_id '
                    . 'AND p.deleted_at IS NULL LIMIT 1'
                );
                $statement->execute([':id' => $productId, ':farmer_id' => $farmerId]);
                $product = $statement->fetch();
                if (!$product) {
                    respond(['error' => 'Product not found'], 404);
                }
                respond(['data' => normalizeFarmerProduct($product)]);
            }

            if ($method === 'POST' && $productId === null) {
                $body = requestBody();
                $name = trim((string) ($body['name'] ?? ''));
                $unit = trim((string) ($body['unit'] ?? ''));
                $categoryId = trim((string) ($body['category_id'] ?? ''));
                $price = filter_var($body['price'] ?? null, FILTER_VALIDATE_FLOAT);
                $stock = filter_var($body['stock'] ?? null, FILTER_VALIDATE_INT);
                $minStock = filter_var($body['min_stock'] ?? 0, FILTER_VALIDATE_INT);
                $description = trim((string) ($body['description'] ?? ''));
                if ($name === '' || mb_strlen($name) > 200 ||
                    $unit === '' || mb_strlen($unit) > 50 ||
                    $categoryId === '' || $price === false || $price <= 0 ||
                    $stock === false || $stock < 0 ||
                    $minStock === false || $minStock < 0 ||
                    mb_strlen($description) > 10000) {
                    respond(['error' => 'Invalid product fields'], 422);
                }
                $category = $pdo->prepare(
                    'SELECT id FROM categories WHERE id = :id AND is_active = 1 '
                    . 'AND deleted_at IS NULL LIMIT 1'
                );
                $category->execute([':id' => $categoryId]);
                if (!$category->fetchColumn()) {
                    respond(['error' => 'Active category not found'], 422);
                }

                $imageUrl = farmerProductImage() ?? trim((string) ($body['image_url'] ?? ''));
                $imageUrl = $imageUrl === '' ? null : $imageUrl;
                $productId = bin2hex(random_bytes(20));
                $isActive = filter_var($body['is_active'] ?? 1, FILTER_VALIDATE_BOOLEAN) ? 1 : 0;
                $insert = $pdo->prepare(
                    'INSERT INTO products (id,name,name_lower,category_id,price,unit,stock,'
                    . 'min_stock,description,image_url,farmer_id,farmer_name,market_id,market_name,'
                    . 'latitude,longitude,is_active,created_at,updated_at) VALUES '
                    . '(:id,:name,:name_lower,:category_id,:price,:unit,:stock,:min_stock,'
                    . ':description,:image_url,:farmer_id,:farmer_name,:market_id,:market_name,'
                    . ':latitude,:longitude,:is_active,NOW(),NOW())'
                );
                $insert->execute([
                    ':id' => $productId,
                    ':name' => $name,
                    ':name_lower' => mb_strtolower($name),
                    ':category_id' => $categoryId,
                    ':price' => $price,
                    ':unit' => $unit,
                    ':stock' => $stock,
                    ':min_stock' => $minStock,
                    ':description' => $description === '' ? null : $description,
                    ':image_url' => $imageUrl,
                    ':farmer_id' => $farmerId,
                    ':farmer_name' => $farmer['farm_name'],
                    ':market_id' => $farmer['market_id'],
                    ':market_name' => $farmer['market_name'],
                    ':latitude' => $farmer['latitude'],
                    ':longitude' => $farmer['longitude'],
                    ':is_active' => $isActive,
                ]);
                respond(['data' => ['id' => $productId]], 201);
            }

            if ($method === 'PUT' && $productId !== null) {
                $body = requestBody();
                $currentStatement = $pdo->prepare(
                    'SELECT id FROM products WHERE id = :id AND farmer_id = :farmer_id '
                    . 'AND deleted_at IS NULL LIMIT 1'
                );
                $currentStatement->execute([':id' => $productId, ':farmer_id' => $farmerId]);
                if (!$currentStatement->fetchColumn()) {
                    respond(['error' => 'Product not found'], 404);
                }

                $fields = [];
                $params = [':id' => $productId, ':farmer_id' => $farmerId];
                foreach (['name', 'unit', 'description', 'image_url'] as $field) {
                    if (!array_key_exists($field, $body)) {
                        continue;
                    }
                    $value = trim((string) $body[$field]);
                    $max = $field === 'name' ? 200 : ($field === 'unit' ? 50 : 10000);
                    if (($field === 'name' || $field === 'unit') && $value === '' ||
                        mb_strlen($value) > $max) {
                        respond(['error' => "Invalid $field"], 422);
                    }
                    $fields[] = "$field = :$field";
                    $params[":$field"] = $value === '' ? null : $value;
                    if ($field === 'name') {
                        $fields[] = 'name_lower = :name_lower';
                        $params[':name_lower'] = mb_strtolower($value);
                    }
                }
                foreach (['price', 'stock', 'min_stock', 'category_id', 'is_active'] as $field) {
                    if (!array_key_exists($field, $body)) {
                        continue;
                    }
                    if ($field === 'category_id') {
                        $categoryId = trim((string) $body[$field]);
                        $category = $pdo->prepare(
                            'SELECT id FROM categories WHERE id = :id AND is_active = 1 '
                            . 'AND deleted_at IS NULL LIMIT 1'
                        );
                        $category->execute([':id' => $categoryId]);
                        if (!$category->fetchColumn()) {
                            respond(['error' => 'Active category not found'], 422);
                        }
                        $value = $categoryId;
                    } elseif ($field === 'is_active') {
                        $value = filter_var($body[$field], FILTER_VALIDATE_BOOLEAN) ? 1 : 0;
                    } else {
                        $value = filter_var(
                            $body[$field],
                            $field === 'price' ? FILTER_VALIDATE_FLOAT : FILTER_VALIDATE_INT
                        );
                        if ($value === false || $value < ($field === 'price' ? 0.01 : 0)) {
                            respond(['error' => "Invalid $field"], 422);
                        }
                    }
                    $fields[] = "$field = :$field";
                    $params[":$field"] = $value;
                }
                $uploadedImage = farmerProductImage();
                if ($uploadedImage !== null) {
                    $fields[] = 'image_url = :uploaded_image';
                    $params[':uploaded_image'] = $uploadedImage;
                }
                if ($fields === []) {
                    respond(['error' => 'No product fields to update'], 422);
                }
                $fields[] = 'updated_at = NOW()';
                $update = $pdo->prepare(
                    'UPDATE products SET ' . implode(', ', $fields)
                    . ' WHERE id = :id AND farmer_id = :farmer_id AND deleted_at IS NULL'
                );
                $update->execute($params);
                respond(['ok' => true]);
            }

            if ($method === 'DELETE' && $productId !== null) {
                $delete = $pdo->prepare(
                    'UPDATE products SET deleted_at = NOW(), updated_at = NOW() '
                    . 'WHERE id = :id AND farmer_id = :farmer_id AND deleted_at IS NULL'
                );
                $delete->execute([':id' => $productId, ':farmer_id' => $farmerId]);
                if ($delete->rowCount() === 0) {
                    respond(['error' => 'Product not found'], 404);
                }
                respond(['ok' => true]);
            }
            respond(['error' => 'Method not allowed'], 405);
        }

        if ($path === '/api/farmer/orders') {
            if ($method === 'GET') {
                $status = trim((string) ($_GET['status'] ?? ''));
                $sql = 'SELECT id, customer_name, total, status, pickup_time '
                    . 'FROM orders WHERE farmer_id = :farmer_id';
                $params = [':farmer_id' => $farmerId];
                if ($status !== '') {
                    $allowed = ['Pending', 'Confirmed', 'Ready for Pickup', 'Completed', 'Cancelled'];
                    if (!in_array($status, $allowed, true)) {
                        respond(['error' => 'Invalid order status filter'], 422);
                    }
                    $sql .= ' AND status = :status';
                    $params[':status'] = $status;
                }
                $sql .= ' ORDER BY created_at DESC';
                $statement = $pdo->prepare($sql);
                $statement->execute($params);
                $orders = $statement->fetchAll();
                foreach ($orders as &$order) {
                    $order['id'] = (string) $order['id'];
                    $order['total'] = (float) $order['total'];
                }
                unset($order);
                respond(['data' => $orders]);
            }
            if ($method === 'PATCH' &&
                preg_match('#^/api/farmer/orders/([^/]+)$#', $path, $matches)) {
                $body = requestBody();
                $nextStatus = (string) ($body['status'] ?? '');
                $orderStatement = $pdo->prepare(
                    'SELECT status FROM orders WHERE id = :id AND farmer_id = :farmer_id LIMIT 1'
                );
                $orderStatement->execute([':id' => $matches[1], ':farmer_id' => $farmerId]);
                $currentStatus = $orderStatement->fetchColumn();
                if (!is_string($currentStatus)) {
                    respond(['error' => 'Order not found'], 404);
                }
                $transitions = [
                    'Pending' => ['Confirmed', 'Cancelled'],
                    'Confirmed' => ['Ready for Pickup', 'Cancelled'],
                    'Ready for Pickup' => ['Completed'],
                    'Completed' => [],
                    'Cancelled' => [],
                ];
                if (!in_array($nextStatus, $transitions[$currentStatus] ?? [], true)) {
                    respond(['error' => 'Invalid order status transition'], 422);
                }
                $update = $pdo->prepare(
                    'UPDATE orders SET status = :status, updated_at = NOW() '
                    . 'WHERE id = :id AND farmer_id = :farmer_id'
                );
                $update->execute([
                    ':status' => $nextStatus,
                    ':id' => $matches[1],
                    ':farmer_id' => $farmerId,
                ]);
                respond(['ok' => true]);
            }
            respond(['error' => 'Method not allowed'], 405);
        }

        if ($path === '/api/farmer/pickup-slots') {
            if ($method === 'GET') {
                $statement = $pdo->prepare(
                    'SELECT id,start_time,end_time,capacity,booked_count,is_open '
                    . 'FROM pickup_slots WHERE farmer_id = :farmer_id ORDER BY start_time DESC'
                );
                $statement->execute([':farmer_id' => $farmerId]);
                $slots = $statement->fetchAll();
                foreach ($slots as &$slot) {
                    $slot['id'] = (string) $slot['id'];
                    $slot['capacity'] = (int) $slot['capacity'];
                    $slot['booked_count'] = (int) $slot['booked_count'];
                    $slot['is_open'] = (int) $slot['is_open'];
                }
                unset($slot);
                respond(['data' => $slots]);
            }
            if ($method === 'POST') {
                $body = requestBody();
                $start = strtotime((string) ($body['start_time'] ?? ''));
                $end = strtotime((string) ($body['end_time'] ?? ''));
                $capacity = filter_var($body['capacity'] ?? null, FILTER_VALIDATE_INT);
                if ($start === false || $end === false || $end <= $start ||
                    $capacity === false || $capacity < 1 || $capacity > 1000) {
                    respond(['error' => 'Invalid pickup slot fields'], 422);
                }
                $insert = $pdo->prepare(
                    'INSERT INTO pickup_slots (id,farmer_id,farmer_name,market_id,'
                    . 'start_time,end_time,capacity,booked_count,is_open) VALUES '
                    . '(:id,:farmer_id,:farmer_name,:market_id,:start,:end,:capacity,0,1)'
                );
                $insert->execute([
                    ':id' => bin2hex(random_bytes(20)),
                    ':farmer_id' => $farmerId,
                    ':farmer_name' => $farmer['farm_name'],
                    ':market_id' => $farmer['market_id'],
                    ':start' => date('Y-m-d H:i:s', $start),
                    ':end' => date('Y-m-d H:i:s', $end),
                    ':capacity' => $capacity,
                ]);
                respond(['ok' => true], 201);
            }
            if ($method === 'PATCH') {
                $body = requestBody();
                $slotId = trim((string) ($body['id'] ?? ''));
                if ($slotId === '' || !array_key_exists('is_open', $body)) {
                    respond(['error' => 'Pickup slot id and is_open are required'], 422);
                }
                $update = $pdo->prepare(
                    'UPDATE pickup_slots SET is_open = :is_open '
                    . 'WHERE id = :id AND farmer_id = :farmer_id'
                );
                $update->execute([
                    ':is_open' => filter_var($body['is_open'], FILTER_VALIDATE_BOOLEAN) ? 1 : 0,
                    ':id' => $slotId,
                    ':farmer_id' => $farmerId,
                ]);
                if ($update->rowCount() === 0) {
                    $check = $pdo->prepare(
                        'SELECT id FROM pickup_slots WHERE id = :id AND farmer_id = :farmer_id'
                    );
                    $check->execute([':id' => $slotId, ':farmer_id' => $farmerId]);
                    if (!$check->fetchColumn()) {
                        respond(['error' => 'Pickup slot not found'], 404);
                    }
                }
                respond(['ok' => true]);
            }
            if ($method === 'DELETE') {
                $slotId = trim((string) ($_GET['id'] ?? ''));
                $delete = $pdo->prepare(
                    'DELETE FROM pickup_slots WHERE id = :id AND farmer_id = :farmer_id '
                    . 'AND booked_count = 0'
                );
                $delete->execute([':id' => $slotId, ':farmer_id' => $farmerId]);
                if ($delete->rowCount() === 0) {
                    respond(['error' => 'Slot not found or already has bookings'], 409);
                }
                respond(['ok' => true]);
            }
            respond(['error' => 'Method not allowed'], 405);
        }

        if ($path === '/api/farmer/notifications' && $method === 'GET') {
            $statement = $pdo->prepare(
                'SELECT id,title,body,order_id,product_id,is_read,created_at FROM notifications '
                . 'WHERE user_id = :user_id ORDER BY created_at DESC LIMIT 100'
            );
            $statement->execute([':user_id' => $identity['claims']['sub']]);
            $notifications = $statement->fetchAll();
            foreach ($notifications as &$notification) {
                $notification['id'] = (string) $notification['id'];
                $notification['is_read'] = (int) $notification['is_read'];
            }
            unset($notification);
            respond(['data' => $notifications]);
        }
        if ($path === '/api/farmer/notifications' && $method === 'PATCH') {
            $body = requestBody();
            $notificationId = trim((string) ($body['id'] ?? ''));
            $update = $pdo->prepare(
                'UPDATE notifications SET is_read = 1 WHERE id = :id AND user_id = :user_id'
            );
            $update->execute([
                ':id' => $notificationId,
                ':user_id' => $identity['claims']['sub'],
            ]);
            if ($update->rowCount() === 0) {
                $check = $pdo->prepare(
                    'SELECT id FROM notifications WHERE id = :id AND user_id = :user_id'
                );
                $check->execute([
                    ':id' => $notificationId,
                    ':user_id' => $identity['claims']['sub'],
                ]);
                if (!$check->fetchColumn()) {
                    respond(['error' => 'Notification not found'], 404);
                }
            }
            respond(['ok' => true]);
        }

        if ($path === '/api/farmer/reviews' && $method === 'GET') {
            $statement = $pdo->prepare(
                'SELECT id,user_name,rating,comment,created_at FROM reviews '
                . 'WHERE farmer_id = :farmer_id ORDER BY created_at DESC LIMIT 100'
            );
            $statement->execute([':farmer_id' => $farmerId]);
            $reviews = $statement->fetchAll();
            foreach ($reviews as &$review) {
                $review['rating'] = (int) $review['rating'];
            }
            unset($review);
            respond(['data' => $reviews]);
        }

        if ($path === '/api/farmer/reports' && $method === 'GET') {
            $statement = $pdo->prepare(
                "SELECT COUNT(*) AS total_orders, "
                . "COALESCE(SUM(CASE WHEN status = 'Completed' THEN total ELSE 0 END), 0) AS revenue, "
                . "SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) AS completed_orders "
                . 'FROM orders WHERE farmer_id = :farmer_id'
            );
            $statement->execute([':farmer_id' => $farmerId]);
            $report = $statement->fetch() ?: [];
            $productStatement = $pdo->prepare(
                'SELECT COUNT(*) AS total_products, '
                . 'SUM(CASE WHEN stock <= min_stock AND is_active = 1 AND is_hidden = 0 '
                . 'THEN 1 ELSE 0 END) AS low_stock FROM products '
                . 'WHERE farmer_id = :farmer_id AND deleted_at IS NULL'
            );
            $productStatement->execute([':farmer_id' => $farmerId]);
            $productReport = $productStatement->fetch() ?: [];
            respond(['data' => [
                'total_orders' => (int) ($report['total_orders'] ?? 0),
                'revenue' => (float) ($report['revenue'] ?? 0),
                'completed_orders' => (int) ($report['completed_orders'] ?? 0),
                'total_products' => (int) ($productReport['total_products'] ?? 0),
                'low_stock' => (int) ($productReport['low_stock'] ?? 0),
            ]]);
        }

        if ($path === '/api/farmer/following' && $method === 'GET') {
            $statement = $pdo->prepare(
                'SELECT u.uid AS user_id,u.full_name AS user_name,u.email,ff.followed_at '
                . 'FROM farmer_followers ff JOIN users u ON u.uid=ff.user_id '
                . 'WHERE ff.farmer_id=:farmer_id ORDER BY ff.followed_at DESC'
            );
            $statement->execute([':farmer_id' => $farmerId]);
            respond(['data' => $statement->fetchAll()]);
        }

        if (($path === '/api/farmer/announcements' ||
            $path === '/api/farmer/following') && $method === 'POST') {
            $body = requestBody();
            $title = trim((string) ($body['title'] ?? ''));
            $message = trim((string) ($body['body'] ?? ''));
            if ($title === '' || mb_strlen($title) > 255 ||
                $message === '' || mb_strlen($message) > 5000) {
                respond(['error' => 'Announcement title and message are required'], 422);
            }

            $pdo->beginTransaction();
            try {
                $countStatement = $pdo->prepare(
                    'SELECT COUNT(*) FROM farmer_followers WHERE farmer_id=:farmer_id'
                );
                $countStatement->execute([':farmer_id' => $farmerId]);
                $recipientCount = (int) $countStatement->fetchColumn();
                if ($recipientCount > 0) {
                    $insert = $pdo->prepare(
                        "INSERT INTO notifications "
                        . "(id,user_id,type,title,body,order_id,product_id,is_read,created_at) "
                        . "SELECT REPLACE(UUID(),'-',''),ff.user_id,'farmer_announcement',"
                        . ":title,CONCAT(:farm_name,'\\n\\n',:body),NULL,NULL,0,NOW() "
                        . "FROM farmer_followers ff "
                        . "WHERE ff.farmer_id=:farmer_id"
                    );
                    $insert->execute([
                        ':title' => $title,
                        ':farm_name' => $farmer['farm_name'],
                        ':body' => $message,
                        ':farmer_id' => $farmerId,
                    ]);
                    $recipientCount = $insert->rowCount();
                }
                $pdo->commit();
            } catch (Throwable $error) {
                if ($pdo->inTransaction()) {
                    $pdo->rollBack();
                }
                throw $error;
            }

            $pushResult = [
                'status' => 'no_devices',
                'sent_count' => 0,
                'failed_count' => 0,
            ];
            if ($recipientCount > 0) {
                $devices = $pdo->prepare(
                    'SELECT DISTINCT t.token_hash,t.token FROM farmer_followers ff '
                    . 'JOIN user_fcm_tokens t ON t.user_id=ff.user_id '
                    . 'JOIN users u ON u.uid=ff.user_id AND u.is_locked=0 '
                    . 'WHERE ff.farmer_id=:farmer_id'
                );
                $devices->execute([':farmer_id' => $farmerId]);
                $deviceTokens = $devices->fetchAll();
                try {
                    $pushResult = sendFcmAnnouncement(
                        $pdo,
                        $deviceTokens,
                        trim((string) ($_ENV['FCM_PROJECT_ID'] ?? '')),
                        trim((string) ($_ENV['FCM_SERVICE_ACCOUNT_PATH'] ?? '')),
                        $title,
                        mb_strcut(
                            $farmer['farm_name'] . "\n\n" . $message,
                            0,
                            2000,
                            'UTF-8'
                        )
                    );
                } catch (Throwable $error) {
                    error_log('FCM announcement delivery failed: ' . $error->getMessage());
                    $pushResult = [
                        'status' => 'failed',
                        'sent_count' => 0,
                        'failed_count' => count($deviceTokens),
                    ];
                }
            }
            respond([
                'ok' => true,
                'sent_count' => $recipientCount,
                'push' => $pushResult,
            ], 201);
        }

        respond(['error' => 'Farmer API route not found'], 404);
    }

    if (str_starts_with($path, '/api/admin/')) {
        if (!in_array($method, ['GET', 'POST', 'PATCH', 'DELETE'], true)) {
            respond(['error' => 'Method not allowed'], 405);
        }
        requireAdminUser();
        $_GET['path'] = substr($path, strlen('/api/admin/'));
        require dirname(__DIR__) . '/admin_api/admin/index.php';
        exit;
    }

    if (str_starts_with($path, '/api/reports/')) {
        if ($method !== 'GET') {
            respond(['error' => 'Method not allowed'], 405);
        }
        requireAdminUser();
        $_GET['path'] = substr($path, strlen('/api/reports/'));
        require dirname(__DIR__) . '/admin_api/reports/index.php';
        exit;
    }

    if ($method === 'POST' && $path === '/api/contact-messages') {
        $body = requestBody();
        $name = trim((string) ($body['name'] ?? ''));
        $email = trim((string) ($body['email'] ?? ''));
        $message = trim((string) ($body['message'] ?? ''));

        if ($name === '' || $email === '' || $message === '') {
            respond(['error' => 'Name, email and message are required'], 422);
        }
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            respond(['error' => 'Invalid email'], 422);
        }

        $statement = database()->prepare(
            'INSERT INTO contact_messages (id, name, email, message, status, created_at) '
            . "VALUES (:id, :name, :email, :message, 'new', NOW())"
        );
        $statement->execute([
            ':id' => bin2hex(random_bytes(25)),
            ':name' => $name,
            ':email' => $email,
            ':message' => $message,
        ]);

        respond(['ok' => true], 201);
    }

    if ($method === 'POST' && $path === '/api/auth/sync') {
        $claims = firebaseUser();
        $body = requestBody();
        $uid = (string) ($claims['sub'] ?? '');
        $email = (string) ($claims['email'] ?? '');
        $fullName = trim((string) ($body['full_name'] ?? $claims['name'] ?? ''));
        $provider = ($body['auth_provider'] ?? 'password') === 'google' ? 'google' : 'password';

        // The client may request customer/farmer registration, but it cannot
        // grant itself a privileged role. New accounts start as customers;
        // farmer access must be granted by an administrator after approval.
        $requestedRole = $body['role'] ?? 'customer';
        if (!is_string($requestedRole) ||
            !in_array($requestedRole, ['customer', 'farmer'], true)) {
            respond(['error' => 'Invalid role: must be customer or farmer'], 422);
        }
        $initialRole = 'customer';

        if ($uid === '' || $email === '' || $fullName === '') {
            respond(['error' => 'Firebase token is missing required user data'], 422);
        }

        // Existing account roles are omitted from ON DUPLICATE KEY UPDATE,
        // so sync cannot change a role previously granted by an administrator.
        $sql = <<<'SQL'
INSERT INTO users (uid, email, full_name, role, auth_provider, preferred_language, avatar_url, created_at)
VALUES (:uid, :email, :full_name, :role, :auth_provider, 'vi', :avatar_url, NOW())
ON DUPLICATE KEY UPDATE
  email = VALUES(email),
  full_name = VALUES(full_name),
  auth_provider = VALUES(auth_provider),
  avatar_url = VALUES(avatar_url)
SQL;
        $statement = database()->prepare($sql);
        $statement->execute([
            ':uid' => $uid,
            ':email' => $email,
            ':full_name' => $fullName,
            ':role' => $initialRole,
            ':auth_provider' => $provider,
            ':avatar_url' => $claims['picture'] ?? null,
        ]);

        $userStatement = database()->prepare('SELECT * FROM users WHERE uid = :uid');
        $userStatement->execute([':uid' => $uid]);
        respond(['user' => $userStatement->fetch()]);
    }

    if ($method === 'GET' && $path === '/api/farmer-applications/me') {
        $claims = firebaseUser();
        $statement = database()->prepare(
            'SELECT f.id, f.farm_name, f.market_id, m.name AS market_name, '
            . 'm.address AS market_address, '
            . 'f.address, f.description, f.latitude, f.longitude, f.status, '
            . 'u.phone AS contact_phone FROM farmers f '
            . 'LEFT JOIN users u ON u.uid = COALESCE(NULLIF(f.user_uid, \'\'), f.id) '
            . 'LEFT JOIN farmers_market m ON m.id = f.market_id '
            . 'WHERE f.user_uid = :user_uid OR f.id = :farmer_id '
            . 'ORDER BY f.created_at DESC LIMIT 1'
        );
        $statement->execute([
            ':user_uid' => $claims['sub'],
            ':farmer_id' => $claims['sub'],
        ]);
        respond(['application' => $statement->fetch() ?: null]);
    }

    if ($method === 'POST' && $path === '/api/farmer-applications') {
        $claims = firebaseUser();
        $body = requestBody();
        $farmName = trim((string) ($body['farm_name'] ?? ''));
        $marketId = trim((string) ($body['market_id'] ?? ''));
        $address = trim((string) ($body['address'] ?? ''));
        $contactPhone = trim((string) ($body['contact_phone'] ?? ''));
        $description = trim((string) ($body['description'] ?? ''));
        $latitudeValue = $body['latitude'] ?? null;
        $longitudeValue = $body['longitude'] ?? null;
        $latitude = $latitudeValue === null || $latitudeValue === ''
            ? null : filter_var($latitudeValue, FILTER_VALIDATE_FLOAT);
        $longitude = $longitudeValue === null || $longitudeValue === ''
            ? null : filter_var($longitudeValue, FILTER_VALIDATE_FLOAT);

        if ($farmName === '' || mb_strlen($farmName) > 200 ||
            $marketId === '' || $address === '' || mb_strlen($address) > 500 ||
            $contactPhone === '' || mb_strlen($contactPhone) > 30 ||
            !preg_match('/^\+?[0-9().\-\s]{7,30}$/', $contactPhone) ||
            preg_match_all('/[0-9]/', $contactPhone) < 7 ||
            preg_match_all('/[0-9]/', $contactPhone) > 15 ||
            mb_strlen($description) > 1000) {
            respond(['error' => 'Invalid farmer application fields'], 422);
        }
        if (($latitudeValue !== null && $latitude === false) ||
            ($longitudeValue !== null && $longitude === false) ||
            $latitude === null || $longitude === null ||
            ($latitude !== null && ($latitude < -90 || $latitude > 90)) ||
            ($longitude !== null && ($longitude < -180 || $longitude > 180))) {
            respond(['error' => 'Valid device GPS coordinates are required'], 422);
        }

        $pdo = database();
        $pdo->beginTransaction();
        try {
            $userStatement = $pdo->prepare(
                'SELECT role, is_locked FROM users WHERE uid = :uid FOR UPDATE'
            );
            $userStatement->execute([':uid' => $claims['sub']]);
            $user = $userStatement->fetch();
            if (!$user) {
                $pdo->rollBack();
                respond(['error' => 'user_not_synced'], 404);
            }
            if ((bool) $user['is_locked']) {
                $pdo->rollBack();
                respond(['error' => 'account_locked'], 403);
            }
            if ($user['role'] === 'admin') {
                $pdo->rollBack();
                respond(['error' => 'Admin accounts cannot apply as farmers'], 403);
            }

            $marketStatement = $pdo->prepare(
                'SELECT id FROM farmers_market '
                . 'WHERE id = :market_id AND is_active = 1 AND deleted_at IS NULL LIMIT 1'
            );
            $marketStatement->execute([':market_id' => $marketId]);
            if (!$marketStatement->fetchColumn()) {
                $pdo->rollBack();
                respond(['error' => 'Market not found or inactive'], 422);
            }

            $phoneStatement = $pdo->prepare(
                'UPDATE users SET phone = :phone WHERE uid = :uid'
            );
            $phoneStatement->execute([
                ':phone' => $contactPhone,
                ':uid' => $claims['sub'],
            ]);

            $applicationStatement = $pdo->prepare(
                'SELECT id, status FROM farmers '
                . 'WHERE user_uid = :user_uid OR id = :farmer_id '
                . 'ORDER BY created_at DESC LIMIT 1 FOR UPDATE'
            );
            $applicationStatement->execute([
                ':user_uid' => $claims['sub'],
                ':farmer_id' => $claims['sub'],
            ]);
            $existing = $applicationStatement->fetch();
            if ($existing && $existing['status'] === 'approved') {
                $pdo->commit();
                $statement = $pdo->prepare(
                    'SELECT f.id, f.farm_name, f.market_id, m.name AS market_name, '
                    . 'm.address AS market_address, '
                    . 'f.address, f.description, f.latitude, f.longitude, f.status, '
                    . 'u.phone AS contact_phone FROM farmers f '
                    . 'LEFT JOIN users u ON u.uid = COALESCE(NULLIF(f.user_uid, \'\'), f.id) '
                    . 'LEFT JOIN farmers_market m ON m.id = f.market_id '
                    . 'WHERE f.id = :id LIMIT 1'
                );
                $statement->execute([':id' => $existing['id']]);
                respond(['application' => $statement->fetch()]);
            }

            if ($existing) {
                $save = $pdo->prepare(
                    "UPDATE farmers SET farm_name=:farm_name, market_id=:market_id, address=:address, "
                    . "description=:description, latitude=:latitude, longitude=:longitude, "
                    . "user_uid=:uid, status='pending', updated_at=NOW() WHERE id=:id"
                );
                $save->execute([
                    ':farm_name' => $farmName,
                    ':market_id' => $marketId,
                    ':address' => $address,
                    ':description' => $description !== '' ? $description : null,
                    ':latitude' => $latitude,
                    ':longitude' => $longitude,
                    ':uid' => $claims['sub'],
                    ':id' => $existing['id'],
                ]);
            } else {
                $save = $pdo->prepare(
                    "INSERT INTO farmers "
                    . "(id, user_uid, farm_name, market_id, address, description, latitude, longitude, status) "
                    . "VALUES (:id, :uid, :farm_name, :market_id, :address, :description, "
                    . ":latitude, :longitude, 'pending')"
                );
                $save->execute([
                    ':id' => $claims['sub'],
                    ':uid' => $claims['sub'],
                    ':farm_name' => $farmName,
                    ':market_id' => $marketId,
                    ':address' => $address,
                    ':description' => $description !== '' ? $description : null,
                    ':latitude' => $latitude,
                    ':longitude' => $longitude,
                ]);
            }
            $pdo->commit();

            $statement = $pdo->prepare(
                'SELECT f.id, f.farm_name, f.market_id, m.name AS market_name, '
                . 'm.address AS market_address, '
                . 'f.address, f.description, f.latitude, f.longitude, f.status, '
                . 'u.phone AS contact_phone FROM farmers f '
                . 'LEFT JOIN users u ON u.uid = COALESCE(NULLIF(f.user_uid, \'\'), f.id) '
                . 'LEFT JOIN farmers_market m ON m.id = f.market_id '
                . 'WHERE f.user_uid = :uid LIMIT 1'
            );
            $statement->execute([':uid' => $claims['sub']]);
            respond(['application' => $statement->fetch()]);
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
    }

    if ($method === 'GET' && $path === '/api/auth/me') {
        $claims = firebaseUser();
        $statement = database()->prepare(
            'SELECT uid, email, full_name, role, preferred_language, avatar_url, created_at '
            . 'FROM users WHERE uid = :uid LIMIT 1'
        );
        $statement->execute([':uid' => $claims['sub']]);
        $user = $statement->fetch();
        if (!$user) {
            respond(['error' => 'user_not_synced'], 404);
        }

        respond($user);
    }

    if ($path === '/api/users/me') {
        $claims = requireActiveAppUser();
        $pdo = database();
        if ($method === 'GET') {
            $statement = $pdo->prepare(
                'SELECT uid,email,full_name,phone,address,auth_provider,'
                . 'preferred_language,avatar_url,created_at '
                . 'FROM users WHERE uid=:uid LIMIT 1'
            );
            $statement->execute([':uid' => $claims['sub']]);
            $profile = $statement->fetch();
            if (!$profile) {
                respond(['error' => 'User not found'], 404);
            }
            respond(['data' => $profile]);
        }
        if ($method !== 'PATCH') {
            respond(['error' => 'Method not allowed'], 405);
        }

        $body = requestBody();
        $fields = [];
        $params = [':uid' => $claims['sub']];
        if (array_key_exists('full_name', $body)) {
            $fullName = trim((string) $body['full_name']);
            if ($fullName === '' || mb_strlen($fullName) > 150) {
                respond(['error' => 'Invalid full_name'], 422);
            }
            $fields[] = 'full_name=:full_name';
            $params[':full_name'] = $fullName;
        }
        if (array_key_exists('phone', $body)) {
            $phone = trim((string) $body['phone']);
            if (mb_strlen($phone) > 30) {
                respond(['error' => 'Invalid phone'], 422);
            }
            $fields[] = 'phone=:phone';
            $params[':phone'] = $phone === '' ? null : $phone;
        }
        if (array_key_exists('address', $body)) {
            $address = trim((string) $body['address']);
            if (mb_strlen($address) > 500) {
                respond(['error' => 'Invalid address'], 422);
            }
            $fields[] = 'address=:address';
            $params[':address'] = $address === '' ? null : $address;
        }
        if (array_key_exists('preferred_language', $body)) {
            $language = (string) $body['preferred_language'];
            if (!in_array($language, ['vi', 'en'], true)) {
                respond(['error' => 'preferred_language must be vi or en'], 422);
            }
            $fields[] = 'preferred_language=:preferred_language';
            $params[':preferred_language'] = $language;
        }
        if (array_key_exists('avatar_url', $body)) {
            $avatarUrl = $body['avatar_url'] === null
                ? null
                : trim((string) $body['avatar_url']);
            if ($avatarUrl !== null) {
                $parsedUrl = parse_url($avatarUrl);
                $decodedPath = rawurldecode((string) ($parsedUrl['path'] ?? ''));
                if (($parsedUrl['scheme'] ?? '') !== 'https' ||
                    ($parsedUrl['host'] ?? '') !== 'firebasestorage.googleapis.com' ||
                    !str_contains($decodedPath, '/o/avatars/' . $claims['sub'] . '/')) {
                    respond(['error' => 'Avatar must be stored in the user Firebase Storage folder'], 422);
                }
            }
            $fields[] = 'avatar_url=:avatar_url';
            $params[':avatar_url'] = $avatarUrl;
        }
        if ($fields === []) {
            respond(['error' => 'No profile fields to update'], 422);
        }

        $update = $pdo->prepare(
            'UPDATE users SET ' . implode(', ', $fields) . ' WHERE uid=:uid'
        );
        $update->execute($params);
        $statement = $pdo->prepare(
            'SELECT uid,email,full_name,phone,address,auth_provider,'
            . 'preferred_language,avatar_url,created_at '
            . 'FROM users WHERE uid=:uid LIMIT 1'
        );
        $statement->execute([':uid' => $claims['sub']]);
        respond(['ok' => true, 'data' => $statement->fetch()]);
    }

    if ($path === '/api/orders') {
        $claims = requireCustomerUser();
        if ($method !== 'GET') {
            respond(['error' => 'Method not allowed'], 405);
        }
        $status = trim((string) ($_GET['status'] ?? ''));
        $allowedStatuses = [
            'Pending', 'Confirmed', 'Ready for Pickup', 'Completed', 'Cancelled',
        ];
        if ($status !== '' && !in_array($status, $allowedStatuses, true)) {
            respond(['error' => 'Invalid order status filter'], 422);
        }
        $sql = 'SELECT id,client_order_id,farmer_id,farmer_name,market_id,total,'
            . 'status,source,pickup_slot_id,pickup_time,created_at '
            . 'FROM orders WHERE customer_id=:customer_id';
        $params = [':customer_id' => $claims['sub']];
        if ($status !== '') {
            $sql .= ' AND status=:status';
            $params[':status'] = $status;
        }
        $sql .= ' ORDER BY created_at DESC LIMIT 100';
        $statement = database()->prepare($sql);
        $statement->execute($params);
        $orders = $statement->fetchAll();
        foreach ($orders as &$order) {
            $order['id'] = (string) $order['id'];
            $order['total'] = (float) $order['total'];
        }
        unset($order);
        respond(['data' => $orders]);
    }

    if (preg_match('#^/api/orders/([^/]+)(?:/cancel)?$#', $path, $matches)) {
        $claims = requireCustomerUser();
        $orderId = $matches[1];
        $isCancel = str_ends_with($path, '/cancel');
        if ($isCancel && $method === 'PATCH') {
            $pdo = database();
            $pdo->beginTransaction();
            try {
                $statement = $pdo->prepare(
                    'SELECT status,pickup_slot_id FROM orders '
                    . 'WHERE id=:id AND customer_id=:customer_id FOR UPDATE'
                );
                $statement->execute([
                    ':id' => $orderId,
                    ':customer_id' => $claims['sub'],
                ]);
                $order = $statement->fetch();
                if (!$order) {
                    $pdo->rollBack();
                    respond(['error' => 'Order not found'], 404);
                }
                if ($order['status'] !== 'Pending') {
                    $pdo->rollBack();
                    respond(['error' => 'Only pending orders can be cancelled'], 422);
                }
                $update = $pdo->prepare(
                    "UPDATE orders SET status='Cancelled',updated_at=NOW() "
                    . 'WHERE id=:id AND customer_id=:customer_id'
                );
                $update->execute([
                    ':id' => $orderId,
                    ':customer_id' => $claims['sub'],
                ]);
                if (!empty($order['pickup_slot_id'])) {
                    $slot = $pdo->prepare(
                        'UPDATE pickup_slots SET booked_count=GREATEST(booked_count-1,0) '
                        . 'WHERE id=:slot_id'
                    );
                    $slot->execute([':slot_id' => $order['pickup_slot_id']]);
                }
                $pdo->commit();
                respond(['ok' => true]);
            } catch (Throwable $error) {
                if ($pdo->inTransaction()) {
                    $pdo->rollBack();
                }
                throw $error;
            }
        }
        if ($isCancel || $method !== 'GET') {
            respond(['error' => 'Method not allowed'], 405);
        }

        $pdo = database();
        $statement = $pdo->prepare(
            'SELECT id,client_order_id,farmer_id,farmer_name,market_id,total,status,'
            . 'source,pickup_slot_id,pickup_time,created_at '
            . 'FROM orders WHERE id=:id AND customer_id=:customer_id LIMIT 1'
        );
        $statement->execute([
            ':id' => $orderId,
            ':customer_id' => $claims['sub'],
        ]);
        $order = $statement->fetch();
        if (!$order) {
            respond(['error' => 'Order not found'], 404);
        }
        $itemStatement = $pdo->prepare(
            'SELECT oi.id,oi.product_id,oi.name,oi.price,oi.unit,oi.quantity,oi.image_url '
            . 'FROM order_items oi WHERE oi.order_id=:order_id ORDER BY oi.id'
        );
        $itemStatement->execute([':order_id' => $orderId]);
        $order['items'] = $itemStatement->fetchAll();
        $reviewStatement = $pdo->prepare(
            'SELECT EXISTS(SELECT 1 FROM reviews '
            . 'WHERE order_id=:review_order_id AND user_id=:review_user_id) '
            . 'AS has_review'
        );
        $reviewStatement->execute([
            ':review_order_id' => $orderId,
            ':review_user_id' => $claims['sub'],
        ]);
        $order['id'] = (string) $order['id'];
        $order['total'] = (float) $order['total'];
        $order['has_review'] = (bool) $reviewStatement->fetchColumn();
        foreach ($order['items'] as &$item) {
            $item['price'] = (float) $item['price'];
            $item['quantity'] = (int) $item['quantity'];
        }
        unset($item);
        respond(['data' => $order]);
    }

    if ($path === '/api/reviews' && $method === 'POST') {
        $claims = requireCustomerUser();
        $body = requestBody();
        $orderId = trim((string) ($body['order_id'] ?? ''));
        $productId = trim((string) ($body['product_id'] ?? ''));
        $farmerId = trim((string) ($body['farmer_id'] ?? ''));
        $rating = filter_var($body['rating'] ?? null, FILTER_VALIDATE_INT);
        $comment = trim((string) ($body['comment'] ?? ''));
        if ($orderId === '' || $productId === '' || $farmerId === '' ||
            $rating === false || $rating < 1 || $rating > 5 ||
            mb_strlen($comment) > 2000) {
            respond(['error' => 'Invalid review fields'], 422);
        }
        $pdo = database();
        $orderStatement = $pdo->prepare(
            "SELECT o.status,o.farmer_id,oi.product_id "
            . 'FROM orders o JOIN order_items oi ON oi.order_id=o.id '
            . 'WHERE o.id=:order_id AND o.customer_id=:customer_id '
            . 'AND oi.product_id=:product_id LIMIT 1'
        );
        $orderStatement->execute([
            ':order_id' => $orderId,
            ':customer_id' => $claims['sub'],
            ':product_id' => $productId,
        ]);
        $order = $orderStatement->fetch();
        if (!$order || $order['farmer_id'] !== $farmerId) {
            respond(['error' => 'Review item not found in your order'], 404);
        }
        if ($order['status'] !== 'Completed') {
            respond(['error' => 'Only completed orders can be reviewed'], 422);
        }
        $duplicate = $pdo->prepare(
            'SELECT id FROM reviews WHERE order_id=:order_id AND product_id=:product_id '
            . 'AND user_id=:user_id LIMIT 1'
        );
        $duplicate->execute([
            ':order_id' => $orderId,
            ':product_id' => $productId,
            ':user_id' => $claims['sub'],
        ]);
        if ($duplicate->fetchColumn()) {
            respond(['error' => 'This order item has already been reviewed'], 409);
        }
        $userStatement = $pdo->prepare(
            'SELECT full_name FROM users WHERE uid=:uid LIMIT 1'
        );
        $userStatement->execute([':uid' => $claims['sub']]);
        $userName = (string) ($userStatement->fetchColumn() ?: '');
        $pdo->beginTransaction();
        try {
            $insert = $pdo->prepare(
                'INSERT INTO reviews (id,order_id,user_id,user_name,farmer_id,'
                . 'product_id,rating,comment,created_at) '
                . 'VALUES (:id,:order_id,:user_id,:user_name,:farmer_id,'
                . ':product_id,:rating,:comment,NOW())'
            );
            $insert->execute([
                ':id' => bin2hex(random_bytes(20)),
                ':order_id' => $orderId,
                ':user_id' => $claims['sub'],
                ':user_name' => $userName,
                ':farmer_id' => $farmerId,
                ':product_id' => $productId,
                ':rating' => $rating,
                ':comment' => $comment === '' ? null : $comment,
            ]);
            $recalculate = $pdo->prepare(
                'UPDATE farmers SET rating=('
                . 'SELECT COALESCE(AVG(rating),0) FROM reviews WHERE farmer_id=:review_farmer'
                . '),rating_count=('
                . 'SELECT COUNT(*) FROM reviews WHERE farmer_id=:count_farmer'
                . ') WHERE id=:farmer_id'
            );
            $recalculate->execute([
                ':review_farmer' => $farmerId,
                ':count_farmer' => $farmerId,
                ':farmer_id' => $farmerId,
            ]);
            $pdo->commit();
        } catch (PDOException $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            if ($error->getCode() === '23000') {
                respond(['error' => 'This order item has already been reviewed'], 409);
            }
            throw $error;
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
        respond(['ok' => true], 201);
    }

    if ($path === '/api/wishlist') {
        $claims = requireCustomerUser();
        $pdo = database();
        if ($method === 'GET') {
            $statement = $pdo->prepare(
                'SELECT p.id,p.name,p.description,p.price,p.unit,p.stock,p.category_id,'
                . 'p.image_url,p.farmer_id,p.farmer_name,p.market_name,p.is_active,'
                . 'p.sold_count,p.created_at FROM customer_wishlist w '
                . 'JOIN products p ON p.id=w.product_id '
                . 'WHERE w.user_id=:user_id AND p.is_active=1 AND p.is_hidden=0 '
                . 'AND p.deleted_at IS NULL ORDER BY w.created_at DESC'
            );
            $statement->execute([':user_id' => $claims['sub']]);
            $products = $statement->fetchAll();
            foreach ($products as &$product) {
                $product['price'] = (float) $product['price'];
                $product['stock'] = (int) $product['stock'];
                $product['is_active'] = (int) $product['is_active'];
                $product['sold_count'] = (int) $product['sold_count'];
            }
            unset($product);
            respond(['data' => $products]);
        }
        if ($method === 'POST') {
            $productId = trim((string) (requestBody()['product_id'] ?? ''));
            if ($productId === '') {
                respond(['error' => 'product_id is required'], 422);
            }
            $product = $pdo->prepare(
                'SELECT id FROM products WHERE id=:id AND is_active=1 '
                . 'AND is_hidden=0 AND deleted_at IS NULL LIMIT 1'
            );
            $product->execute([':id' => $productId]);
            if (!$product->fetchColumn()) {
                respond(['error' => 'Product not found'], 404);
            }
            $insert = $pdo->prepare(
                'INSERT IGNORE INTO customer_wishlist (user_id,product_id) '
                . 'VALUES (:user_id,:product_id)'
            );
            $insert->execute([
                ':user_id' => $claims['sub'],
                ':product_id' => $productId,
            ]);
            respond(['ok' => true], 201);
        }
        if ($method === 'DELETE') {
            $productId = trim((string) ($_GET['product_id'] ?? ''));
            if ($productId === '') {
                respond(['error' => 'product_id is required'], 422);
            }
            $delete = $pdo->prepare(
                'DELETE FROM customer_wishlist WHERE user_id=:user_id AND product_id=:product_id'
            );
            $delete->execute([
                ':user_id' => $claims['sub'],
                ':product_id' => $productId,
            ]);
            respond(['ok' => true]);
        }
        respond(['error' => 'Method not allowed'], 405);
    }

    if (preg_match('#^/api/farmers/([^/]+)$#', $path, $matches) &&
        $method === 'GET') {
        $claims = requireCustomerUser();
        $farmerId = $matches[1];
        $pdo = database();
        $statement = $pdo->prepare(
            "SELECT id,farm_name,market_name,address,description,avatar_url,rating,"
            . 'rating_count,follower_count,EXISTS(SELECT 1 FROM farmer_followers ff '
            . 'WHERE ff.farmer_id=farmers.id AND ff.user_id=:user_id) AS is_following '
            . "FROM farmers WHERE id=:farmer_id AND status='approved' "
            . 'AND is_locked=0 AND deleted_at IS NULL LIMIT 1'
        );
        $statement->execute([
            ':user_id' => $claims['sub'],
            ':farmer_id' => $farmerId,
        ]);
        $farmer = $statement->fetch();
        if (!$farmer) {
            respond(['error' => 'Farmer not found'], 404);
        }
        $reviews = $pdo->prepare(
            'SELECT r.user_name,r.rating,r.comment,r.created_at,p.name AS product_name '
            . 'FROM reviews r LEFT JOIN products p ON p.id=r.product_id '
            . 'WHERE r.farmer_id=:farmer_id ORDER BY r.created_at DESC LIMIT 100'
        );
        $reviews->execute([':farmer_id' => $farmerId]);
        $farmer['rating'] = (float) $farmer['rating'];
        $farmer['rating_count'] = (int) $farmer['rating_count'];
        $farmer['follower_count'] = (int) $farmer['follower_count'];
        $farmer['is_following'] = (bool) $farmer['is_following'];
        $farmer['reviews'] = $reviews->fetchAll();
        foreach ($farmer['reviews'] as &$review) {
            $review['rating'] = (int) $review['rating'];
        }
        unset($review);
        respond(['data' => $farmer]);
    }

    if ($path === '/api/customer/notifications/read-all' && $method === 'PATCH') {
        $claims = requireCustomerUser();
        $statement = database()->prepare(
            'UPDATE notifications SET is_read=1 WHERE user_id=:user_id AND is_read=0'
        );
        $statement->execute([':user_id' => $claims['sub']]);
        respond(['ok' => true, 'updated' => $statement->rowCount()]);
    }

    if ($method === 'POST' && $path === '/api/chatbot/message') {
        $claims = requireCustomerUser();
        $body = requestBody();
        $message = trim((string) ($body['message'] ?? ''));
        if ($message === '' || mb_strlen($message) > 2000) {
            respond(['error' => 'Message must contain 1 to 2000 characters'], 422);
        }
        $apiUrl = rtrim($_ENV['AI_API_URL'] ?? '', '/');
        $apiKey = $_ENV['AI_API_KEY'] ?? '';
        $model = $_ENV['AI_MODEL'] ?? 'gemini-2.0-flash';
        if ($apiUrl === '' || $apiKey === '' || str_starts_with($apiKey, 'replace-')) {
            respond(['error' => 'AI service is not configured'], 503);
        }
        $pdo = database();
        $context = [
            'products' => $pdo->query(
                'SELECT name,price,unit,stock,farmer_name,market_name '
                . 'FROM products WHERE is_active=1 AND is_hidden=0 '
                . 'AND deleted_at IS NULL ORDER BY updated_at DESC LIMIT 100'
            )->fetchAll(),
            'farmers' => $pdo->query(
                "SELECT farm_name,market_name,address,rating,rating_count FROM farmers "
                . "WHERE status='approved' AND is_locked=0 AND deleted_at IS NULL "
                . 'ORDER BY farm_name LIMIT 50'
            )->fetchAll(),
            'markets' => $pdo->query(
                'SELECT name,address,open_hours FROM farmers_market '
                . 'WHERE is_active=1 AND deleted_at IS NULL ORDER BY name LIMIT 50'
            )->fetchAll(),
            'pickup_slots' => $pdo->query(
                'SELECT f.farm_name,ps.start_time,ps.end_time '
                . 'FROM pickup_slots ps JOIN farmers f ON f.id=ps.farmer_id '
                . 'WHERE ps.is_open=1 AND ps.capacity>ps.booked_count '
                . 'AND ps.start_time>NOW() AND f.status=\'approved\' '
                . 'AND f.is_locked=0 AND f.deleted_at IS NULL '
                . 'ORDER BY ps.start_time LIMIT 100'
            )->fetchAll(),
        ];
        $language = ($body['language'] ?? 'vi') === 'en' ? 'English' : 'Vietnamese';
        $prompt = 'You are the HarvestHub assistant. Answer in ' . $language . '. '
            . 'Use only the supplied current database context for product, stock, '
            . 'price, market, farmer, or pickup time facts. If a fact is absent, say so; '
            . 'never invent it. Do not reveal private data for another user. '
            . 'Keep the response concise. DATABASE_CONTEXT='
            . json_encode($context, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)
            . "\nCUSTOMER_QUESTION:\n" . $message;
        $payload = json_encode([
            'contents' => [['parts' => [['text' => $prompt]]]],
        ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        $handle = curl_init(
            $apiUrl . '/models/' . rawurlencode($model)
            . ':generateContent?key=' . rawurlencode($apiKey)
        );
        curl_setopt_array($handle, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $payload,
            CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 30,
        ]);
        try {
            $response = curl_exec($handle);
            $status = curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
            $decoded = is_string($response) ? json_decode($response, true) : null;
            $answer = $decoded['candidates'][0]['content']['parts'][0]['text'] ?? null;
            if ($response === false || $status < 200 || $status >= 300 ||
                !is_string($answer) || trim($answer) === '') {
                error_log(sprintf(
                    'Chatbot request failed: http_status=%d curl_error=%s',
                    $status,
                    curl_error($handle) ?: 'none'
                ));
                respond(['error' => 'AI service request failed'], 502);
            }
            respond(['answer' => trim($answer)]);
        } finally {
            curl_close($handle);
        }
    }

    if ($method === 'POST' && $path === '/api/faq/ask') {
        $body = requestBody();
        $question = trim((string) ($body['question'] ?? ''));
        $language = ($body['language'] ?? 'vi') === 'en' ? 'English' : 'Vietnamese';
        $apiUrl = rtrim($_ENV['AI_API_URL'] ?? '', '/');
        $apiKey = $_ENV['AI_API_KEY'] ?? '';
        $model = $_ENV['AI_MODEL'] ?? 'gemini-2.0-flash';

        if ($question === '') {
            respond(['error' => 'Question is required'], 422);
        }
        if ($apiUrl === '' || $apiKey === '' || str_starts_with($apiKey, 'replace-')) {
            respond(['error' => 'AI service is not configured'], 503);
        }

        $payload = json_encode([
            'contents' => [[
                'parts' => [[
                    'text' => 'You are the HarvestHub FAQ assistant. Only answer questions about buying produce, selling produce, accounts, orders, and using the app. If you do not know, say that the user should contact support. Answer briefly in ' . $language . '.\n\nQuestion: ' . $question,
                ]],
            ]],
        ]);
        $handle = curl_init(
            $apiUrl . '/models/' . rawurlencode($model) . ':generateContent?key=' . rawurlencode($apiKey)
        );
        curl_setopt_array($handle, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $payload,
            CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 30,
        ]);

        try {
            $response = curl_exec($handle);
            $status = curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
            $decoded = is_string($response) ? json_decode($response, true) : null;
            $answer = $decoded['candidates'][0]['content']['parts'][0]['text'] ?? null;
            if ($response === false || $status < 200 || $status >= 300 || !is_string($answer)) {
                respond(['error' => 'AI service request failed'], 502);
            }
            respond(['answer' => trim($answer)]);
        } finally {
            curl_close($handle);
        }
    }

    if ($method === 'GET' && $path === '/api/nearby-markets') {
        $latitude = filter_var($_GET['latitude'] ?? null, FILTER_VALIDATE_FLOAT);
        $longitude = filter_var($_GET['longitude'] ?? null, FILTER_VALIDATE_FLOAT);
        $radius = filter_var($_GET['radius'] ?? 10000, FILTER_VALIDATE_INT);
        if ($latitude === false || $longitude === false || $radius === false ||
            $latitude < -90 || $latitude > 90 || $longitude < -180 || $longitude > 180) {
            respond(['error' => 'Invalid location parameters'], 422);
        }

        $radius = max(1000, min($radius, 50000));
        $distanceExpression = '6371 * ACOS(LEAST(1, GREATEST(-1, '
            . 'COS(RADIANS(:latitude1)) * COS(RADIANS(latitude)) * '
            . 'COS(RADIANS(longitude) - RADIANS(:longitude)) + '
            . 'SIN(RADIANS(:latitude2)) * SIN(RADIANS(latitude)))))';
        $query = "SELECT id, name, address, latitude, longitude, distance_km FROM ("
            . "SELECT id, name, address, latitude, longitude, $distanceExpression AS distance_km "
            . "FROM farmers_market WHERE is_active = 1 AND deleted_at IS NULL "
            . "AND latitude IS NOT NULL AND longitude IS NOT NULL"
            . ") AS nearby WHERE distance_km <= :radius ORDER BY distance_km LIMIT 100";
        $statement = database()->prepare($query);
        $statement->execute([
            ':latitude1' => $latitude,
            ':longitude' => $longitude,
            ':latitude2' => $latitude,
            ':radius' => $radius / 1000,
        ]);
        respond(['data' => $statement->fetchAll(), 'source' => 'mysql']);
    }

    if ($method === 'GET' && $path === '/api/farmers_market') {
        $statement = database()->query(
            'SELECT id, name, address FROM farmers_market '
            . 'WHERE is_active = 1 AND deleted_at IS NULL '
            . 'ORDER BY name ASC'
        );
        respond($statement->fetchAll());
    }

    if ($path === '/api/customer/following' && $method === 'GET') {
        $claims = requireCustomerUser();
        $statement = database()->prepare(
            "SELECT f.id,f.farm_name,f.market_name,f.address,f.description,"
            . "f.avatar_url,f.rating,f.rating_count,f.follower_count "
            . "FROM farmer_followers ff JOIN farmers f ON f.id=ff.farmer_id "
            . "WHERE ff.user_id=:user_id AND f.status='approved' "
            . "AND f.is_locked=0 AND f.deleted_at IS NULL "
            . 'ORDER BY ff.followed_at DESC'
        );
        $statement->execute([':user_id' => $claims['sub']]);
        respond(['data' => $statement->fetchAll()]);
    }

    if (preg_match('#^/api/farmers/([^/]+)/follow$#', $path, $matches)) {
        if (!in_array($method, ['GET', 'POST', 'DELETE'], true)) {
            respond(['error' => 'Method not allowed'], 405);
        }
        $claims = requireCustomerUser();
        $farmerId = $matches[1];
        $pdo = database();
        $farmerStatement = $pdo->prepare(
            "SELECT id FROM farmers WHERE id=:id AND status='approved' "
            . 'AND is_locked=0 AND deleted_at IS NULL LIMIT 1'
        );
        $farmerStatement->execute([':id' => $farmerId]);
        if (!$farmerStatement->fetchColumn()) {
            respond(['error' => 'Farmer not found'], 404);
        }

        if ($method === 'GET') {
            $statement = $pdo->prepare(
                'SELECT EXISTS(SELECT 1 FROM farmer_followers '
                . 'WHERE farmer_id=:farmer_id AND user_id=:user_id)'
            );
            $statement->execute([
                ':farmer_id' => $farmerId,
                ':user_id' => $claims['sub'],
            ]);
            $following = (bool) $statement->fetchColumn();
            $count = $pdo->prepare('SELECT follower_count FROM farmers WHERE id=:id');
            $count->execute([':id' => $farmerId]);
            respond([
                'following' => $following,
                'follower_count' => (int) $count->fetchColumn(),
            ]);
        }

        $pdo->beginTransaction();
        try {
            if ($method === 'POST') {
                $statement = $pdo->prepare(
                    'INSERT IGNORE INTO farmer_followers (farmer_id,user_id,followed_at) '
                    . 'VALUES (:farmer_id,:user_id,NOW())'
                );
                $statement->execute([
                    ':farmer_id' => $farmerId,
                    ':user_id' => $claims['sub'],
                ]);
                if ($statement->rowCount() > 0) {
                    $update = $pdo->prepare(
                        'UPDATE farmers SET follower_count=follower_count+1 WHERE id=:id'
                    );
                    $update->execute([':id' => $farmerId]);
                }
            } else {
                $statement = $pdo->prepare(
                    'DELETE FROM farmer_followers WHERE farmer_id=:farmer_id AND user_id=:user_id'
                );
                $statement->execute([
                    ':farmer_id' => $farmerId,
                    ':user_id' => $claims['sub'],
                ]);
                if ($statement->rowCount() > 0) {
                    $update = $pdo->prepare(
                        'UPDATE farmers SET follower_count=GREATEST(follower_count-1,0) '
                        . 'WHERE id=:id'
                    );
                    $update->execute([':id' => $farmerId]);
                }
            }
            $count = $pdo->prepare('SELECT follower_count FROM farmers WHERE id=:id');
            $count->execute([':id' => $farmerId]);
            $followerCount = (int) $count->fetchColumn();
            $pdo->commit();
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
        respond([
            'ok' => true,
            'following' => $method === 'POST',
            'follower_count' => $followerCount,
        ], $method === 'POST' ? 201 : 200);
    }

    if ($path === '/api/customer/notifications') {
        $claims = requireCustomerUser();
        if ($method === 'GET') {
            $statement = database()->prepare(
                'SELECT id,type,title,body,order_id,product_id,is_read,created_at FROM notifications '
                . 'WHERE user_id=:user_id ORDER BY created_at DESC LIMIT 100'
            );
            $statement->execute([':user_id' => $claims['sub']]);
            $notifications = $statement->fetchAll();
            foreach ($notifications as &$notification) {
                $notification['is_read'] = (int) $notification['is_read'];
            }
            unset($notification);
            respond(['data' => $notifications]);
        }
        if ($method === 'PATCH') {
            $notificationId = trim((string) (requestBody()['id'] ?? ''));
            if ($notificationId === '') {
                respond(['error' => 'Notification id is required'], 422);
            }
            $pdo = database();
            $update = $pdo->prepare(
                'UPDATE notifications SET is_read=1 WHERE id=:id AND user_id=:user_id'
            );
            $update->execute([
                ':id' => $notificationId,
                ':user_id' => $claims['sub'],
            ]);
            if ($update->rowCount() === 0) {
                $check = $pdo->prepare(
                    'SELECT id FROM notifications WHERE id=:id AND user_id=:user_id'
                );
                $check->execute([
                    ':id' => $notificationId,
                    ':user_id' => $claims['sub'],
                ]);
                if (!$check->fetchColumn()) {
                    respond(['error' => 'Notification not found'], 404);
                }
            }
            respond(['ok' => true]);
        }
        respond(['error' => 'Method not allowed'], 405);
    }

    if ($method === 'GET' && $path === '/api/route') {
        $coordinates = [];
        foreach (['from_lat', 'from_lng', 'to_lat', 'to_lng'] as $parameter) {
            $value = filter_var($_GET[$parameter] ?? null, FILTER_VALIDATE_FLOAT);
            if ($value === false || !is_finite((float) $value)) {
                respond(['error' => "Invalid $parameter"], 422);
            }
            $coordinates[$parameter] = (float) $value;
        }
        if ($coordinates['from_lat'] < -90 || $coordinates['from_lat'] > 90 ||
            $coordinates['to_lat'] < -90 || $coordinates['to_lat'] > 90 ||
            $coordinates['from_lng'] < -180 || $coordinates['from_lng'] > 180 ||
            $coordinates['to_lng'] < -180 || $coordinates['to_lng'] > 180) {
            respond(['error' => 'Coordinates are outside valid bounds'], 422);
        }

        $baseUrl = rtrim($_ENV['OSRM_BASE_URL'] ?? 'http://127.0.0.1:5000', '/');
        $origin = number_format($coordinates['from_lng'], 7, '.', '') . ',' .
            number_format($coordinates['from_lat'], 7, '.', '');
        $destination = number_format($coordinates['to_lng'], 7, '.', '') . ',' .
            number_format($coordinates['to_lat'], 7, '.', '');
        $url = "$baseUrl/route/v1/driving/$origin;$destination"
            . '?overview=full&geometries=geojson&steps=false';
        $handle = curl_init($url);
        curl_setopt_array($handle, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_TIMEOUT => 30,
            CURLOPT_HTTPHEADER => ['Accept: application/json'],
        ]);

        try {
            $response = curl_exec($handle);
            $status = curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
            $payload = is_string($response) ? json_decode($response, true) : null;
            if ($response === false || $status < 200 || $status >= 300 ||
                !is_array($payload)) {
                $osrmCode = is_array($payload) && is_string($payload['code'] ?? null)
                    ? $payload['code']
                    : 'invalid_json';
                error_log(sprintf(
                    'OSRM route request failed: http_status=%d curl_error=%s osrm_code=%s',
                    $status,
                    curl_error($handle) ?: 'none',
                    $osrmCode
                ));
                respond(['error' => 'Routing service request failed'], 502);
            }
            if (($payload['code'] ?? null) !== 'Ok' ||
                !isset($payload['routes'][0]['geometry']['coordinates'])) {
                respond(['error' => 'No route found for these coordinates'], 404);
            }

            respond($payload);
        } finally {
            curl_close($handle);
        }
    }

    if ($method === 'GET' && $path === '/api/products') {
        $sql = 'SELECT id,name,description,price,unit,stock,category_id,image_url,'
            . 'farmer_id,farmer_name,market_name,is_active,sold_count,created_at '
            . 'FROM products WHERE is_active=1 AND is_hidden=0 AND deleted_at IS NULL';
        $params = [];
        if (isset($_GET['farmer']) && trim((string) $_GET['farmer']) !== '') {
            $sql .= ' AND farmer_id=:farmer_id';
            $params[':farmer_id'] = trim((string) $_GET['farmer']);
        }
        $sql .= ' ORDER BY created_at DESC LIMIT 200';
        $statement = database()->prepare($sql);
        $statement->execute($params);
        $products = $statement->fetchAll();
        foreach ($products as &$product) {
            $product['price'] = (float) $product['price'];
            $product['stock'] = (int) $product['stock'];
            $product['is_active'] = (int) $product['is_active'];
            $product['sold_count'] = (int) $product['sold_count'];
        }
        unset($product);
        respond(['data' => $products]);
    }

    $publicRoutes = [
        '/api/categories' => 'SELECT * FROM categories WHERE is_active = 1 AND deleted_at IS NULL ORDER BY display_order',
        '/api/farmers' => "SELECT id,farm_name,market_name,address,description,avatar_url,"
            . "rating,rating_count,follower_count FROM farmers "
            . "WHERE status = 'approved' AND is_locked=0 AND deleted_at IS NULL "
            . "ORDER BY created_at DESC",
        '/api/farmers_market' => 'SELECT * FROM farmers_market WHERE is_active = 1 AND deleted_at IS NULL ORDER BY name',
    ];

    if ($method === 'GET' && isset($publicRoutes[$path])) {
        $statement = database()->query($publicRoutes[$path]);
        respond(['data' => $statement->fetchAll()]);
    }

    respond(['error' => 'Route not found'], 404);
} catch (Throwable $error) {
    error_log($error->getMessage());
    respond(['error' => 'Internal server error'], 500);
}