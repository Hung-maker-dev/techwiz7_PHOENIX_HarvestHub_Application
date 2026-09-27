import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_mobile/models/admin/admin_farmer.dart';

void main() {
  test('parses MySQL decimal strings for farmer list fields', () {
    final farmer = AdminFarmer.fromJson({
      'id': 'farmer-1',
      'farm_name': 'Green Farm',
      'status': 'pending',
      'is_locked': false,
      'rating': '4.75',
      'rating_count': 2,
      'follower_count': 5,
      'latitude': '10.1234567',
      'longitude': '105.1234567',
      'created_at': '2025-01-01 12:00:00',
    });

    expect(farmer.rating, 4.75);
    expect(farmer.latitude, 10.1234567);
    expect(farmer.longitude, 105.1234567);
  });
}
