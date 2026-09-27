import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';

class PublicFarmer {
  final String id;
  final String farmName;
  final String? marketName;
  final String? address;
  final String? description;
  final String? avatarUrl;
  final double rating;
  final int ratingCount;
  final int followerCount;

  const PublicFarmer({
    required this.id,
    required this.farmName,
    this.marketName,
    this.address,
    this.description,
    this.avatarUrl,
    required this.rating,
    required this.ratingCount,
    required this.followerCount,
  });

  factory PublicFarmer.fromJson(Map<String, dynamic> json) => PublicFarmer(
        id: json['id'].toString(),
        farmName: json['farm_name'] as String,
        marketName: json['market_name'] as String?,
        address: json['address'] as String?,
        description: json['description'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        rating: double.tryParse(json['rating']?.toString() ?? '') ?? 0,
        ratingCount: int.tryParse(json['rating_count']?.toString() ?? '') ?? 0,
        followerCount:
            int.tryParse(json['follower_count']?.toString() ?? '') ?? 0,
      );
}

class CustomerNotification {
  final String id;
  final String type;
  final String title;
  final String? body;
  final DateTime createdAt;
  final bool isRead;
  final String? orderId;
  final String? productId;

  const CustomerNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    required this.createdAt,
    required this.isRead,
    this.orderId,
    this.productId,
  });

  factory CustomerNotification.fromJson(Map<String, dynamic> json) =>
      CustomerNotification(
        id: json['id'].toString(),
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        isRead: (int.tryParse(json['is_read']?.toString() ?? '0') ?? 0) != 0,
        orderId: json['order_id']?.toString(),
        productId: json['product_id']?.toString(),
      );
}

class CustomerCommunityApi {
  final Dio _dio;

  CustomerCommunityApi(this._dio);

  Future<List<PublicFarmer>> fetchFarmers() async {
    try {
      final response = await _dio.get('/api/farmers');
      return (response.data['data'] as List<dynamic>)
          .map((item) => PublicFarmer.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<Set<String>> fetchFollowingIds() async {
    try {
      final response = await _dio.get('/api/customer/following');
      return (response.data['data'] as List<dynamic>)
          .map((item) => (item as Map<String, dynamic>)['id'].toString())
          .toSet();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<List<PublicFarmer>> fetchFollowing() async {
    try {
      final response = await _dio.get('/api/customer/following');
      return (response.data['data'] as List<dynamic>)
          .map((item) => PublicFarmer.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<int> setFollowing(String farmerId, {required bool following}) async {
    try {
      final response = following
          ? await _dio.post('/api/farmers/$farmerId/follow')
          : await _dio.delete('/api/farmers/$farmerId/follow');
      return int.tryParse(
            response.data['follower_count']?.toString() ?? '',
          ) ??
          0;
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<List<CustomerNotification>> fetchNotifications() async {
    try {
      final response = await _dio.get('/api/customer/notifications');
      return (response.data['data'] as List<dynamic>)
          .map((item) =>
              CustomerNotification.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await _dio.patch(
        '/api/customer/notifications',
        data: {'id': id},
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await _dio.patch('/api/customer/notifications/read-all');
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}

final customerCommunityApiProvider = Provider<CustomerCommunityApi>((ref) {
  return CustomerCommunityApi(ref.watch(dioProvider));
});
