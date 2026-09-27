import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/farmer_data_api.dart';

final farmerOrdersProvider = FutureProvider.autoDispose
    .family<List<FarmerOrderData>, String?>((ref, status) async {
  return ref.watch(farmerDataApiProvider).fetchOrders(status: status);
});

final farmerPickupSlotsProvider = FutureProvider.autoDispose
    .family<List<FarmerPickupSlotData>, bool>((ref, _) async {
  return ref.watch(farmerDataApiProvider).fetchPickupSlots();
});

final farmerNotificationsProvider = FutureProvider.autoDispose
    .family<List<FarmerNotificationData>, bool>((ref, _) async {
  return ref.watch(farmerDataApiProvider).fetchNotifications();
});

final farmerReviewsProvider = FutureProvider.autoDispose
    .family<List<FarmerReviewData>, bool>((ref, _) async {
  return ref.watch(farmerDataApiProvider).fetchReviews();
});

final farmerFollowersProvider = FutureProvider.autoDispose
    .family<List<FarmerFollowerData>, bool>((ref, _) async {
  return ref.watch(farmerDataApiProvider).fetchFollowers();
});

final farmerReportProvider =
    FutureProvider.autoDispose<FarmerReportData>((ref) {
  return ref.watch(farmerDataApiProvider).fetchReport();
});

final farmerProfileProvider =
    FutureProvider.autoDispose<FarmerProfileData>((ref) {
  return ref.watch(farmerDataApiProvider).fetchProfile();
});
