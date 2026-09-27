// lib/models/admin/admin_product.dart
//
// Khớp bảng `products` (+ name_en/description_en, deleted_at từ
// harvesthub_mysql_migration.sql). Dùng cho
// GET /api/admin/products?farmer=&category=&status=,
// PATCH /api/admin/products/:id/hide (4.4).
// Model riêng của admin (không tái dùng Product phía customer/farmer) —
// đúng nguyên tắc tách model theo role của dự án.

class AdminProduct {
  final String id;
  final String name;
  final String? nameEn;
  final String categoryId;
  final String? categoryName;
  final double price;
  final String unit;
  final int stock;
  final String? imageUrl;
  final String farmerId;
  final String? farmerName;
  final String? marketId;
  final String? marketName;
  final bool isActive;
  /// true nếu admin đã ẩn (kiểm duyệt nội dung) — khác `isActive` (nông dân
  /// tự bật/tắt bán). API trả cả hai cờ để phân biệt lý do sản phẩm không
  /// hiển thị.
  final bool isHidden;
  final String? hideReason;
  final DateTime updatedAt;

  const AdminProduct({
    required this.id,
    required this.name,
    this.nameEn,
    required this.categoryId,
    this.categoryName,
    required this.price,
    required this.unit,
    required this.stock,
    this.imageUrl,
    required this.farmerId,
    this.farmerName,
    this.marketId,
    this.marketName,
    required this.isActive,
    required this.isHidden,
    this.hideReason,
    required this.updatedAt,
  });

  factory AdminProduct.fromJson(Map<String, dynamic> json) => AdminProduct(
        id: json['id'].toString(),
        name: (json['name'] ?? '') as String,
        nameEn: (json['nameEn'] ?? json['name_en']) as String?,
        categoryId: (json['categoryId'] ?? json['category_id']).toString(),
        categoryName: (json['categoryName'] ?? json['category_name']) as String?,
        price: (json['price'] as num?)?.toDouble() ?? 0,
        unit: (json['unit'] ?? '') as String,
        stock: (json['stock'] ?? 0) as int,
        imageUrl: (json['imageUrl'] ?? json['image_url']) as String?,
        farmerId: (json['farmerId'] ?? json['farmer_id']).toString(),
        farmerName: (json['farmerName'] ?? json['farmer_name']) as String?,
        marketId: (json['marketId'] ?? json['market_id'])?.toString(),
        marketName: (json['marketName'] ?? json['market_name']) as String?,
        isActive: (json['isActive'] ?? json['is_active'] ?? true) as bool,
        isHidden: (json['isHidden'] ?? json['is_hidden'] ?? false) as bool,
        hideReason: (json['hideReason'] ?? json['hide_reason']) as String?,
        updatedAt: DateTime.parse(
            (json['updatedAt'] ?? json['updated_at']) as String),
      );
}
