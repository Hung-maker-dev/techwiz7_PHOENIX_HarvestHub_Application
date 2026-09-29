<?php

declare(strict_types=1);

function chatbotNormalizeText(string $value): string
{
    $value = mb_strtolower(trim($value), 'UTF-8');
    $accentGroups = [
        'a' => 'àáạảãâầấậẩẫăằắặẳẵ',
        'd' => 'đ',
        'e' => 'èéẹẻẽêềếệểễ',
        'i' => 'ìíịỉĩ',
        'o' => 'òóọỏõôồốộổỗơờớợởỡ',
        'u' => 'ùúụủũưừứựửữ',
        'y' => 'ỳýỵỷỹ',
    ];
    $replacements = [];
    foreach ($accentGroups as $ascii => $characters) {
        foreach (preg_split('//u', $characters, -1, PREG_SPLIT_NO_EMPTY) as $character) {
            $replacements[$character] = $ascii;
        }
    }
    $value = strtr($value, $replacements);
    $value = preg_replace('/[^a-z0-9]+/', ' ', $value);
    return trim(is_string($value) ? $value : '');
}

function chatbotClassifyIntent(string $message): string
{
    $text = chatbotNormalizeText($message);

    if (preg_match('/\b(hello|hi|xin chao|chao ban|good morning|good afternoon)\b/', $text)) {
        return 'greeting';
    }
    if (preg_match('/\b(help|ban giup|giup duoc gi|lam duoc gi|huong dan)\b/', $text)) {
        return 'help';
    }
    if (preg_match('/\b(pickup|pick up|khung gio|gio nhan|nhan hang|lay hang|khi nao nhan)\b/', $text)) {
        return 'pickup_slots';
    }
    if (preg_match('/\b(market|markets|farmers market|cho nao|dia chi cho|cho nong san|cho gan|tim cho|cac cho|danh sach cho)\b/', $text)) {
        return 'markets';
    }
    if (preg_match('/\b(farmer|farmers|nha vuon|nong dan|nong trai|trang trai)\b/', $text)) {
        return 'farmers';
    }
    $asksForStock = preg_match(
        '/\b(stock|available|in stock|ton kho|con hang|het hang|con khong|con bao nhieu)\b/',
        $text
    ) === 1;
    $asksForPrice = preg_match('/\b(price|cost|how much|gia|gia ban)\b/', $text) === 1;
    if ($asksForStock && !$asksForPrice) {
        return 'product_stock';
    }
    if ($asksForPrice || (str_contains($text, 'bao nhieu') && !$asksForStock)) {
        return 'product_price';
    }
    if ($asksForStock) {
        return 'product_stock';
    }
    if (preg_match('/\b(product|products|san pham|rau cu|nong san|dang ban)\b/', $text)) {
        return 'products';
    }

    return 'general';
}

function chatbotFormatPrice(mixed $price, string $language): string
{
    $formatted = number_format((float) $price, 0, '.', ',');
    return '$' . $formatted;
}

function chatbotFindProduct(array $products, string $message): ?array
{
    $question = ' ' . chatbotNormalizeText($message) . ' ';
    $matches = [];
    foreach ($products as $product) {
        $name = chatbotNormalizeText((string) ($product['name'] ?? ''));
        if ($name !== '' && str_contains($question, ' ' . $name . ' ')) {
            $matches[] = $product;
        }
    }

    if ($matches === []) {
        return null;
    }
    usort(
        $matches,
        static fn (array $left, array $right): int =>
            mb_strlen((string) $right['name']) <=> mb_strlen((string) $left['name'])
    );
    return $matches[0];
}

