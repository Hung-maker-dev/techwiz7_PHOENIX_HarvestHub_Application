import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_mobile/data/api/farmer_data_api.dart';
import 'package:harvesthub_mobile/data/api/customer_community_api.dart';
import 'package:harvesthub_mobile/models/product.dart';

void main() {
  group('Farmer product API model', () {
    Map<String, dynamic> productJson({
      int isActive = 1,
      int stock = 5,
      int isHidden = 0,
    }) {
      return {
        'id': 'product-1',
        'farmer_id': 'farmer-1',
        'name': 'Rau cải',
        'price': 12000.0,
        'unit': 'kg',
        'stock': stock,
        'min_stock': 1,
        'category_id': 'category-1',
        'is_active': isActive,
        'is_hidden': isHidden,
        'created_at': '2026-01-01 08:00:00',
      };
    }

    test('maps available, out-of-stock and hidden statuses', () {
      expect(
        Product.fromJson(productJson()).status,
        ProductStatus.active,
      );
      expect(
        Product.fromJson(productJson(stock: 0)).status,
        ProductStatus.outOfStock,
      );
      expect(
        Product.fromJson(productJson(isHidden: 1)).status,
        ProductStatus.hidden,
      );
      expect(
        Product.fromJson(productJson(isActive: 0)).status,
        ProductStatus.hidden,
      );
    });
  });

  test('parses profile coordinates returned as MySQL decimal strings', () {
    final profile = FarmerProfileData.fromJson({
      'farm_name': 'Vườn rau',
      'address': 'Cần Thơ',
      'description': null,
      'market_name': 'Chợ trung tâm',
      'latitude': '10.0277043',
      'longitude': '105.7528362',
      'phone': '0900000000',
    });

    expect(profile.farmName, 'Vườn rau');
    expect(profile.latitude, 10.0277043);
    expect(profile.longitude, 105.7528362);
  });

  test('parses farmer community data returned with MySQL numeric strings', () {
    final farmer = PublicFarmer.fromJson({
      'id': 'farmer-1',
      'farm_name': 'Vườn rau',
      'market_name': 'Chợ trung tâm',
      'address': 'Cần Thơ',
      'description': 'Rau sạch',
      'rating': '4.50',
      'rating_count': '12',
      'follower_count': '8',
    });
    expect(farmer.rating, 4.5);
    expect(farmer.ratingCount, 12);
    expect(farmer.followerCount, 8);

    final notification = CustomerNotification.fromJson({
      'id': 'notification-1',
      'type': 'farmer_announcement',
      'title': 'Rau mới',
      'body': 'Vừa thu hoạch',
      'created_at': '2026-09-26 10:00:00',
      'is_read': '0',
    });
    expect(notification.isRead, isFalse);
    expect(notification.type, 'farmer_announcement');
  });

  test('parses in-app and FCM announcement delivery results', () {
    final delivery = FarmerAnnouncementDelivery.fromJson({
      'ok': true,
      'sent_count': 4,
      'push': {
        'status': 'partial',
        'sent_count': 3,
        'failed_count': 1,
      },
    });

    expect(delivery.recipientCount, 4);
    expect(delivery.pushStatus, 'partial');
    expect(delivery.pushedDeviceCount, 3);
    expect(delivery.failedDeviceCount, 1);
  });
}
