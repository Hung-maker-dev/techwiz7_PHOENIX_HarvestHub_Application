/// Danh mục sản phẩm — khớp bảng `categories`. `products.category_id` bắt
/// buộc phải là một id có thật trong bảng này (khoá ngoại NOT NULL).
class Category {
  final String id;
  final String name;

  const Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'].toString(),
      name: json['name'] as String,
    );
  }
}
