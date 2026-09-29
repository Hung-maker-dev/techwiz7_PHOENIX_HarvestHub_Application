<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

$private = __DIR__ . '/_private';
$autoload = $private . '/vendor/autoload.php';
$envFile = $private . '/.env';

if (!is_file($autoload) || !is_readable($envFile)) {
    echo json_encode(['ok' => false, 'result' => 'backend-config-unavailable']);
    exit;
}

try {
    require $autoload;
    \Dotenv\Dotenv::createImmutable($private)->safeLoad();
} catch (Throwable) {
    echo json_encode(['ok' => false, 'result' => 'backend-config-unavailable']);
    exit;
}

$apiKey = $_ENV['FIREBASE_WEB_API_KEY'] ?? '';
if (!is_string($apiKey) || trim($apiKey) === '') {
    echo json_encode(['ok' => false, 'result' => 'firebase-api-key-missing']);
    exit;
}

if (!extension_loaded('curl')) {
    echo json_encode(['ok' => false, 'result' => 'curl-extension-unavailable']);
    exit;
}

$handle = curl_init(
    'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key='
        . rawurlencode($apiKey)
);
if ($handle === false) {
    echo json_encode(['ok' => false, 'result' => 'curl-init-failed']);
    exit;
}

curl_setopt_array($handle, [
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => json_encode(['idToken' => 'invalid-diagnostic-token']),
    CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_CONNECTTIMEOUT => 5,
    CURLOPT_TIMEOUT => 10,
]);

$startedAt = microtime(true);
$response = curl_exec($handle);
$status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
$errno = curl_errno($handle);
curl_close($handle);

if ($response === false) {
    echo json_encode([
        'ok' => false,
        'result' => 'firebase-request-failed',
        'curl_errno' => $errno,
        'elapsed_ms' => (int) ((microtime(true) - $startedAt) * 1000),
    ]);
    exit;
}

$payload = json_decode($response, true);
$message = is_array($payload) ? ($payload['error']['message'] ?? null) : null;
$firebaseCode = is_string($message) ? explode(':', $message, 2)[0] : null;

echo json_encode([
    'ok' => $status === 400 && $firebaseCode === 'INVALID_ID_TOKEN',
    'result' => $firebaseCode === 'INVALID_ID_TOKEN'
        ? 'firebase-api-key-valid'
        : 'firebase-api-check-failed',
    'http_status' => $status,
    'firebase_code' => $firebaseCode,
    'elapsed_ms' => (int) ((microtime(true) - $startedAt) * 1000),
]);
