<?php

declare(strict_types=1);

function database(): PDO
{
    static $pdo = null;

    if ($pdo instanceof PDO) {
        return $pdo;
    }

    // Ưu tiên cấu hình local (không upload lên hosting, không commit git)
    $localFile = __DIR__ . '/database.local.php';

    if (is_file($localFile)) {
        $cfg = require $localFile;
    } else {
        // Production (InfinityFree): điền mật khẩu thật trực tiếp trên server
        $cfg = [
            'host' => 'sql302.infinityfree.com',
            'port' => 3306,
            'db'   => 'if0_43024476_harvesthub',
            'user' => 'if0_43024476',
            'pass' => 'FyE1wNwlziWMx',
        ];
    }

    foreach (['host', 'port', 'db', 'user', 'pass'] as $key) {
        if (!is_array($cfg) || !array_key_exists($key, $cfg)) {
            throw new RuntimeException("Thiếu cấu hình database: {$key}");
        }
    }

    $dsn = sprintf(
        'mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
        $cfg['host'],
        (int) $cfg['port'],
        $cfg['db']
    );

    $pdo = new PDO($dsn, $cfg['user'], $cfg['pass'], [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
        PDO::ATTR_TIMEOUT            => 5,
    ]);

    return $pdo;
}