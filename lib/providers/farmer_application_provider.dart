import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';
import '../data/api/farmer_application_api.dart';
import '../models/farmer_application.dart';

final farmerApplicationApiProvider = Provider<FarmerApplicationApi>((ref) {
  return FarmerApplicationApi(ref.watch(dioProvider));
});

final farmerMarketsProvider =
    FutureProvider.autoDispose<List<FarmerMarketOption>>((ref) {
  return ref.watch(farmerApplicationApiProvider).fetchMarkets();
});

final myFarmerApplicationProvider =
    FutureProvider.autoDispose<FarmerApplication?>((ref) {
  return ref.watch(farmerApplicationApiProvider).fetchMyApplication();
});
