import 'package:delivery_customer/features/home/data/customer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds the favorite that belongs to a merchant', () {
    const favorite = Favorite(
      id: 'favorite-1',
      name: 'Comercio 1',
      description: '',
      merchantId: 'merchant-1',
      productId: null,
    );

    expect(favoriteForMerchant([favorite], 'merchant-1'), same(favorite));
    expect(favoriteForMerchant([favorite], 'merchant-2'), isNull);
  });
}
