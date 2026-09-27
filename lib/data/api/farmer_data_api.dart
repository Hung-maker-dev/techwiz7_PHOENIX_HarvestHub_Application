import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';

class FarmerOrderData {
  final String id;
  final String? customerName;
  final double total;
  final String status;
  final DateTime? pickupTime;

  const FarmerOrderData({
    required this.id,
    this.customerName,
    required this.total,
    required this.status,
    this.pickupTime,
  });

  factory FarmerOrderData.fromJson(Map<String, dynamic> json) {
    return FarmerOrderData(
      id: json['id'].toString(),
      customerName: json['customer_name'] as String?,
      total: (json['total'] as num).toDouble(),
      status: json['status'] as String,
      pickupTime: json['pickup_time'] == null
          ? null
          : DateTime.tryParse(json['pickup_time'] as String),
    );
  }
}

class FarmerPickupSlotData {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int capacity;
  final int bookedCount;
  final bool isOpen;

  const FarmerPickupSlotData({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.bookedCount,
    required this.isOpen,
  });

  factory FarmerPickupSlotData.fromJson(Map<String, dynamic> json) {
    return FarmerPickupSlotData(
      id: json['id'].toString(),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      capacity: (json['capacity'] as num).toInt(),
      bookedCount: (json['booked_count'] as num).toInt(),
      isOpen: (json['is_open'] as num).toInt() != 0,
    );
  }
}

class FarmerNotificationData {
  final String id;
  final String title;
  final String? body;
  final String? orderId;
  final String? productId;
  final bool isRead;
  final DateTime createdAt;

  const FarmerNotificationData({
    required this.id,
    required this.title,
    this.body,
    this.orderId,
    this.productId,
    required this.isRead,
    required this.createdAt,
  });

