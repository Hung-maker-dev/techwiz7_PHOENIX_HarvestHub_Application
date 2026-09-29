<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

$stage = 'private-directory';

try {
    $private = __DIR__ . '/_private';
    if (!is_dir($private)) {
        throw new RuntimeException('private-directory');
    }

    $stage = 'autoload';
    $autoload = $private . '/vendor/autoload.php';
    if (!is_file($autoload)) {
        throw new RuntimeException('autoload');
    }
    try {
        require $autoload;
    } catch (Throwable $error) {
        throw new RuntimeException('autoload', 0, $error);
    }

    $stage = 'dotenv';
    if (!class_exists(\Dotenv\Dotenv::class)) {
        throw new RuntimeException('dotenv-class-missing');
    }
    $envFile = $private . '/.env';
    if (!is_readable($envFile)) {
        throw new RuntimeException('env-file');
    }
    try {
        \Dotenv\Dotenv::createImmutable($private)->safeLoad();
    } catch (\Dotenv\Exception\InvalidFileException) {
        throw new RuntimeException('env-format');
    } catch (Throwable $error) {
        throw new RuntimeException('dotenv-load', 0, $error);
    }

    $stage = 'source-files';
    foreach (['fcm.php', 'chatbot.php', 'password_reset.php'] as $file) {
        $path = $private . '/src/' . $file;
        if (!is_file($path)) {
            throw new RuntimeException('source-files');
        }
        try {
            require_once $path;
        } catch (Throwable) {
            throw new RuntimeException('source-files');
        }
    }

    $stage = 'database-config';
    $required = ['DB_HOST', 'DB_PORT', 'DB_NAME', 'DB_USER', 'DB_PASSWORD'];
    foreach ($required as $key) {
        if (!array_key_exists($key, $_ENV)) {
            throw new RuntimeException('database-config');
        }
    }
    if (!extension_loaded('pdo_mysql')) {
        throw new RuntimeException('pdo-mysql-unavailable');
    }

    $dsn = sprintf(
        'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
        $_ENV['DB_HOST'],
        $_ENV['DB_PORT'],
        $_ENV['DB_NAME']
    );

    $stage = 'database-connect';
    new PDO($dsn, $_ENV['DB_USER'], $_ENV['DB_PASSWORD'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_TIMEOUT => 5,
    ]);

    echo json_encode(['ok' => true, 'stage' => 'complete']);
} catch (Throwable $error) {
    $result = ['ok' => false, 'stage' => $stage];
    if ($error instanceof PDOException) {
        $result['error'] = 'database-connection-failed';
        $result['code'] = (string) $error->getCode();
    } else {
        $result['error'] = $error->getMessage();
        $result['exception'] = get_class($error);
        if ($error->getPrevious() !== null) {
            $result['cause'] = get_class($error->getPrevious());
            $result['cause_file'] = basename($error->getPrevious()->getFile());
            $result['cause_line'] = $error->getPrevious()->getLine();
        }
    }
    echo json_encode($result);
}
