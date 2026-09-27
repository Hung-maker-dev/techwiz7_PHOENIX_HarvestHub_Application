<?php

declare(strict_types=1);

function fcmBase64UrlEncode(string $value): string
{
    return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
}

function fcmAccessToken(string $serviceAccountPath, string $projectId): string
{
    static $cachedToken = null;
    static $expiresAt = 0;
    if (is_string($cachedToken) && $expiresAt > time() + 60) {
        return $cachedToken;
    }
    if (!is_readable($serviceAccountPath)) {
        throw new RuntimeException('FCM service account file is not readable');
    }

    $rawCredentials = file_get_contents($serviceAccountPath);
    if (!is_string($rawCredentials)) {
        throw new RuntimeException('FCM service account file could not be read');
    }
    try {
        $credentials = json_decode($rawCredentials, true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException $error) {
        throw new RuntimeException('FCM service account JSON is invalid', 0, $error);
    }
    $clientEmail = $credentials['client_email'] ?? null;
    $privateKey = $credentials['private_key'] ?? null;
    $tokenUri = $credentials['token_uri'] ?? 'https://oauth2.googleapis.com/token';
    $credentialProjectId = $credentials['project_id'] ?? null;
    if (!is_string($clientEmail) || !filter_var($clientEmail, FILTER_VALIDATE_EMAIL) ||
        !is_string($privateKey) || !is_string($tokenUri) ||
        !str_starts_with($tokenUri, 'https://') ||
        !is_string($credentialProjectId) || $credentialProjectId !== $projectId) {
        throw new RuntimeException('FCM service account credentials are incomplete');
    }

    $issuedAt = time();
    $header = fcmBase64UrlEncode(json_encode(
        ['alg' => 'RS256', 'typ' => 'JWT'],
        JSON_THROW_ON_ERROR
    ));
    $claims = fcmBase64UrlEncode(json_encode([
        'iss' => $clientEmail,
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => $tokenUri,
        'iat' => $issuedAt,
        'exp' => $issuedAt + 3600,
    ], JSON_THROW_ON_ERROR));
    $unsignedToken = "$header.$claims";
    $key = openssl_pkey_get_private($privateKey);
    if ($key === false ||
        !openssl_sign($unsignedToken, $signature, $key, OPENSSL_ALGO_SHA256)) {
        throw new RuntimeException('Could not sign FCM service account assertion');
    }

    $assertion = $unsignedToken . '.' . fcmBase64UrlEncode($signature);
    $handle = curl_init($tokenUri);
    if ($handle === false) {
        throw new RuntimeException('Could not initialize Google OAuth request');
    }
    curl_setopt_array($handle, [
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $assertion,
        ]),
        CURLOPT_HTTPHEADER => ['Content-Type: application/x-www-form-urlencoded'],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 5,
        CURLOPT_TIMEOUT => 15,
    ]);
    try {
        $response = curl_exec($handle);
        $status = curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        if (!is_string($response) || $status < 200 || $status >= 300) {
            throw new RuntimeException("Google OAuth token request failed (HTTP $status)");
        }
        try {
            $payload = json_decode($response, true, 512, JSON_THROW_ON_ERROR);
        } catch (JsonException $error) {
            throw new RuntimeException('Google OAuth returned invalid JSON', 0, $error);
        }
        $accessToken = $payload['access_token'] ?? null;
        $validFor = filter_var($payload['expires_in'] ?? null, FILTER_VALIDATE_INT);
        if (!is_string($accessToken) || $accessToken === '' ||
            $validFor === false || $validFor < 1) {
            throw new RuntimeException('Google OAuth response has no valid access token');
        }
        $cachedToken = $accessToken;
        $expiresAt = time() + $validFor;
        return $cachedToken;
    } finally {
        curl_close($handle);
    }
}

