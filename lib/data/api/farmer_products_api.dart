import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';
import '../../models/product.dart';

/// Mọi gọi HTTP liên quan tới `/api/farmer/products` đi qua đây — provider
/// không tự gọi dio trực tiếp (theo cùng convention với OrdersApi).
class FarmerProductsApi {
  final Dio _dio;
  FarmerProductsApi(this._dio);

  /// GET /api/farmer/products?status= — status rỗng/null nghĩa là "Tất cả".
  Future<List<Product>> fetchMyProducts({ProductStatus? status}) async {
    try {
      final res = await _dio.get(
        '/api/farmer/products',
        queryParameters: {
          if (status != null) 'status': status.value,
        },
      );
      final data = res.data;
      final list = (data is Map ? data['data'] : data) as List<dynamic>;
      return list
          .map((e) => Product.fromJson(
              _withAbsoluteImageUrl(e as Map<String, dynamic>)))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// GET /api/farmer/products/:id — chi tiết một sản phẩm.
  Future<Product> fetchProduct(String id) async {
    try {
      final res = await _dio.get('/api/farmer/products/$id');
      final data =
          _withAbsoluteImageUrl(res.data['data'] as Map<String, dynamic>);
      return Product.fromJson(data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// POST /api/farmer/products — tạo sản phẩm mới, trả về id vừa tạo.
  Future<String> createProduct({
    required String name,
    required double price,
    required String unit,
    required int stock,
    required int minStock,
    String? description,
    required String categoryId,
    String? imageUrl,
    XFile? imageFile,
    bool isActive = true,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'price': price,
        'unit': unit,
        'stock': stock,
        'min_stock': minStock,
        'description': description,
        'category_id': categoryId,
        'image_url': imageUrl,
        'is_active': isActive ? 1 : 0,
      };
      if (imageFile != null) {
        data['image'] = await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.name,
        );
      }
      final res = await _dio.post(
        '/api/farmer/products',
        data: imageFile == null ? data : FormData.fromMap(data),
      );
      return (res.data['data']['id'] as Object).toString();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// PUT /api/farmer/products/:id — chỉ gửi các trường cần đổi (partial
  /// update); trường không truyền giữ nguyên giá trị cũ ở backend.
  Future<void> updateProduct(
    String id, {
    String? name,
    String? description,
    double? price,
    String? unit,
    int? stock,
    int? minStock,
    String? categoryId,
    String? imageUrl,
    XFile? imageFile,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (price != null) 'price': price,
        if (unit != null) 'unit': unit,
        if (stock != null) 'stock': stock,
        if (minStock != null) 'min_stock': minStock,
        if (categoryId != null) 'category_id': categoryId,
        if (imageUrl != null) 'image_url': imageUrl,
        if (isActive != null) 'is_active': isActive ? 1 : 0,
      };
      if (imageFile != null) {
        data['image'] = await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.name,
        );
      }
      await _dio.put(
        '/api/farmer/products/$id',
        data: imageFile == null ? data : FormData.fromMap(data),
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// DELETE /api/farmer/products/:id.
  Future<void> deleteProduct(String id) async {
    try {
      await _dio.delete('/api/farmer/products/$id');
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Map<String, dynamic> _withAbsoluteImageUrl(Map<String, dynamic> data) {
    final imageUrl = data['image_url'];
    if (imageUrl is String && imageUrl.startsWith('/')) {
      return {
        ...data,
        'image_url': Uri.parse(kApiBaseUrl).resolve(imageUrl).toString(),
      };
    }
    return data;
  }
}

final farmerProductsApiProvider = Provider<FarmerProductsApi>((ref) {
  return FarmerProductsApi(ref.watch(dioProvider));
});
