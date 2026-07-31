import 'package:delivery_customer/features/customer_tracking/domain/customer_tracking_event.dart';
import 'package:delivery_customer/features/customer_tracking/domain/customer_tracking_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const location = {
    'latitude': -12,
    'longitude': -77.0428,
    'speed': 25,
    'heading': 180,
    'accuracy': 8,
    'altitude': 120,
    'gpsTimestamp': '2026-07-31T15:30:00-05:00',
  };

  test('parsea REST con números int/double y normaliza gpsTimestamp a UTC', () {
    final tracking = CustomerOrderTracking.fromJson({
      'orderId': 'order',
      'deliveryId': 'delivery',
      'deliveryStatus': 'IN_TRANSIT',
      'courier': {'courierId': 'courier', 'displayName': 'Carlos M.'},
      'location': location,
      'updatedAt': '2026-07-31T20:30:01Z',
      'trackingActive': true,
      'stale': false,
    });
    expect(tracking.location!.latitude, -12.0);
    expect(tracking.location!.gpsTimestamp.isUtc, isTrue);
    expect(tracking.stale, isFalse);
  });

  test('parsea tracking activo todavía sin ubicación', () {
    final tracking = CustomerOrderTracking.fromJson({
      'orderId': 'order',
      'deliveryStatus': 'PICKED_UP',
      'location': null,
      'trackingActive': true,
      'stale': true,
    });
    expect(tracking.location, isNull);
    expect(tracking.trackingActive, isTrue);
    expect(tracking.stale, isTrue);
  });

  test('parsea evento STOMP', () {
    final event = CustomerTrackingEvent.fromJson({
      'type': 'COURIER_LOCATION_UPDATED',
      'orderId': 'order',
      'deliveryStatus': 'IN_TRANSIT',
      'location': location,
      'publishedAt': '2026-07-31T20:30:01Z',
    });
    expect(event.type, 'COURIER_LOCATION_UPDATED');
    expect(event.location!.accuracy, 8.0);
  });
}