function sendFcmAnnouncement(
    PDO $pdo,
    array $deviceTokens,
    string $projectId,
    string $serviceAccountPath,
    string $title,
    string $body
): array {
    if ($projectId === '' || $serviceAccountPath === '') {
        error_log('FCM push is not configured; in-app announcement was saved.');
        return ['status' => 'not_configured', 'sent_count' => 0, 'failed_count' => 0];
    }
    if ($deviceTokens === []) {
        return ['status' => 'no_devices', 'sent_count' => 0, 'failed_count' => 0];
    }

    $accessToken = fcmAccessToken($serviceAccountPath, $projectId);
    $endpoint = 'https://fcm.googleapis.com/v1/projects/'
        . rawurlencode($projectId) . '/messages:send';
    $sentCount = 0;
    $failedCount = 0;
    $invalidHashes = [];

    foreach (array_chunk($deviceTokens, 25) as $batch) {
        $handles = [];
        $multiHandle = curl_multi_init();
        foreach ($batch as $device) {
            if (!is_array($device) ||
                !is_string($device['token'] ?? null) ||
                !is_string($device['token_hash'] ?? null)) {
                continue;
            }
            $handle = curl_init($endpoint);
            if ($handle === false) {
                $failedCount++;
                continue;
            }
            $message = [
                'message' => [
                    'token' => $device['token'],
                    'notification' => ['title' => $title, 'body' => $body],
                    'data' => [
                        'type' => 'farmer_announcement',
                        'screen' => 'notifications',
                    ],
                    'android' => [
                        'priority' => 'HIGH',
                        'notification' => [
                            'channel_id' => 'harvesthub_announcements',
                        ],
                    ],
                ],
            ];
            curl_setopt_array($handle, [
                CURLOPT_POST => true,
                CURLOPT_POSTFIELDS => json_encode($message, JSON_THROW_ON_ERROR),
                CURLOPT_HTTPHEADER => [
                    'Authorization: Bearer ' . $accessToken,
                    'Content-Type: application/json',
                ],
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_CONNECTTIMEOUT => 5,
                CURLOPT_TIMEOUT => 20,
            ]);
            curl_multi_add_handle($multiHandle, $handle);
            $handles[] = [
                'handle' => $handle,
                'token_hash' => $device['token_hash'],
            ];
        }

        do {
            $multiStatus = curl_multi_exec($multiHandle, $running);
            if ($running > 0 && $multiStatus === CURLM_OK) {
                curl_multi_select($multiHandle, 1.0);
            }
        } while ($running > 0 && $multiStatus === CURLM_OK);

        foreach ($handles as $entry) {
            $handle = $entry['handle'];
            $response = curl_multi_getcontent($handle);
            $status = curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
            if ($multiStatus !== CURLM_OK || !is_string($response) ||
                $status < 200 || $status >= 300) {
                $failedCount++;
                $details = is_string($response) ? json_decode($response, true) : null;
                $errorStatus = $details['error']['status'] ?? null;
                if ($errorStatus === 'UNREGISTERED') {
                    $invalidHashes[] = $entry['token_hash'];
                }
                error_log(sprintf(
                    'FCM message send failed: http_status=%d error_status=%s',
                    $status,
                    is_string($errorStatus) ? $errorStatus : 'unknown'
                ));
            } else {
                $sentCount++;
            }
            curl_multi_remove_handle($multiHandle, $handle);
            curl_close($handle);
        }
        curl_multi_close($multiHandle);
    }

    if ($invalidHashes !== []) {
        $placeholders = implode(',', array_fill(0, count($invalidHashes), '?'));
        $delete = $pdo->prepare(
            "DELETE FROM user_fcm_tokens WHERE token_hash IN ($placeholders)"
        );
        $delete->execute($invalidHashes);
    }

    return [
        'status' => $failedCount === 0 ? 'sent' : ($sentCount > 0 ? 'partial' : 'failed'),
        'sent_count' => $sentCount,
        'failed_count' => $failedCount,
    ];
}
