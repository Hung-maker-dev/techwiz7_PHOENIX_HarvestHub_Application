<?php

declare(strict_types=1);

// Cấu hình MySQL trên máy local (XAMPP/Laragon).
// KHÔNG upload file này lên hosting, KHÔNG commit lên git.
return [
    'host' => '127.0.0.1',
    'port' => 3306,
    'db'   => 'harvesthub',   // tên database bạn tạo trên MySQL local
    'user' => 'root',
    'pass' => '',             // điền nếu root của bạn có mật khẩu
];