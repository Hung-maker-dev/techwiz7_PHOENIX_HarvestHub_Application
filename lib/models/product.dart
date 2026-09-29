enum ProductStatus {
  active('active'),
  outOfStock('out_of_stock'),
  hidden('hidden');

  final String value;
  const ProductStatus(this.value);

  static ProductStatus fromValue(String value) {
    return ProductStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => ProductStatus.active,
    );
  }
}

class Product {
  final String id;
  final String farmerId;
  final String? farmerName;
  final String name;
  final String? description;
  final double price;
  final String unit;
  final int stock;
  final int minStock;
  final String categoryId;
  final String? categoryName;
  final String? imageUrl;
  final bool isActive;
  final int soldCount;
  final ProductStatus status;
  final DateTime createdAt;

  int get stockQuantity => stock;

  const Product({
    required this.id,
    required this.farmerId,
    this.farmerName,
    required this.name,
    this.description,
    required this.price,
    required this.unit,
    required this.stock,
    required this.minStock,
    required this.categoryId,
    this.categoryName,
    this.imageUrl,
    required this.isActive,
    this.soldCount = 0,
    required this.status,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      farmerId: json['farmer_id'].toString(),
      farmerName: json['farmer_name'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      unit: json['unit'] as String,
      stock: (json['stock'] as num).toInt(),
      minStock: (json['min_stock'] as num?)?.toInt() ?? 0,
      categoryId: json['category_id'].toString(),
      categoryName: json['category_name'] as String?,
      imageUrl: json['image_url'] as String?,
      isActive: (json['is_active'] as num?)?.toInt() != 0,
      soldCount: (json['sold_count'] as num?)?.toInt() ?? 0,
      // 'status' do API tính sẵn (active/out_of_stock/hidden); nếu backend
      // cũ chưa trả field này thì tự suy ra tương tự phía server.
      status: json['status'] != null
          ? ProductStatus.fromValue(json['status'] as String)
          : (((json['is_active'] as num?)?.toInt() ?? 1) == 0 ||
                  ((json['is_hidden'] as num?)?.toInt() ?? 0) != 0
              ? ProductStatus.hidden
              : (((json['stock'] as num?)?.toInt() ?? 0) <= 0
                  ? ProductStatus.outOfStock
                  : ProductStatus.active)),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
