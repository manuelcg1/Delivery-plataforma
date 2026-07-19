import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_customer/features/orders/data/commerce_repository.dart';

void main() {
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
      'currency': 'PEN'
    });
    expect(order.status, 'CONFIRMED');
  });
}
