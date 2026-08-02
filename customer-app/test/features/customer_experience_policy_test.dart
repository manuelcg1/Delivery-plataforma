import 'package:delivery_customer/features/courier/data/courier_repository.dart';
import 'package:delivery_customer/features/orders/data/commerce_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('courier notices', () {
    for (final status in const [
      'ASSIGNED',
      'ACCEPTED',
      'PICKED_UP',
      'IN_TRANSIT'
    ]) {
      test('$status remains visible', () {
        expect(isCourierNoticeActive(status), isTrue);
      });
    }
    for (final status in const [
      'DELIVERED',
      'CANCELLED',
      'FAILED',
      'REJECTED',
      'EXPIRED'
    ]) {
      test('$status is hidden', () {
        expect(isCourierNoticeActive(status), isFalse);
      });
    }
  });

  group('order rating', () {
    Order order(String status, {bool rated = false}) => Order(
          id: 'order',
          number: 'ORD-1',
          status: status,
          total: 10,
          currency: 'PEN',
          createdAt: '2026-08-01T00:00:00Z',
          ratingSubmitted: rated,
        );

    test('delivered order without rating can be rated', () {
      expect(canRateOrder(order('DELIVERED')), isTrue);
    });
    test('rated delivered order cannot be rated again', () {
      expect(canRateOrder(order('DELIVERED', rated: true)), isFalse);
    });
    test('active and failed orders cannot be rated', () {
      expect(canRateOrder(order('IN_TRANSIT')), isFalse);
      expect(canRateOrder(order('CANCELLED')), isFalse);
    });
  });
}
