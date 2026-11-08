import 'package:delivery_customer/features/orders/data/commerce_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkout ofrece únicamente Yape', () {
    expect(checkoutPaymentMethods.keys, ['YAPE']);
  });
}
