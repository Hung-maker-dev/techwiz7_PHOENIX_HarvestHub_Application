<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit("This script can only be run from the command line.\n");
}

require dirname(__DIR__) . '/vendor/autoload.php';

use Dotenv\Dotenv;

$root = dirname(__DIR__);
Dotenv::createImmutable($root)->safeLoad();

$email = trim($argv[1] ?? '');
if ($email === '' || filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
    fwrite(STDERR, "Usage: php cli/grant_admin.php <email>\n");
    exit(2);
}

try {
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

    $statement = $pdo->prepare('SELECT uid, role FROM users WHERE email = :email LIMIT 1');
    $statement->execute([':email' => $email]);
    $user = $statement->fetch();
    if (!$user) {
        fwrite(STDERR, "No user found for email: $email\n");
        exit(1);
    }
    if ($user['role'] === 'admin') {
        fwrite(STDOUT, "This user is already an admin.\n");
        exit(0);
    }

    $currentAdmin = $pdo->query(
        "SELECT uid, email FROM users WHERE role = 'admin' LIMIT 1"
    )->fetch();
    if ($currentAdmin && $currentAdmin['uid'] !== $user['uid']) {
        fwrite(
            STDERR,
            "An admin already exists ({$currentAdmin['email']}); only one admin account is allowed.\n"
        );
        exit(1);
    }

    $update = $pdo->prepare('UPDATE users SET role = :role WHERE uid = :uid');
    $update->execute([':role' => 'admin', ':uid' => $user['uid']]);
    fwrite(STDOUT, "Granted admin role to $email (uid: {$user['uid']}).\n");
} catch (Throwable $error) {
    fwrite(STDERR, 'Failed to grant admin role: ' . $error->getMessage() . PHP_EOL);
    exit(1);
}
