<?php

declare(strict_types=1);

require dirname(__DIR__) . '/vendor/autoload.php';

use Dotenv\Dotenv;

$root = dirname(__DIR__);
Dotenv::createImmutable($root)->safeLoad();

function logSyncError(string $message): never
{
    fwrite(STDERR, $message . PHP_EOL);
    exit(1);
}

try {
    $query = <<<'OVERPASS'
[out:json][timeout:60];
area["ISO3166-1"="VN"][admin_level=2]->.vn;
(
  node["shop"="marketplace"](area.vn);
  way["shop"="marketplace"](area.vn);
  node["amenity"="marketplace"](area.vn);
  way["amenity"="marketplace"](area.vn);
);
out center tags;
OVERPASS;

    $overpassUrl = $_ENV['OVERPASS_URL'] ?? 'https://overpass-api.de/api/interpreter';
    $handle = curl_init($overpassUrl);
    curl_setopt_array($handle, [
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => http_build_query(['data' => $query]),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 15,
        CURLOPT_TIMEOUT => 90,
        CURLOPT_HTTPHEADER => ['Accept: application/json'],
    ]);

    try {
        $response = curl_exec($handle);
        $status = curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        if ($response === false || $status < 200 || $status >= 300) {
            logSyncError(
                'Overpass request failed (HTTP ' . $status . '): ' . curl_error($handle)
            );
        }
    } finally {
        curl_close($handle);
    }

    $payload = json_decode($response, true, 512, JSON_THROW_ON_ERROR);
    $elements = $payload['elements'] ?? null;
    if (!is_array($elements)) {
        logSyncError('Overpass response does not contain a valid elements list.');
    }

    $dsn = sprintf(
        'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
        $_ENV['DB_HOST'] ?? '127.0.0.1',
        $_ENV['DB_PORT'] ?? '3306',
        $_ENV['DB_NAME'] ?? 'harvesthub'
    );
    $pdo = new PDO($dsn, $_ENV['DB_USER'] ?? 'root', $_ENV['DB_PASSWORD'] ?? '', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
    $statement = $pdo->prepare(
        'INSERT INTO farmers_market '
        . '(id, name, address, latitude, longitude, open_hours, is_active) '
        . 'VALUES (:id, :name, :address, :latitude, :longitude, :open_hours, 1) '
        . 'ON DUPLICATE KEY UPDATE '
        . 'name = VALUES(name), address = VALUES(address), '
        . 'latitude = VALUES(latitude), longitude = VALUES(longitude), '
        . 'open_hours = VALUES(open_hours), is_active = 1'
    );

    $pdo->beginTransaction();
    $synced = 0;
    foreach ($elements as $element) {
        $tags = $element['tags'] ?? [];
        if (!is_array($tags)) {
            $tags = [];
        }
        $latitude = $element['lat'] ?? $element['center']['lat'] ?? null;
        $longitude = $element['lon'] ?? $element['center']['lon'] ?? null;
        if (!isset($element['type'], $element['id']) ||
            !is_numeric($latitude) || !is_numeric($longitude) ||
            $latitude < -90 || $latitude > 90 ||
            $longitude < -180 || $longitude > 180) {
            continue;
        }

        $address = $tags['addr:full'] ?? trim(implode(', ', array_filter([
            $tags['addr:street'] ?? null,
            $tags['addr:city'] ?? null,
        ])));
        $statement->execute([
            ':id' => 'osm_' . $element['type'] . '_' . $element['id'],
            ':name' => $tags['name'] ?? 'Chợ không tên',
            ':address' => $address !== '' ? $address : 'OpenStreetMap',
            ':latitude' => $latitude,
            ':longitude' => $longitude,
            ':open_hours' => $tags['opening_hours'] ?? null,
        ]);
        $synced++;
    }
    $pdo->commit();

    fwrite(STDOUT, "Synchronized $synced market records." . PHP_EOL);
} catch (Throwable $error) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    logSyncError('Market sync failed: ' . $error->getMessage());
}
