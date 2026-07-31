import 'package:delivery_customer/features/courier/tracking/domain/courier_location_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes the exact backend contract in UTC', () {
    final location = CourierLocationUpdate(
      latitude: -12.0464,
      longitude: -77.0428,
      speed: 25,
      heading: 180,
      accuracy: 8,
      altitude: 120,
      provider: 'gps',
      batteryLevel: 75,
      gpsTimestamp: DateTime.parse('2026-07-28T10:30:00-05:00'),
    );
    expect(location.toJson(), {
      'latitude': -12.0464,
      'longitude': -77.0428,
      'speed': 25,
      'heading': 180,
      'accuracy': 8,
      'altitude': 120,
      'provider': 'gps',
      'batteryLevel': 75,
      'gpsTimestamp': '2026-07-28T15:30:00.000Z',
    });
    expect(location.isValid, isTrue);
  });

  test('omits nullable optional fields', () {
    final json = CourierLocationUpdate(
      latitude: 0,
      longitude: 0,
      accuracy: 0.5,
      provider: 'gps',
      gpsTimestamp: DateTime.utc(2026),
    ).toJson();
    expect(json.keys, {
      'latitude',
      'longitude',
      'accuracy',
      'provider',
      'gpsTimestamp',
    });
  });

  test('rejects invalid coordinates and precision', () {
    expect(
      CourierLocationUpdate(
        latitude: 91,
        longitude: 0,
        accuracy: 0,
        provider: 'gps',
        gpsTimestamp: DateTime.utc(2026),
      ).isValid,
      isFalse,
    );
  });
}
