import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/categories_api.dart';
import '../data/api/farmer_products_api.dart';
import '../models/category.dart';
import '../models/product.dart';

final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  final api = ref.watch(categoriesApiProvider);
  return api.fetchCategories();
});

/// Tab lọc trạng thái hiện tại của FarmerHomePage. null = "Tất cả".
final farmerProductFilterProvider = StateProvider<ProductStatus?>((ref) => null);

/// Danh sách sản phẩm của farmer cho tab lọc hiện tại. Tự refetch khi
/// [farmerProductFilterProvider] đổi (family theo status).
final farmerProductsProvider = FutureProvider.autoDispose
    .family<List<Product>, ProductStatus?>((ref, status) async {
  final api = ref.watch(farmerProductsApiProvider);
  return api.fetchMyProducts(status: status);
});

/// Chi tiết một sản phẩm — dùng khi mở màn hình sửa.
final farmerProductDetailProvider = FutureProvider.autoDispose
    .family<Product, String>((ref, productId) async {
  final api = ref.watch(farmerProductsApiProvider);
  return api.fetchProduct(productId);
});
