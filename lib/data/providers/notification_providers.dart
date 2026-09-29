import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/customer_community_api.dart';
import '../api/farmer_data_api.dart';

final customerUnreadNotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final notifications =
      await ref.watch(customerCommunityApiProvider).fetchNotifications();
  return notifications.where((notification) => !notification.isRead).length;
});

final farmerUnreadNotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final notifications =
      await ref.watch(farmerDataApiProvider).fetchNotifications();
  return notifications.where((notification) => !notification.isRead).length;
});
