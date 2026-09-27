// lib/models/admin/admin_order.dart
//
// Khớp bảng `orders` + client_order_id/source (harvesthub_mysql_migration.sql,
// khối 2). Admin CHỈ XEM (4.7 nói rõ: "không có nút đổi trạng thái, farmer
// mới được sửa") nên model này không có setter/hàm cập nhật trạng thái.
// Dùng cho GET /api/admin/orders?status=&market=&from=&to=.

enum OrderSource { online, offlineSync }

OrderSource orderSourceFromString(String value) =>
    value == 'offline_sync' ? OrderSource.offlineSync : OrderSource.online;

class AdminOrder {
  final String id;
  final String? clientOrderId;
  final OrderSource source;
  final String status;
  final String? marketId;
  final String? marketName;
  final String? customerName;
  final double totalAmount;
  final DateTime createdAt;

  const AdminOrder({
    required this.id,
    this.clientOrderId,
    required this.source,
    required this.status,
    this.marketId,
    this.marketName,
    this.customerName,
    required this.totalAmount,
    required this.createdAt,
  });

  factory AdminOrder.fromJson(Map<String, dynamic> json) => AdminOrder(
        id: json['id'].toString(),
        clientOrderId: (json['clientOrderId'] ?? json['client_order_id']) as String?,
        source: orderSourceFromString(
            (json['source'] ?? 'online') as String),
        status: (json['status'] ?? '') as String,
        marketId: (json['marketId'] ?? json['market_id'])?.toString(),
        marketName: (json['marketName'] ?? json['market_name']) as String?,
        customerName: (json['customerName'] ?? json['customer_name']) as String?,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ??
            (json['total_amount'] as num?)?.toDouble() ??
            0,
        createdAt: DateTime.parse(
            (json['createdAt'] ?? json['created_at']) as String),
      );
}
