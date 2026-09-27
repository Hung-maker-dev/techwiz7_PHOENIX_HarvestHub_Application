import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_mobile/data/api/customer_api.dart';

void main() {
  group('CustomerOrder', () {
    test('parses an order and its items from the PHP API shape', () {
      final order = CustomerOrder.fromJson({
        'id': 'order-1',
        'farmer_id': 'farmer-1',
        'farmer_name': 'Vườn Xanh',
        'total': '125000.50',
        'status': 'Ready for Pickup',
        'created_at': '2026-09-26 12:30:00',
        'pickup_time': null,
        'has_review': 0,
        'items': [
          {
            'id': '7',
            'product_id': 'product-1',
            'name': 'Rau cải',
            'price': '25000',
            'quantity': '5',
            'unit': 'bó',
            'image_url': null,
          },
        ],
      });

      expect(order.id, 'order-1');
      expect(order.status, CustomerOrderStatus.readyForPickup);
      expect(order.total, 125000.5);
      expect(order.items.single.quantity, 5);
      expect(order.items.single.price, 25000);
      expect(order.hasReview, isFalse);
    });

    test('rejects an unknown order status instead of treating it as pending',
        () {
      expect(
        () => CustomerOrderStatus.parse('Unexpected'),
        throwsFormatException,
      );
    });

    test('rejects a malformed required amount', () {
      expect(
        () => CustomerOrder.fromJson({
          'id': 'order-1',
          'farmer_id': 'farmer-1',
          'total': 'not-a-number',
          'status': 'Pending',
          'created_at': '2026-09-26 12:30:00',
        }),
        throwsFormatException,
      );
    });
  });

  test('CustomerProfile distinguishes password and federated accounts', () {
    final profile = CustomerProfile.fromJson({
      'uid': 'user-1',
      'email': 'customer@example.test',
      'full_name': 'Nguyễn An',
      'preferred_language': 'vi',
      'auth_provider': 'google',
      'phone': null,
      'address': null,
      'avatar_url': null,
    });

    expect(profile.authProvider, 'google');
    expect(profile.preferredLanguage, 'vi');
    expect(profile.avatarUrl, isNull);
  });
}
