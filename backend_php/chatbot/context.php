<?php

declare(strict_types=1);

// ============================================================
// HarvestHub — Chatbot Context API
// ============================================================

require_once __DIR__ . '/../config/cors.php';
require_once __DIR__ . '/../config/database.php';

try {


    $db = database();



    $categorySql = "
        SELECT
            id,
            name,
            name AS name_en
        FROM categories
        WHERE is_active = 1
          AND (
              deleted_at IS NULL
              OR deleted_at IS NOT NULL
          )
        ORDER BY display_order ASC, name ASC
    ";

    $categoryStmt = $db->query($categorySql);
    $categories = $categoryStmt->fetchAll();



    $productSql = "
        SELECT
            id,
            name,
            name_lower,
            name AS name_en,
            category_id,
            price,
            unit,
            stock,
            description,
            description AS description_en,
            image_url,
            is_active,
            farmer_id,
            farmer_name,
            market_id,
            market_name
        FROM products
        WHERE is_active = 1
          AND deleted_at IS NULL
          AND (
              is_hidden = 0
              OR is_hidden IS NULL
          )
        ORDER BY name ASC
    ";

    $productStmt = $db->query($productSql);
    $products = $productStmt->fetchAll();


    $farmerSql = "
        SELECT
            id,
            farm_name,
            address,
            market_id,
            status,
            rating,
            rating_count,
            follower_count,
            description,
            market_name,
            latitude,
            longitude,
            geohash,
            avatar_url
        FROM farmers
        WHERE deleted_at IS NULL
        ORDER BY farm_name ASC
    ";

    $farmerStmt = $db->query($farmerSql);
    $farmers = $farmerStmt->fetchAll();


    $marketSql = "
        SELECT
            id,
            name,
            name_en,
            address,
            latitude,
            longitude,
            geohash,
            open_hours,
            is_active
        FROM farmers_market
        WHERE is_active = 1
          AND deleted_at IS NULL
        ORDER BY name ASC
    ";

    $marketStmt = $db->query($marketSql);
    $markets = $marketStmt->fetchAll();



    foreach ($categories as &$category) {

        $category['id'] = (string) (
            $category['id'] ?? ''
        );

        $category['name'] = (string) (
            $category['name'] ?? ''
        );

        $category['name_en'] = (string) (
            $category['name_en'] ?? ''
        );
    }

    unset($category);



    foreach ($products as &$product) {

        $product['id'] = (string) (
            $product['id'] ?? ''
        );

        $product['name'] = (string) (
            $product['name'] ?? ''
        );

        $product['name_lower'] = (string) (
            $product['name_lower'] ?? ''
        );

        $product['name_en'] = (string) (
            $product['name_en'] ?? ''
        );

        $product['category_id'] = (string) (
            $product['category_id'] ?? ''
        );

        $product['price'] = (float) (
            $product['price'] ?? 0
        );

        $product['unit'] = (string) (
            $product['unit'] ?? ''
        );

        $product['stock'] = (int) (
            $product['stock'] ?? 0
        );

        $product['description'] = (string) (
            $product['description'] ?? ''
        );

        $product['description_en'] = (string) (
            $product['description_en'] ?? ''
        );

        $product['image_url'] = (string) (
            $product['image_url'] ?? ''
        );

        $product['is_active'] = (bool) (
            $product['is_active'] ?? false
        );

        $product['farmer_id'] = (string) (
            $product['farmer_id'] ?? ''
        );

        $product['farmer_name'] = (string) (
            $product['farmer_name'] ?? ''
        );

        $product['market_id'] = (string) (
            $product['market_id'] ?? ''
        );

        $product['market_name'] = (string) (
            $product['market_name'] ?? ''
        );
    }

    unset($product);


    // ========================================================
    // 8. Normalize farmers
    // ========================================================

    foreach ($farmers as &$farmer) {

        $farmer['id'] = (string) (
            $farmer['id'] ?? ''
        );

        $farmer['farm_name'] = (string) (
            $farmer['farm_name'] ?? ''
        );

        $farmer['address'] = (string) (
            $farmer['address'] ?? ''
        );

        $farmer['market_id'] = (string) (
            $farmer['market_id'] ?? ''
        );

        $farmer['status'] = (string) (
            $farmer['status'] ?? ''
        );

        $farmer['rating'] = (float) (
            $farmer['rating'] ?? 0
        );

        $farmer['rating_count'] = (int) (
            $farmer['rating_count'] ?? 0
        );

        $farmer['follower_count'] = (int) (
            $farmer['follower_count'] ?? 0
        );

        $farmer['description'] = (string) (
            $farmer['description'] ?? ''
        );

        $farmer['market_name'] = (string) (
            $farmer['market_name'] ?? ''
        );

        $farmer['latitude'] =
            $farmer['latitude'] !== null
                ? (float) $farmer['latitude']
                : null;

        $farmer['longitude'] =
            $farmer['longitude'] !== null
                ? (float) $farmer['longitude']
                : null;

        $farmer['geohash'] = (string) (
            $farmer['geohash'] ?? ''
        );

        $farmer['avatar_url'] = (string) (
            $farmer['avatar_url'] ?? ''
        );
    }

    unset($farmer);


    // ========================================================
    // 9. Normalize markets
    // ========================================================

    foreach ($markets as &$market) {

        $market['id'] = (string) (
            $market['id'] ?? ''
        );

        $market['name'] = (string) (
            $market['name'] ?? ''
        );

        $market['name_en'] = (string) (
            $market['name_en'] ?? ''
        );

        $market['address'] = (string) (
            $market['address'] ?? ''
        );

        $market['latitude'] =
            $market['latitude'] !== null
                ? (float) $market['latitude']
                : null;

        $market['longitude'] =
            $market['longitude'] !== null
                ? (float) $market['longitude']
                : null;

        $market['geohash'] = (string) (
            $market['geohash'] ?? ''
        );

        $market['open_hours'] = (string) (
            $market['open_hours'] ?? ''
        );

        $market['is_active'] = (bool) (
            $market['is_active'] ?? false
        );
    }

    unset($market);


    // ========================================================
    // 10. Response
    // ========================================================

    echo json_encode(
        [
            'success' => true,

            'data' => [
                'categories' => $categories,
                'products' => $products,
                'farmers' => $farmers,
                'markets' => $markets,
            ],
        ],
        JSON_UNESCAPED_UNICODE |
        JSON_UNESCAPED_SLASHES
    );


} catch (Throwable $e) {

    // ========================================================
    // Local debugging
    // ========================================================

    error_log(
        'HarvestHub chatbot context error: ' .
        $e->getMessage()
    );

    http_response_code(500);

    echo json_encode(
        [
            'success' => false,
            'message' =>
                'Không thể tải dữ liệu cho chatbot',
            'debug' =>
                $e->getMessage(),
        ],
        JSON_UNESCAPED_UNICODE |
        JSON_UNESCAPED_SLASHES
    );
}