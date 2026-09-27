import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_mobile/models/admin/admin_account.dart';

void main() {
  test('parses account type, approval state, and MySQL lock values', () {
    final account = AdminAccount.fromJson({
      'id': 'user-1',
      'name': 'Farmer Applicant',
      'email': 'farmer@example.com',
      'role': 'customer',
      'account_type': 'farmer',
      'application_status': 'pending',
      'farmer_id': 'farm-1',
      'created_at': '2026-09-26 12:00:00',
      'is_locked': '0',
      'phone': '0123456789',
      'farm_name': 'Green Farm',
      'latitude': '10.1234567',
      'longitude': '105.1234567',
    });

    expect(account.accountType, 'farmer');
    expect(account.applicationStatus, 'pending');
    expect(account.isLocked, isFalse);
    expect(account.farmName, 'Green Farm');
    expect(account.farmerId, 'farm-1');
    expect(account.latitude, 10.1234567);
    expect(account.longitude, 105.1234567);
  });
}
