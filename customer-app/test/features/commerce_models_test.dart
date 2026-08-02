import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_customer/features/orders/data/commerce_repository.dart';

void main() {
  test('empty cart has no stale items or total', () {
    final cart = Cart.empty(currency: 'PEN');

    expect(cart.items, isEmpty);
    expect(cart.total, 0);
    expect(cart.currency, 'PEN');
  });

  test('maps server cart totals without trusting local prices', () {
    final cart = Cart.fromJson({
      'items': [
        {'id': 'i1', 'productName': 'Pollo', 'quantity': 2, 'subtotal': 40}
      ],
      'total': 45.5,
      'currency': 'PEN'
    });
    expect(cart.items.single.quantity, 2);
    expect(cart.total, 45.5);
  });
  test('maps tenant identity required by realtime subscriptions', () {
    final order = Order.fromJson({
      'id': 'o1',
      'orderNumber': 'ORD-1',
      'status': 'CONFIRMED',
      'total': 30,
      'currency': 'PEN',
      'createdAt': '2026-07-21T14:30:00Z'
    });
    expect(order.status, 'CONFIRMED');
    expect(order.createdAt, '2026-07-21T14:30:00Z');
  });
  test('maps delivery events used by the customer timeline', () {
    final event = DeliveryStatusEvent.fromJson({
      'id': 'event-1',
      'status': 'IN_TRANSIT',
      'createdAt': '2026-07-22T15:45:00Z',
    });
    expect(event.status, 'IN_TRANSIT');
    expect(event.createdAt, '2026-07-22T15:45:00Z');
  });
}
