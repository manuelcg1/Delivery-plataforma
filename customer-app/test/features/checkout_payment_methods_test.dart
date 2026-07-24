import 'package:delivery_customer/features/orders/data/commerce_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkout only sends payment methods accepted by the backend', () {
    expect(
      checkoutPaymentMethods.keys,
      unorderedEquals(<String>['CARD', 'CASH_ON_DELIVERY']),
    );
    expect(checkoutPaymentMethods, isNot(contains('CARD_SIMULATED')));
  });
}
