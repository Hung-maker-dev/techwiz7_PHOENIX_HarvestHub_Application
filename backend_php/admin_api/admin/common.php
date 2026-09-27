<?php
use PHPMailer\PHPMailer\PHPMailer;

function admin_json($data, int $status = 200): never
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function admin_error(string $message, int $status = 400): never
{
    http_response_code($status);
    echo json_encode(['message' => $message], JSON_UNESCAPED_UNICODE);
    exit;
}

function admin_resolve_path(): array
{
    $queryPath = trim((string) ($_GET['path'] ?? ''), '/');
    if ($queryPath !== '') {
        return $queryPath === '' ? [] : explode('/', $queryPath);
    }

    $requestPath = parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH) ?: '';
    $scriptPath = trim((string) ($_SERVER['SCRIPT_NAME'] ?? ''), '/');
    $requestPath = trim((string) $requestPath, '/');
    $scriptPath = trim((string) $scriptPath, '/');

    if ($scriptPath !== '') {
        $scriptSegments = explode('/', $scriptPath);
        $scriptParent = implode('/', array_slice($scriptSegments, 0, -1));
        $scriptParent = trim($scriptParent, '/');

        if ($scriptParent !== '' && str_starts_with($requestPath, $scriptParent . '/')) {
            $requestPath = substr($requestPath, strlen($scriptParent) + 1);
        } elseif ($scriptParent === '' && $requestPath === $scriptSegments[count($scriptSegments) - 1]) {
            $requestPath = '';
        }
    }

    if ($requestPath === '' || $requestPath === 'index.php') {
        return [];
    }

    $segments = array_values(array_filter(explode('/', $requestPath), static fn($segment) => $segment !== 'index.php' && $segment !== ''));
    return $segments;
}

function admin_body(): array
{
    $raw = file_get_contents('php://input');
    $body = json_decode($raw ?: '{}', true);
    return is_array($body) ? $body : [];
}

function admin_id(string $prefix): string
{
    return $prefix . '-' . bin2hex(random_bytes(8));
}

function admin_bool($value): bool
{
    return (bool) ((int) $value);
}

function admin_date($value): string
{
    return (string) $value;
}

function admin_column_exists(PDO $db, string $table, string $column): bool
{
    static $cache = [];
    $key = $table . '.' . $column;
    if (array_key_exists($key, $cache))
        return $cache[$key];

    $stmt = $db->prepare(
        'SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :table_name AND COLUMN_NAME = :column_name'
    );
    $stmt->execute(['table_name' => $table, 'column_name' => $column]);
    return $cache[$key] = ((int) $stmt->fetchColumn() > 0);
}

function admin_expr(PDO $db, string $table, string $column, string $fallback = 'NULL'): string
{
    return admin_column_exists($db, $table, $column)
        ? '`' . str_replace('`', '', $column) . '`'
        : $fallback;
}

function admin_audit(PDO $db, string $action, string $entityType, string $entityId, ?string $details = null): void
{
    if (!admin_column_exists($db, 'audit_logs', 'id'))
        return;

    $columns = ['id', 'action', 'detail', 'created_at'];
    $values = [':id', ':action', ':detail', 'NOW()'];
    $params = [
        'id' => admin_id('LOG'),
        'action' => $action,
        'detail' => $entityType . '#' . $entityId . ($details !== null ? ' — ' . $details : ''),
    ];

    if (admin_column_exists($db, 'audit_logs', 'actor_id')) {
        $columns[] = 'actor_id';
        $values[] = ':actor_id';
        $params['actor_id'] = $GLOBALS['admin_actor_uid'] ?? null;
    }

    try {
        $stmt = $db->prepare(
            'INSERT INTO audit_logs (' . implode(',', $columns) . ')
             VALUES (' . implode(',', $values) . ')'
        );
        $stmt->execute($params);
    } catch (Throwable $e) {
        error_log('Audit log skipped: ' . $e->getMessage());
    }
}

function admin_send_farmer_approval_email(PDO $db, string $farmerId): bool
{
    $statement = $db->prepare(
        'SELECT u.email, u.full_name, u.preferred_language, f.farm_name '
        . 'FROM farmers f JOIN users u ON u.uid = COALESCE(f.user_uid, f.id) '
        . 'WHERE f.id = :id LIMIT 1'
    );
    $statement->execute(['id' => $farmerId]);
    $application = $statement->fetch();
    if (!$application || !filter_var($application['email'], FILTER_VALIDATE_EMAIL)) {
        return false;
    }

    $host = trim((string) ($_ENV['SMTP_HOST'] ?? ''));
    $username = trim((string) ($_ENV['SMTP_USERNAME'] ?? ''));
    $password = (string) ($_ENV['SMTP_PASSWORD'] ?? '');
    $fromEmail = trim((string) ($_ENV['SMTP_FROM_EMAIL'] ?? $username));
    if ($host === '' || $username === '' || $password === '' || $fromEmail === '') {
        throw new RuntimeException('Farmer approval SMTP settings are incomplete.');
    }

    $english = ($application['preferred_language'] ?? 'vi') === 'en';
    $farmName = htmlspecialchars(
        (string) $application['farm_name'],
        ENT_QUOTES | ENT_SUBSTITUTE,
        'UTF-8'
    );
    $name = htmlspecialchars(
        (string) $application['full_name'],
        ENT_QUOTES | ENT_SUBSTITUTE,
        'UTF-8'
    );
    $mail = new PHPMailer(true);
    $mail->isSMTP();
    $mail->Host = $host;
    $mail->SMTPAuth = true;
    $mail->Username = $username;
    $mail->Password = $password;
    $mail->Port = (int) ($_ENV['SMTP_PORT'] ?? 587);
    $encryption = strtolower((string) ($_ENV['SMTP_ENCRYPTION'] ?? 'tls'));
    if ($encryption === 'ssl') {
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS;
    } elseif ($encryption === 'tls') {
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
    } else {
        throw new RuntimeException('SMTP_ENCRYPTION must be tls or ssl.');
    }
    $mail->CharSet = PHPMailer::CHARSET_UTF8;
    $mail->setFrom($fromEmail, (string) ($_ENV['SMTP_FROM_NAME'] ?? 'HarvestHub'));
    $mail->addAddress(
        (string) $application['email'],
        (string) $application['full_name']
    );
    $mail->isHTML(true);
    $mail->Subject = $english
        ? 'Your HarvestHub farmer application was approved'
        : 'Hồ sơ người bán HarvestHub của bạn đã được duyệt';
    $mail->Body = $english
        ? "<p>Hello {$name},</p><p>Your farm application for <strong>{$farmName}</strong> has been approved. Farmer features are now available in HarvestHub.</p>"
        : "<p>Xin chào {$name},</p><p>Hồ sơ đăng ký bán hàng cho trang trại <strong>{$farmName}</strong> đã được duyệt. Bạn đã có thể sử dụng các chức năng dành cho người bán trên HarvestHub.</p>";
    $mail->AltBody = $english
        ? "Hello {$application['full_name']}, your farmer application for {$application['farm_name']} has been approved."
        : "Xin chào {$application['full_name']}, hồ sơ bán hàng cho trang trại {$application['farm_name']} đã được duyệt.";
    $mail->send();
    return true;
}
