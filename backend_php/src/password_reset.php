<?php

declare(strict_types=1);

use PHPMailer\PHPMailer\PHPMailer;

function passwordResetHashKey(): string
{
    $key = trim((string) ($_ENV['PASSWORD_RESET_HASH_KEY'] ?? ''));
    if (strlen($key) < 32) {
        throw new RuntimeException('Password reset hash key is not configured');
    }
    return $key;
}

function passwordResetDigest(string $value): string
{
    return hash_hmac('sha256', $value, passwordResetHashKey());
}

function passwordResetConsumeRateLimit(
    PDO $pdo,
    string $bucket,
    int $limit,
    bool $cooldown
): bool {
    $insert = $pdo->prepare(
        'INSERT IGNORE INTO password_reset_rate_limits '
        . '(bucket_hash,window_started_at,request_count,last_requested_at) '
        . 'VALUES (:bucket_hash,NOW(),0,NULL)'
    );
    $insert->execute([':bucket_hash' => $bucket]);

    $select = $pdo->prepare(
        'SELECT request_count,'
        . '(window_started_at<DATE_SUB(NOW(),INTERVAL 1 HOUR)) AS window_expired,'
        . '(last_requested_at>DATE_SUB(NOW(),INTERVAL 60 SECOND)) AS cooldown_active '
        . 'FROM password_reset_rate_limits WHERE bucket_hash=:bucket_hash FOR UPDATE'
    );
    $select->execute([':bucket_hash' => $bucket]);
    $row = $select->fetch();
    if (!is_array($row)) {
        throw new RuntimeException('Password reset rate limit row could not be loaded');
    }

    $windowExpired = (bool) $row['window_expired'];
    $cooldownActive = $cooldown && (bool) $row['cooldown_active'];
    if ($cooldownActive || (!$windowExpired && (int) $row['request_count'] >= $limit)) {
        return false;
    }

    $update = $pdo->prepare(
        'UPDATE password_reset_rate_limits SET '
        . 'window_started_at=IF(:window_expired=1,NOW(),window_started_at),'
        . 'request_count=IF(:window_expired_again=1,1,request_count+1),'
        . 'last_requested_at=NOW() WHERE bucket_hash=:bucket_hash'
    );
    $expired = $windowExpired ? 1 : 0;
    $update->execute([
        ':window_expired' => $expired,
        ':window_expired_again' => $expired,
        ':bucket_hash' => $bucket,
    ]);
    return true;
}

function passwordResetMailer(): PHPMailer
{
    $host = trim((string) ($_ENV['SMTP_HOST'] ?? ''));
    $username = trim((string) ($_ENV['SMTP_USERNAME'] ?? ''));
    $password = (string) ($_ENV['SMTP_PASSWORD'] ?? '');
    $fromEmail = trim((string) ($_ENV['SMTP_FROM_EMAIL'] ?? $username));
    if ($host === '' || $username === '' || $password === '' || $fromEmail === '') {
        throw new RuntimeException('Password reset SMTP settings are incomplete');
    }

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
        throw new RuntimeException('SMTP_ENCRYPTION must be tls or ssl');
    }
    $mail->CharSet = PHPMailer::CHARSET_UTF8;
    $mail->setFrom(
        $fromEmail,
        (string) ($_ENV['SMTP_FROM_NAME'] ?? 'HarvestHub')
    );
    return $mail;
}

