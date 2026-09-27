import 'package:dio/dio.dart';

import '../../models/farmer_application.dart';

class FarmerApplicationApi {
  FarmerApplicationApi(this._dio);

  final Dio _dio;

  Future<List<FarmerMarketOption>> fetchMarkets() async {
    final response = await _dio.get('/api/farmers_market');
    return (response.data as List)
        .map(
            (item) => FarmerMarketOption.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FarmerApplication?> fetchMyApplication() async {
    final response = await _dio.get('/api/farmer-applications/me');
    final application = (response.data as Map<String, dynamic>)['application'];
    if (application == null) return null;
    return FarmerApplication.fromJson(application as Map<String, dynamic>);
  }

  Future<FarmerApplication> submitApplication({
    required String farmName,
    required String marketId,
    required String address,
    required String contactPhone,
    String? description,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _dio.post(
      '/api/farmer-applications',
      data: {
        'farm_name': farmName,
        'market_id': marketId,
        'address': address,
        'contact_phone': contactPhone,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    return FarmerApplication.fromJson(
        response.data['application'] as Map<String, dynamic>);
  }
}
