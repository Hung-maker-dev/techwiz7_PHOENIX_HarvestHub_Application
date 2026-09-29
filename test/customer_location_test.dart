import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_mobile/shared_widgets/current_location_button.dart';

void main() {
  test('adds GPS coordinates to a delivery address', () {
    expect(
      addressWithGpsCoordinates('12 Main Street', 10.123456789, -106.987654321),
      '12 Main Street\nGPS: 10.1234568, -106.9876543',
    );
  });

  test('replaces previously selected GPS coordinates', () {
    expect(
      addressWithGpsCoordinates(
        '12 Main Street\nGPS: 10.0000000, 106.0000000',
        11,
        107,
      ),
      '12 Main Street\nGPS: 11.0000000, 107.0000000',
    );
  });
}
