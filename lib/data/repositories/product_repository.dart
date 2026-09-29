import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
import '../../data/api/customer_api.dart';
import '../../models/product.dart';
import 'cart_repository.dart';

class ProductRepository {
  ProductRepository(this._api, this._cart);

  final CustomerApi _api;
  final CartRepository _cart;

  Future<List<Product>> browse({
    required bool online,
    String? categoryId,
    String? marketId,
    String? farmerId,
    String sort = 'newest',
  }) async {
    if (!online) {
      return _cart.cachedProducts(
        categoryId: categoryId,
        marketId: marketId,
        farmerId: farmerId,
        sort: sort,
      );
    }
    try {
      final products = await _api.fetchProducts(
        categoryId: categoryId,
        marketId: marketId,
        farmerId: farmerId,
        sort: sort,
      );
      await _cart.cacheProducts(products);
      return products;
    } on ApiException catch (error) {
      if (!error.isNetworkError) rethrow;
      final cached = await _cart.cachedProducts(
        categoryId: categoryId,
        marketId: marketId,
        farmerId: farmerId,
      );
      if (cached.isEmpty) rethrow;
      return cached;
    } catch (error, stackTrace) {
      debugPrint('Unable to cache or load products: $error\n$stackTrace');
      rethrow;
    }
  }

  Future<Product?> detail(String id, {required bool online}) async {
    if (!online) return _cart.cachedProduct(id);
    try {
      final product = await _api.fetchProduct(id);
      await _cart.cacheProducts([product]);
      return product;
    } on ApiException catch (error) {
      if (!error.isNetworkError) rethrow;
      return _cart.cachedProduct(id);
    }
  }
}
