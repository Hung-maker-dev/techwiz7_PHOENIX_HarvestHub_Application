import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';
import '../../models/product.dart';

enum CustomerOrderStatus {
  pending('Pending'),
  confirmed('Confirmed'),
  readyForPickup('Ready for Pickup'),
  completed('Completed'),
  cancelled('Cancelled');

  const CustomerOrderStatus(this.value);
  final String value;

  static CustomerOrderStatus parse(String value) {
    return CustomerOrderStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw FormatException('Unknown order status: $value'),
    );
  }
}

class CustomerOrderItem {
  const CustomerOrderItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.unit,
    this.imageUrl,
  });

  final String id;
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String? unit;
  final String? imageUrl;

  factory CustomerOrderItem.fromJson(Map<String, dynamic> json) =>
      CustomerOrderItem(
        id: _requiredString(json['id'], 'id'),
        productId: _requiredString(json['product_id'], 'product_id'),
        name: json['name'] as String,
        price: _requiredDouble(json['price'], 'price'),
        quantity: _requiredInt(json['quantity'], 'quantity'),
        unit: json['unit'] as String?,
        imageUrl: _resolveImage(json['image_url']),
      );
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.farmerId,
    required this.total,
    required this.status,
    required this.createdAt,
    this.farmerName,
    this.pickupTime,
    this.items = const [],
    this.hasReview = false,
  });

  final String id;
  final String farmerId;
  final String? farmerName;
  final double total;
  final CustomerOrderStatus status;
  final DateTime createdAt;
  final DateTime? pickupTime;
  final List<CustomerOrderItem> items;
  final bool hasReview;

  factory CustomerOrder.fromJson(Map<String, dynamic> json) => CustomerOrder(
        id: _requiredString(json['id'], 'id'),
        farmerId: _requiredString(json['farmer_id'], 'farmer_id'),
        farmerName: json['farmer_name'] as String?,
        total: _requiredDouble(json['total'], 'total'),
        status: CustomerOrderStatus.parse(json['status'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        pickupTime: DateTime.tryParse(json['pickup_time']?.toString() ?? ''),
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((item) =>
                CustomerOrderItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        hasReview:
            json['has_review'] == true || json['has_review']?.toString() == '1',
      );
}

class CustomerProfile {
  const CustomerProfile({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.preferredLanguage,
    required this.authProvider,
    this.phone,
    this.address,
    this.avatarUrl,
  });

  final String uid;
  final String email;
  final String fullName;
  final String preferredLanguage;
  final String authProvider;
  final String? phone;
  final String? address;
  final String? avatarUrl;

  factory CustomerProfile.fromJson(Map<String, dynamic> json) =>
      CustomerProfile(
        uid: json['uid'].toString(),
        email: json['email'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        preferredLanguage: json['preferred_language'] as String? ?? 'vi',
        authProvider: json['auth_provider'] as String? ?? 'password',
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        avatarUrl: _resolveImage(json['avatar_url']),
      );
}

class CustomerApi {
  CustomerApi(this._dio);

  final Dio _dio;

  Future<List<CustomerOrder>> fetchOrders({String? status}) async {
    try {
      final response = await _dio.get(
        '/api/orders',
        queryParameters: {if (status != null) 'status': status},
      );
      return _mapList(response.data['data'], CustomerOrder.fromJson);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<CustomerOrder> fetchOrder(String id) async {
    try {
      final response = await _dio.get('/api/orders/$id');
      return CustomerOrder.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<void> cancelOrder(String id) async {
    try {
      await _dio.patch('/api/orders/$id/cancel');
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<void> submitReview({
    required String orderId,
    required String productId,
    required String farmerId,
    required int rating,
    String? comment,
  }) async {
    try {
      await _dio.post(
        '/api/reviews',
        data: {
          'order_id': orderId,
          'product_id': productId,
          'farmer_id': farmerId,
          'rating': rating,
          'comment': comment,
        },
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<List<Product>> fetchWishlist() async {
    try {
      final response = await _dio.get('/api/wishlist');
      return _products(response.data['data']);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<void> addWishlist(String productId) async {
    try {
      await _dio.post('/api/wishlist', data: {'product_id': productId});
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<void> removeWishlist(String productId) async {
    try {
      await _dio.delete(
        '/api/wishlist',
        queryParameters: {'product_id': productId},
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<List<Product>> fetchProducts({String? farmerId}) async {
    try {
      final response = await _dio.get(
        '/api/products',
        queryParameters: {if (farmerId != null) 'farmer': farmerId},
      );
      return _products(response.data['data']);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<Map<String, dynamic>> fetchFarmer(String farmerId) async {
    try {
      final response = await _dio.get('/api/farmers/$farmerId');
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<CustomerProfile> fetchProfile() async {
    try {
      final response = await _dio.get('/api/users/me');
      return CustomerProfile.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<CustomerProfile> updateProfile(Map<String, dynamic> values) async {
    try {
      final response = await _dio.patch('/api/users/me', data: values);
      return CustomerProfile.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<String> sendChatMessage({
    required String message,
    required String conversationId,
    required String language,
  }) async {
    try {
      final response = await _dio.post(
        '/api/chatbot/message',
        data: {
          'message': message,
          'conversationId': conversationId,
          'language': language,
        },
      );
      return response.data['answer'] as String;
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  List<Product> _products(dynamic value) => _mapList(value, (item) {
        final normalized = Map<String, dynamic>.from(item);
        normalized['image_url'] = _resolveImage(normalized['image_url']);
        return Product.fromJson(normalized);
      });
}

List<T> _mapList<T>(
  dynamic value,
  T Function(Map<String, dynamic>) parse,
) {
  if (value is! List) {
    throw const FormatException('Expected a list in the customer API response');
  }
  return value
      .map((item) => parse(Map<String, dynamic>.from(item as Map)))
      .toList();
}

String _requiredString(dynamic value, String field) {
  final result = value?.toString();
  if (result == null || result.isEmpty || result == 'null') {
    throw FormatException('Missing required field: $field');
  }
  return result;
}

int _requiredInt(dynamic value, String field) {
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) throw FormatException('Invalid required field: $field');
  return parsed;
}

double _requiredDouble(dynamic value, String field) {
  if (value is num) return value.toDouble();
  final parsed = double.tryParse(value?.toString() ?? '');
  if (parsed == null) throw FormatException('Invalid required field: $field');
  return parsed;
}

String? _resolveImage(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return value.startsWith('/')
      ? Uri.parse(kApiBaseUrl).resolve(value).toString()
      : value;
}

final customerApiProvider = Provider<CustomerApi>(
  (ref) => CustomerApi(ref.watch(dioProvider)),
);