function passwordResetSendCode(string $email, string $code): void
{
    $mail = passwordResetMailer();
    $mail->addAddress($email);
    $mail->isHTML(true);
    $mail->Subject = 'Your HarvestHub password reset code';
    $escapedCode = htmlspecialchars($code, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    $mail->Body = '<p>Use this code to reset your HarvestHub password:</p>'
        . '<p style="font-size:28px;font-weight:bold;letter-spacing:8px">'
        . $escapedCode . '</p><p>This code expires in 10 minutes. '
        . 'If you did not request a password reset, you can ignore this email.</p>';
    $mail->AltBody = "Your HarvestHub password reset code is $code. "
        . 'It expires in 10 minutes. If you did not request a reset, ignore this email.';
    $mail->send();
}

function passwordResetBase64UrlEncode(string $value): string
{
    return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
}

function passwordResetAdminToken(string $serviceAccountPath, string $projectId): string
{
    if (!is_readable($serviceAccountPath)) {
        throw new RuntimeException('Firebase Admin service account file is not readable');
    }
    $rawCredentials = file_get_contents($serviceAccountPath);
    if (!is_string($rawCredentials)) {
        throw new RuntimeException('Firebase Admin service account file could not be read');
    }
    try {
        $credentials = json_decode($rawCredentials, true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException $error) {
        throw new RuntimeException(
            'Firebase Admin service account JSON is invalid',
            0,
            $error
        );
    }

    $clientEmail = $credentials['client_email'] ?? null;
    $privateKey = $credentials['private_key'] ?? null;
    $tokenUri = $credentials['token_uri'] ?? 'https://oauth2.googleapis.com/token';
    if (!is_string($clientEmail) || !filter_var($clientEmail, FILTER_VALIDATE_EMAIL) ||
        !is_string($privateKey) || !is_string($tokenUri) ||
        !str_starts_with($tokenUri, 'https://') ||
        ($credentials['project_id'] ?? null) !== $projectId) {
        throw new RuntimeException('Firebase Admin service account credentials are incomplete');
    }

    $issuedAt = time();
    $unsignedToken = passwordResetBase64UrlEncode(json_encode(
        ['alg' => 'RS256', 'typ' => 'JWT'],
        JSON_THROW_ON_ERROR
    )) . '.' . passwordResetBase64UrlEncode(json_encode([
        'iss' => $clientEmail,
        'scope' => 'https://www.googleapis.com/auth/cloud-platform',
        'aud' => $tokenUri,
        'iat' => $issuedAt,
        'exp' => $issuedAt + 3600,
    ], JSON_THROW_ON_ERROR));
    $key = openssl_pkey_get_private($privateKey);
    if ($key === false ||
        !openssl_sign($unsignedToken, $signature, $key, OPENSSL_ALGO_SHA256)) {
        throw new RuntimeException('Could not sign Firebase Admin service account assertion');
    }

    $handle = curl_init($tokenUri);
    if ($handle === false) {
        throw new RuntimeException('Could not initialize Google OAuth request');
    }
    curl_setopt_array($handle, [
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $unsignedToken . '.' . passwordResetBase64UrlEncode($signature),
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
        $payload = json_decode($response, true, 512, JSON_THROW_ON_ERROR);
        $accessToken = $payload['access_token'] ?? null;
        if (!is_string($accessToken) || $accessToken === '') {
            throw new RuntimeException('Google OAuth response has no access token');
        }
        return $accessToken;
    } finally {
        curl_close($handle);
    }
}

function passwordResetUpdateFirebasePassword(
    string $uid,
    string $password,
    string $serviceAccountPath,
    string $projectId
): void {
    $accessToken = passwordResetAdminToken($serviceAccountPath, $projectId);
    $url = 'https://identitytoolkit.googleapis.com/v1/projects/'
        . rawurlencode($projectId) . '/accounts:update';
    $handle = curl_init($url);
    if ($handle === false) {
        throw new RuntimeException('Could not initialize Firebase password update');
    }
    curl_setopt_array($handle, [
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode([
            'localId' => $uid,
            'password' => $password,
        ], JSON_THROW_ON_ERROR),
        CURLOPT_HTTPHEADER => [
            'Authorization: Bearer ' . $accessToken,
            'Content-Type: application/json',
        ],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 5,
        CURLOPT_TIMEOUT => 15,
    ]);
    try {
        $response = curl_exec($handle);
        $status = curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        if (!is_string($response) || $status < 200 || $status >= 300) {
            throw new RuntimeException("Firebase password update failed (HTTP $status)");
        }
    } finally {
        curl_close($handle);
    }
}

function passwordResetRequest(PDO $pdo): never
{
    $body = requestBody();
    $email = strtolower(trim((string) ($body['email'] ?? '')));
    if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 254) {
        respond(['error' => 'Valid email is required'], 422);
    }

    passwordResetHashKey();
    $serviceAccountPath = trim(
        (string) ($_ENV['FIREBASE_ADMIN_SERVICE_ACCOUNT_PATH'] ?? '')
    );
    $projectId = trim((string) ($_ENV['FIREBASE_PROJECT_ID'] ?? ''));
    if ($serviceAccountPath === '' || $projectId === '') {
        throw new RuntimeException('Firebase Admin password reset settings are incomplete');
    }
    passwordResetMailer();

    $emailHash = passwordResetDigest('email:' . $email);
    $ipHash = passwordResetDigest('ip:' . (string) ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
    $pdo->beginTransaction();
    $allowed = passwordResetConsumeRateLimit($pdo, $emailHash, 5, true) &&
        passwordResetConsumeRateLimit($pdo, $ipHash, 20, false);
    if (!$allowed) {
        $pdo->rollBack();
        respond(['error' => 'Please wait before requesting another code'], 429);
    }

    $user = $pdo->prepare(
        'SELECT uid FROM users WHERE LOWER(email)=:email LIMIT 1'
    );
    $user->execute([':email' => $email]);
    $uid = $user->fetchColumn();
    $code = (string) random_int(100000, 999999);
    $codeHash = password_hash($code, PASSWORD_DEFAULT);
    $save = $pdo->prepare(
        'INSERT INTO password_reset_otps '
        . '(email_hash,user_uid,code_hash,code_expires_at,attempts,reset_token_hash,'
        . 'reset_token_expires_at,updated_at) '
        . 'VALUES (:email_hash,:user_uid,:code_hash,DATE_ADD(NOW(),INTERVAL 10 MINUTE),'
        . '0,NULL,NULL,NOW()) ON DUPLICATE KEY UPDATE user_uid=VALUES(user_uid),'
        . 'code_hash=VALUES(code_hash),code_expires_at=VALUES(code_expires_at),'
        . 'attempts=0,reset_token_hash=NULL,reset_token_expires_at=NULL,updated_at=NOW()'
    );
    $save->execute([
        ':email_hash' => $emailHash,
        ':user_uid' => $uid === false ? null : (string) $uid,
        ':code_hash' => $codeHash,
    ]);
    $pdo->commit();

    if ($uid !== false) {
        passwordResetSendCode($email, $code);
    }
    respond([
        'message' => 'If the email is registered, a reset code has been sent.',
    ]);
}

function passwordResetVerifyCode(PDO $pdo): never
{
    $body = requestBody();
    $email = strtolower(trim((string) ($body['email'] ?? '')));
    $code = trim((string) ($body['code'] ?? ''));
    if (!filter_var($email, FILTER_VALIDATE_EMAIL) || !preg_match('/^\d{6}$/', $code)) {
        respond(['error' => 'The code is invalid or expired'], 422);
    }

    $emailHash = passwordResetDigest('email:' . $email);
    $pdo->beginTransaction();
    $select = $pdo->prepare(
        'SELECT user_uid,code_hash,attempts,'
        . '(code_expires_at>NOW()) AS code_is_valid '
        . 'FROM password_reset_otps WHERE email_hash=:email_hash FOR UPDATE'
    );
    $select->execute([':email_hash' => $emailHash]);
    $row = $select->fetch();
    $valid = is_array($row) && is_string($row['user_uid']) &&
        $row['user_uid'] !== '' && is_string($row['code_hash']) &&
        (int) $row['attempts'] < 5 &&
        (bool) $row['code_is_valid'] &&
        password_verify($code, $row['code_hash']);

    if (!$valid) {
        if (is_array($row) && (int) $row['attempts'] < 5) {
            $increment = $pdo->prepare(
                'UPDATE password_reset_otps SET attempts=attempts+1,updated_at=NOW() '
                . 'WHERE email_hash=:email_hash'
            );
            $increment->execute([':email_hash' => $emailHash]);
        }
        $pdo->commit();
        respond(['error' => 'The code is invalid or expired'], 422);
    }

    $resetToken = bin2hex(random_bytes(32));
    $update = $pdo->prepare(
        'UPDATE password_reset_otps SET code_hash=NULL,code_expires_at=NULL,'
        . 'reset_token_hash=:token_hash,'
        . 'reset_token_expires_at=DATE_ADD(NOW(),INTERVAL 10 MINUTE),updated_at=NOW() '
        . 'WHERE email_hash=:email_hash'
    );
    $update->execute([
        ':token_hash' => passwordResetDigest('token:' . $resetToken),
        ':email_hash' => $emailHash,
    ]);
    $pdo->commit();
    respond(['reset_token' => $resetToken]);
}

function passwordResetComplete(PDO $pdo): never
{
    $body = requestBody();
    $token = trim((string) ($body['reset_token'] ?? ''));
    $password = (string) ($body['password'] ?? '');
    if (!preg_match('/^[a-f0-9]{64}$/', $token) ||
        strlen($password) < 8 || strlen($password) > 128) {
        respond(['error' => 'A valid reset token and password are required'], 422);
    }

    $tokenHash = passwordResetDigest('token:' . $token);
    $pdo->beginTransaction();
    $select = $pdo->prepare(
        'SELECT email_hash,user_uid FROM password_reset_otps '
        . 'WHERE reset_token_hash=:token_hash '
        . 'AND reset_token_expires_at>NOW() FOR UPDATE'
    );
    $select->execute([':token_hash' => $tokenHash]);
    $row = $select->fetch();
    if (!is_array($row) || !is_string($row['user_uid']) || $row['user_uid'] === '') {
        $pdo->rollBack();
        respond(['error' => 'The reset session is invalid or expired'], 422);
    }

    $serviceAccountPath = trim(
        (string) ($_ENV['FIREBASE_ADMIN_SERVICE_ACCOUNT_PATH'] ?? '')
    );
    $projectId = trim((string) ($_ENV['FIREBASE_PROJECT_ID'] ?? ''));
    if ($serviceAccountPath === '' || $projectId === '') {
        throw new RuntimeException('Firebase Admin password reset settings are incomplete');
    }
    passwordResetUpdateFirebasePassword(
        (string) $row['user_uid'],
        $password,
        $serviceAccountPath,
        $projectId
    );

    $delete = $pdo->prepare(
        'DELETE FROM password_reset_otps WHERE email_hash=:email_hash'
    );
    $delete->execute([':email_hash' => $row['email_hash']]);
    $pdo->commit();
    respond(['message' => 'Password updated successfully']);
}

function passwordResetHandleRoute(string $method, string $path, PDO $pdo): bool
{
    $routes = [
        '/api/auth/password-reset/request' => 'passwordResetRequest',
        '/api/auth/password-reset/verify-code' => 'passwordResetVerifyCode',
        '/api/auth/password-reset/complete' => 'passwordResetComplete',
    ];
    if (!isset($routes[$path])) {
        return false;
    }
    if ($method !== 'POST') {
        respond(['error' => 'Method not allowed'], 405);
    }
    $routes[$path]($pdo);
    return true;
}
