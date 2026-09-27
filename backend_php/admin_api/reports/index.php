<?php
require_once __DIR__ . '/../admin/common.php';

$db = database();
$method = $_SERVER['REQUEST_METHOD'];
$path = admin_resolve_path();
$pathKey = $path === [] ? '' : implode('/', $path);

function report_period_dates(string $period): array
{
    $now = new DateTimeImmutable('now');
    switch ($period) {
        case 'week':
            $from = $now->modify('-6 days')->setTime(0, 0, 0);
            break;
        case 'quarter':
            $from = $now->modify('-3 months')->setTime(0, 0, 0);
            break;
        case 'year':
            $from = $now->modify('-1 year')->setTime(0, 0, 0);
            break;
        case 'month':
        default:
            $from = $now->modify('-1 month')->setTime(0, 0, 0);
            break;
    }
    return [$from->format('Y-m-d H:i:s'), $now->format('Y-m-d H:i:s')];
}
try {
    if ($method !== 'GET')
        admin_error('Method Not Allowed', 405);
    if ($pathKey === 'system/summary') {
        $totalOrders = (int) $db->query('SELECT COUNT(*) FROM orders')->fetchColumn();
        $totalRevenue = (float) $db->query("SELECT COALESCE(SUM(total),0) FROM orders WHERE status NOT IN ('Cancelled','cancelled')")->fetchColumn();

        $marketRows = [];
        if (admin_column_exists($db, 'orders', 'market_id') && admin_column_exists($db, 'farmers_market', 'id')) {
            $s = $db->query("SELECT o.market_id,m.name market_name,COUNT(*) order_count,COALESCE(SUM(o.total),0) revenue
                           FROM orders o LEFT JOIN farmers_market m ON m.id=o.market_id
                           WHERE o.status NOT IN ('Cancelled','cancelled')
                           GROUP BY o.market_id,m.name ORDER BY revenue DESC");
            $marketRows = $s->fetchAll();
            foreach ($marketRows as &$r) {
                $r['order_count'] = (int) $r['order_count'];
                $r['revenue'] = (float) $r['revenue'];
            }
        }
        $farmers = [];
        if (admin_column_exists($db, 'orders', 'farmer_id') && admin_column_exists($db, 'farmers', 'id')) {
            $s = $db->query("SELECT o.farmer_id,f.farm_name,COUNT(*) order_count,COALESCE(SUM(o.total),0) revenue
                           FROM orders o LEFT JOIN farmers f ON f.id=o.farmer_id
                           WHERE o.status NOT IN ('Cancelled','cancelled')
                           GROUP BY o.farmer_id,f.farm_name ORDER BY order_count DESC,revenue DESC LIMIT 5");
            $farmers = $s->fetchAll();
            foreach ($farmers as &$r) {
                $r['order_count'] = (int) $r['order_count'];
                $r['revenue'] = (float) $r['revenue'];
            }
        }
        $pending = [];
        if (admin_column_exists($db, 'farmers', 'status')) {
            $s = $db->query("SELECT id,farm_name FROM farmers WHERE status='pending' ORDER BY created_at DESC LIMIT 10");
            foreach ($s->fetchAll() as $r)
                $pending[] = ['type' => 'farmer_pending', 'id' => $r['id'], 'title' => $r['farm_name'], 'subtitle' => 'Chờ duyệt nông dân'];
        }
        if (admin_column_exists($db, 'contact_messages', 'status')) {
            $s = $db->query("SELECT id,message FROM contact_messages WHERE status IN ('read','new') ORDER BY created_at DESC LIMIT 10");
            foreach ($s->fetchAll() as $r)
                $pending[] = ['type' => 'contact_message', 'id' => $r['id'], 'title' => $r['message'], 'subtitle' => 'Phản hồi liên hệ mới'];
        }
        admin_json([
            'total_orders' => $totalOrders,
            'total_revenue' => $totalRevenue,
            'revenue_by_market' => $marketRows,
            'most_active_farmers' => $farmers,
            'pending_actions' => $pending,
        ]);
    }

    if ($pathKey === 'system') {
        $period = (string) ($_GET['period'] ?? 'month');
        [$from, $to] = report_period_dates($period);
        $s = $db->prepare("SELECT COUNT(*) FROM orders WHERE created_at BETWEEN :from AND :to");
        $s->execute(['from' => $from, 'to' => $to]);
        $orders = (int) $s->fetchColumn();
        $s = $db->prepare("SELECT COALESCE(SUM(total),0) FROM orders WHERE created_at BETWEEN :from AND :to AND status NOT IN ('Cancelled','cancelled')");
        $s->execute(['from' => $from, 'to' => $to]);
        $revenue = (float) $s->fetchColumn();
        $marketRows = [];
        if (admin_column_exists($db, 'orders', 'market_id') && admin_column_exists($db, 'farmers_market', 'id')) {
            $s = $db->prepare("SELECT o.market_id,m.name market_name,COUNT(*) order_count,COALESCE(SUM(o.total),0) revenue
                FROM orders o LEFT JOIN farmers_market m ON m.id=o.market_id
                WHERE o.created_at BETWEEN :from AND :to AND o.status NOT IN ('Cancelled','cancelled')
                GROUP BY o.market_id,m.name ORDER BY revenue DESC");
            $s->execute(['from' => $from, 'to' => $to]);
            $marketRows = $s->fetchAll();
            foreach ($marketRows as &$r) {
                $r['order_count'] = (int) $r['order_count'];
                $r['revenue'] = (float) $r['revenue'];
            }
        }
        $farmers = [];
        if (admin_column_exists($db, 'orders', 'farmer_id') && admin_column_exists($db, 'farmers', 'id')) {
            $s = $db->prepare("SELECT o.farmer_id,f.farm_name,COUNT(*) order_count,COALESCE(SUM(o.total),0) revenue
                FROM orders o LEFT JOIN farmers f ON f.id=o.farmer_id
                WHERE o.created_at BETWEEN :from AND :to AND o.status NOT IN ('Cancelled','cancelled')
                GROUP BY o.farmer_id,f.farm_name ORDER BY order_count DESC,revenue DESC LIMIT 5");
            $s->execute(['from' => $from, 'to' => $to]);
            $farmers = $s->fetchAll();
            foreach ($farmers as &$r) {
                $r['order_count'] = (int) $r['order_count'];
                $r['revenue'] = (float) $r['revenue'];
            }
        }
        $bestProductsStmt = $db->prepare("SELECT oi.product_id,MAX(oi.name) product_name,
                SUM(oi.quantity) quantity_sold,COALESCE(SUM(oi.quantity * oi.price),0) revenue
                FROM order_items oi JOIN orders o ON o.id=oi.order_id
                WHERE o.status NOT IN ('Cancelled','cancelled') AND o.created_at BETWEEN :from AND :to
                GROUP BY oi.product_id ORDER BY quantity_sold DESC,revenue DESC LIMIT 5");
        $bestProductsStmt->execute(['from' => $from, 'to' => $to]);
        $bestProducts = $bestProductsStmt->fetchAll();
        foreach ($bestProducts as &$r) {
            $r['quantity_sold'] = (int) $r['quantity_sold'];
            $r['revenue'] = (float) $r['revenue'];
        }
        $activeCustomersStmt = $db->prepare("SELECT o.customer_id,
                COALESCE(u.full_name,o.customer_name) customer_name,
                COUNT(*) order_count,COALESCE(SUM(o.total),0) total_spent
                FROM orders o LEFT JOIN users u ON u.uid=o.customer_id
                WHERE o.status NOT IN ('Cancelled','cancelled') AND o.created_at BETWEEN :from AND :to
                GROUP BY o.customer_id,COALESCE(u.full_name,o.customer_name)
                ORDER BY order_count DESC,total_spent DESC LIMIT 5");
        $activeCustomersStmt->execute(['from' => $from, 'to' => $to]);
        $activeCustomers = $activeCustomersStmt->fetchAll();
        foreach ($activeCustomers as &$r) {
            $r['order_count'] = (int) $r['order_count'];
            $r['total_spent'] = (float) $r['total_spent'];
        }
        admin_json([
            'period' => $period,
            'total_orders' => $orders,
            'total_revenue' => $revenue,
            'revenue_by_market' => $marketRows,
            'most_active_farmers' => $farmers,
            'best_selling_products' => $bestProducts,
            'active_customers' => $activeCustomers
        ]);
    }
    admin_error('Report endpoint not found.', 404);
} catch (Throwable $e) {
    error_log('Reports API: ' . $e->getMessage());
    admin_error('Không thể tạo báo cáo. Kiểm tra tên bảng/cột trong database.', 500);
}