function chatbotAnswerFromDatabase(PDO $pdo, string $message, string $language): ?string
{
    $intent = chatbotClassifyIntent($message);
    $isEnglish = $language === 'English';
    if ($intent === 'greeting') {
        return $isEnglish
            ? 'Hello! I can help you check produce prices and stock, find farms and markets, or view pickup time slots.'
            : 'Xin chào! Tôi có thể giúp bạn tra giá và tồn kho nông sản, tìm nông trại/chợ hoặc xem khung giờ nhận hàng.';
    }
    if ($intent === 'help') {
        return $isEnglish
            ? 'Ask me about a product price or stock, available produce, farms, markets, or pickup slots.'
            : 'Bạn có thể hỏi giá/tồn kho một sản phẩm, sản phẩm đang bán, nông trại, chợ hoặc khung giờ nhận hàng.';
    }

    if (in_array($intent, ['product_price', 'product_stock', 'products'], true)) {
        $products = $pdo->query(
            'SELECT name,price,unit,stock,farmer_name,market_name '
            . 'FROM products WHERE is_active=1 AND is_hidden=0 AND deleted_at IS NULL '
            . 'ORDER BY name LIMIT 200'
        )->fetchAll();

        if ($intent === 'products') {
            if ($products === []) {
                return $isEnglish
                    ? 'There are currently no active products in the catalog.'
                    : 'Hiện chưa có sản phẩm nào đang được bán.';
            }
            $lines = [];
            foreach (array_slice($products, 0, 10) as $product) {
                $lines[] = sprintf(
                    '%s — %s/%s (%s: %s)',
                    $product['name'],
                    chatbotFormatPrice($product['price'], $language),
                    $product['unit'],
                    $isEnglish ? 'stock' : 'tồn kho',
                    $product['stock']
                );
            }
            $suffix = count($products) > 10
                ? ($isEnglish ? "\nShowing the first 10 products." : "\nĐang hiển thị 10 sản phẩm đầu tiên.")
                : '';
            return ($isEnglish ? "Available products:\n" : "Sản phẩm đang bán:\n")
                . implode("\n", $lines) . $suffix;
        }

        $product = chatbotFindProduct($products, $message);
        if ($product === null) {
            return $isEnglish
                ? 'I could not identify the product name in your question. Please use a product name from the catalog.'
                : 'Tôi chưa nhận ra tên sản phẩm trong câu hỏi. Bạn hãy dùng tên sản phẩm trong danh sách đang bán nhé.';
        }

        if ($intent === 'product_stock') {
            return sprintf(
                $isEnglish
                    ? '%s currently has %s %s in stock. Price: %s per %s.'
                    : '%s hiện còn %s %s. Giá: %s/%s.',
                $product['name'],
                number_format((float) $product['stock'], 0, ',', '.'),
                $product['unit'],
                chatbotFormatPrice($product['price'], $language),
                $product['unit']
            );
        }
        return sprintf(
            $isEnglish
                ? '%s costs %s per %s. Current stock: %s %s.'
                : '%s có giá %s/%s. Tồn kho hiện tại: %s %s.',
            $product['name'],
            chatbotFormatPrice($product['price'], $language),
            $product['unit'],
            number_format((float) $product['stock'], 0, ',', '.'),
            $product['unit']
        );
    }

    if ($intent === 'farmers') {
        $farmers = $pdo->query(
            "SELECT farm_name,market_name,address,rating,rating_count FROM farmers "
            . "WHERE status='approved' AND is_locked=0 AND deleted_at IS NULL "
            . 'ORDER BY farm_name LIMIT 10'
        )->fetchAll();
        if ($farmers === []) {
            return $isEnglish ? 'There are no approved farms to show.' : 'Hiện chưa có nông trại nào được duyệt để hiển thị.';
        }
        $lines = array_map(
            static fn (array $farmer): string => sprintf(
                '%s — %s%s%s',
                $farmer['farm_name'],
                (string) ($farmer['market_name'] ?? ''),
                !empty($farmer['market_name']) && !empty($farmer['address']) ? ', ' : '',
                (string) ($farmer['address'] ?? '')
            ),
            $farmers
        );
        return ($isEnglish ? "Approved farms:\n" : "Nông trại đang hoạt động:\n")
            . implode("\n", $lines);
    }

    if ($intent === 'markets') {
        $markets = $pdo->query(
            'SELECT name,address,open_hours FROM farmers_market '
            . 'WHERE is_active=1 AND deleted_at IS NULL ORDER BY name LIMIT 10'
        )->fetchAll();
        if ($markets === []) {
            return $isEnglish ? 'There are no active markets to show.' : 'Hiện chưa có chợ nào đang hoạt động.';
        }
        $lines = array_map(
            static fn (array $market): string => sprintf(
                '%s — %s%s%s',
                $market['name'],
                (string) ($market['address'] ?? ''),
                !empty($market['open_hours']) ? ($isEnglish ? '; hours: ' : '; giờ mở cửa: ') : '',
                (string) ($market['open_hours'] ?? '')
            ),
            $markets
        );
        return ($isEnglish ? "Active markets:\n" : "Các chợ đang hoạt động:\n")
            . implode("\n", $lines);
    }

    if ($intent === 'pickup_slots') {
        $slots = $pdo->query(
            'SELECT f.farm_name,ps.start_time,ps.end_time '
            . 'FROM pickup_slots ps JOIN farmers f ON f.id=ps.farmer_id '
            . 'WHERE ps.is_open=1 AND ps.capacity>ps.booked_count '
            . 'AND ps.start_time>NOW() AND f.status=\'approved\' '
            . 'AND f.is_locked=0 AND f.deleted_at IS NULL '
            . 'ORDER BY ps.start_time LIMIT 10'
        )->fetchAll();
        if ($slots === []) {
            return $isEnglish
                ? 'There are currently no future pickup slots with availability.'
                : 'Hiện chưa có khung giờ nhận hàng sắp tới còn chỗ.';
        }
        $lines = array_map(
            static fn (array $slot): string => sprintf(
                '%s — %s đến %s',
                $slot['farm_name'],
                $slot['start_time'],
                $slot['end_time']
            ),
            $slots
        );
        return ($isEnglish ? "Available pickup slots:\n" : "Khung giờ nhận hàng còn chỗ:\n")
            . implode("\n", $lines);
    }

    return null;
}

function chatbotBuildDatabaseContext(PDO $pdo): array
{
    return [
        'products' => $pdo->query(
            'SELECT name,price,unit,stock,farmer_name,market_name '
            . 'FROM products WHERE is_active=1 AND is_hidden=0 '
            . 'AND deleted_at IS NULL ORDER BY updated_at DESC LIMIT 100'
        )->fetchAll(),
        'farmers' => $pdo->query(
            "SELECT farm_name,market_name,address,rating,rating_count FROM farmers "
            . "WHERE status='approved' AND is_locked=0 AND deleted_at IS NULL "
            . 'ORDER BY farm_name LIMIT 50'
        )->fetchAll(),
        'markets' => $pdo->query(
            'SELECT name,address,open_hours FROM farmers_market '
            . 'WHERE is_active=1 AND deleted_at IS NULL ORDER BY name LIMIT 50'
        )->fetchAll(),
        'pickup_slots' => $pdo->query(
            'SELECT f.farm_name,ps.start_time,ps.end_time '
            . 'FROM pickup_slots ps JOIN farmers f ON f.id=ps.farmer_id '
            . 'WHERE ps.is_open=1 AND ps.capacity>ps.booked_count '
            . 'AND ps.start_time>NOW() AND f.status=\'approved\' '
            . 'AND f.is_locked=0 AND f.deleted_at IS NULL '
            . 'ORDER BY ps.start_time LIMIT 100'
        )->fetchAll(),
    ];
}
