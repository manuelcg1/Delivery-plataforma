import 'package:delivery_customer/features/courier/data/courier_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps courier delivery history used by the timeline', () {
    final event = CourierDeliveryHistory.fromJson({
      'id': 'history-1',
      'status': 'DELIVERED',
      'createdAt': '2026-07-22T18:30:00Z',
    });

    expect(event.status, 'DELIVERED');
    expect(event.createdAt, '2026-07-22T18:30:00Z');
  });
}
