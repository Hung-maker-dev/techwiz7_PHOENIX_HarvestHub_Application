import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';
import '../../models/category.dart';

/// GET /api/categories — danh sách danh mục còn hoạt động, dùng cho dropdown
/// chọn category_id khi farmer thêm/sửa sản phẩm.
class CategoriesApi {
  final Dio _dio;
  CategoriesApi(this._dio);

  Future<List<Category>> fetchCategories() async {
    try {
      final res = await _dio.get('/api/categories');
      final data = res.data;
      final list = (data is Map ? data['data'] : data) as List<dynamic>;
      return list
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

final categoriesApiProvider = Provider<CategoriesApi>((ref) {
  return CategoriesApi(ref.watch(dioProvider));
});
