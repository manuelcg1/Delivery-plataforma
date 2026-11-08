import 'package:delivery_customer/features/orders/data/yape_checkout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final settings = YapeSettings.fromJson({
    'enabled': true,
    'phone': '999888777',
    'holderName': 'Ana',
    'qrUrl': 'https://example.com/qr',
    'version': 'v1'
  });
  test('configuration requires complete receiver and QR', () {
    expect(settings.available, isTrue);
    expect(YapeSettings.fromJson({'enabled': true}).available, isFalse);
  });
  test('declaration is bound to merchant, total, fee, address and version', () {
    const snapshot = YapeCheckoutSnapshot(
        merchantId: 'm',
        addressId: 'a',
        total: 25,
        deliveryFee: 5,
        currency: 'PEN');
    final declaration = YapeDeclaration(snapshot, settings.version!);
    expect(declaration.matches(snapshot, 'v1'), isTrue);
    expect(declaration.matches(snapshot, 'v2'), isFalse);
    for (final other in [
      const YapeCheckoutSnapshot(
          merchantId: 'other',
          addressId: 'a',
          total: 25,
          deliveryFee: 5,
          currency: 'PEN'),
      const YapeCheckoutSnapshot(
          merchantId: 'm',
          addressId: 'b',
          total: 25,
          deliveryFee: 5,
          currency: 'PEN'),
      const YapeCheckoutSnapshot(
          merchantId: 'm',
          addressId: 'a',
          total: 26,
          deliveryFee: 5,
          currency: 'PEN'),
      const YapeCheckoutSnapshot(
          merchantId: 'm',
          addressId: 'a',
          total: 25,
          deliveryFee: 6,
          currency: 'PEN'),
      const YapeCheckoutSnapshot(
          merchantId: 'm',
          addressId: 'a',
          total: 25,
          deliveryFee: 5,
          currency: 'USD'),
    ]) {
      expect(declaration.matches(other, 'v1'), isFalse);
    }
  });
}
