<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

if (!extension_loaded('curl')) {
    echo json_encode(['ok' => false, 'result' => 'curl-extension-unavailable']);
    exit;
}

$handle = curl_init(
    'https://identitytoolkit.googleapis.com/v1/accounts:lookup'
);
if ($handle === false) {
    echo json_encode(['ok' => false, 'result' => 'curl-init-failed']);
    exit;
}

curl_setopt_array($handle, [
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => '{}',
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
        'result' => 'outbound-request-failed',
        'curl_errno' => $errno,
        'elapsed_ms' => (int) ((microtime(true) - $startedAt) * 1000),
    ]);
    exit;
}

echo json_encode([
    'ok' => true,
    'result' => 'google-endpoint-reachable',
    'http_status' => $status,
    'elapsed_ms' => (int) ((microtime(true) - $startedAt) * 1000),
]);