  factory FarmerNotificationData.fromJson(Map<String, dynamic> json) {
    return FarmerNotificationData(
      id: json['id'].toString(),
      title: json['title'] as String,
      body: json['body'] as String?,
      orderId: json['order_id'] as String?,
      productId: json['product_id'] as String?,
      isRead: (json['is_read'] as num).toInt() != 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class FarmerReviewData {
  final String id;
  final String? userName;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const FarmerReviewData({
    required this.id,
    this.userName,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory FarmerReviewData.fromJson(Map<String, dynamic> json) {
    return FarmerReviewData(
      id: json['id'].toString(),
      userName: json['user_name'] as String?,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class FarmerFollowerData {
  final String userId;
  final String userName;
  final String? email;
  final DateTime followedAt;

  const FarmerFollowerData({
    required this.userId,
    required this.userName,
    this.email,
    required this.followedAt,
  });

  factory FarmerFollowerData.fromJson(Map<String, dynamic> json) {
    return FarmerFollowerData(
      userId: json['user_id'].toString(),
      userName: json['user_name'] as String,
      email: json['email'] as String?,
      followedAt: DateTime.parse(json['followed_at'] as String),
    );
  }
}

class FarmerReportData {
  final int totalOrders;
  final double revenue;
  final int completedOrders;
  final int totalProducts;
  final int lowStock;

  const FarmerReportData({
    required this.totalOrders,
    required this.revenue,
    required this.completedOrders,
    required this.totalProducts,
    required this.lowStock,
  });

  factory FarmerReportData.fromJson(Map<String, dynamic> json) {
    return FarmerReportData(
      totalOrders: (json['total_orders'] as num).toInt(),
      revenue: (json['revenue'] as num).toDouble(),
      completedOrders: (json['completed_orders'] as num).toInt(),
      totalProducts: (json['total_products'] as num).toInt(),
      lowStock: (json['low_stock'] as num).toInt(),
    );
  }
}

class FarmerProfileData {
  final String farmName;
  final String address;
  final String? description;
  final String? marketName;
  final double? latitude;
  final double? longitude;
  final String? phone;

  const FarmerProfileData({
    required this.farmName,
    required this.address,
    this.description,
    this.marketName,
    this.latitude,
    this.longitude,
    this.phone,
  });

  factory FarmerProfileData.fromJson(Map<String, dynamic> json) {
    return FarmerProfileData(
      farmName: json['farm_name'] as String,
      address: json['address'] as String? ?? '',
      description: json['description'] as String?,
      marketName: json['market_name'] as String?,
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      phone: json['phone'] as String?,
    );
  }
}

class FarmerAnnouncementDelivery {
  final int recipientCount;
  final String pushStatus;
  final int pushedDeviceCount;
  final int failedDeviceCount;

  const FarmerAnnouncementDelivery({
    required this.recipientCount,
    required this.pushStatus,
    required this.pushedDeviceCount,
    required this.failedDeviceCount,
  });

  factory FarmerAnnouncementDelivery.fromJson(Map<String, dynamic> json) {
    final push = json['push'] as Map<String, dynamic>? ?? const {};
    return FarmerAnnouncementDelivery(
      recipientCount: (json['sent_count'] as num).toInt(),
      pushStatus: push['status'] as String? ?? 'failed',
      pushedDeviceCount: (push['sent_count'] as num?)?.toInt() ?? 0,
      failedDeviceCount: (push['failed_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class FarmerDataApi {
  final Dio _dio;

  FarmerDataApi(this._dio);

  Future<FarmerProfileData> fetchProfile() async {
    try {
      final response = await _dio.get('/api/farmer/profile');
      return FarmerProfileData.fromJson(
          response.data['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<void> updateProfile({
    required String farmName,
    required String address,
    required String phone,
    String? description,
  }) async {
    try {
      await _dio.patch(
        '/api/farmer/profile',
        data: {
          'farm_name': farmName,
          'address': address,
          'phone': phone,
          'description': description,
        },
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<List<FarmerOrderData>> fetchOrders({String? status}) async {
    try {
      final response = await _dio.get(
        '/api/farmer/orders',
        queryParameters: {if (status != null) 'status': status},
      );
      return ((response.data['data'] as List<dynamic>)
          .map((item) => FarmerOrderData.fromJson(item as Map<String, dynamic>))
          .toList());
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<void> updateOrderStatus(String id, String status) async {
    try {
      await _dio.patch('/api/farmer/orders/$id', data: {'status': status});
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<List<FarmerPickupSlotData>> fetchPickupSlots() async {
    try {
      final response = await _dio.get('/api/farmer/pickup-slots');
      return ((response.data['data'] as List<dynamic>)
          .map((item) =>
              FarmerPickupSlotData.fromJson(item as Map<String, dynamic>))
          .toList());
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<void> updatePickupSlot(String id, bool isOpen) async {
    try {
      await _dio.patch(
        '/api/farmer/pickup-slots',
        data: {'id': id, 'is_open': isOpen ? 1 : 0},
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<void> deletePickupSlot(String id) async {
    try {
      await _dio.delete(
        '/api/farmer/pickup-slots',
        queryParameters: {'id': id},
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<void> createPickupSlot({
    required DateTime startTime,
    required DateTime endTime,
    required int capacity,
  }) async {
    try {
      await _dio.post(
        '/api/farmer/pickup-slots',
        data: {
          'start_time': _sqlDateTime(startTime),
          'end_time': _sqlDateTime(endTime),
          'capacity': capacity,
        },
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<List<FarmerNotificationData>> fetchNotifications() async {
    try {
      final response = await _dio.get('/api/farmer/notifications');
      return ((response.data['data'] as List<dynamic>)
          .map((item) =>
              FarmerNotificationData.fromJson(item as Map<String, dynamic>))
          .toList());
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<List<FarmerReviewData>> fetchReviews() async {
    try {
      final response = await _dio.get('/api/farmer/reviews');
      return ((response.data['data'] as List<dynamic>)
          .map(
              (item) => FarmerReviewData.fromJson(item as Map<String, dynamic>))
          .toList());
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<List<FarmerFollowerData>> fetchFollowers() async {
    try {
      final response = await _dio.get('/api/farmer/following');
      return ((response.data['data'] as List<dynamic>)
          .map((item) =>
              FarmerFollowerData.fromJson(item as Map<String, dynamic>))
          .toList());
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<FarmerAnnouncementDelivery> sendAnnouncement({
    required String title,
    required String body,
  }) async {
    try {
      final response = await _dio.post(
        '/api/farmer/announcements',
        data: {'title': title, 'body': body},
      );
      return FarmerAnnouncementDelivery.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await _dio.patch(
        '/api/farmer/notifications',
        data: {'id': id, 'is_read': 1},
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<FarmerReportData> fetchReport() async {
    try {
      final response = await _dio.get('/api/farmer/reports');
      return FarmerReportData.fromJson(
          response.data['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  String _sqlDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:00';
  }
}

final farmerDataApiProvider = Provider<FarmerDataApi>((ref) {
  return FarmerDataApi(ref.watch(dioProvider));
});
