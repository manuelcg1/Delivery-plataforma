import 'package:delivery_customer/features/orders/presentation/commerce_pages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detalle consulta mientras la entrega está activa', () {
    expect(shouldPollOrderDetail('PICKED_UP'), isTrue);
    expect(shouldPollOrderDetail('IN_TRANSIT'), isTrue);
    expect(shouldPollOrderDetail('ARRIVED_AT_CUSTOMER'), isTrue);
  });

  test('detalle no consulta después de un estado terminal', () {
    for (final status in const {
      'DELIVERED',
      'FAILED',
      'CANCELLED',
      'REJECTED',
      'EXPIRED',
    }) {
      expect(shouldPollOrderDetail(status), isFalse, reason: status);
    }
  });
}
