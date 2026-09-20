import 'package:delivery_customer/features/home/data/customer_repository.dart';
import 'package:delivery_customer/features/home/presentation/home_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const products = <Product>[
    Product(
      id: '1',
      name: 'Pollo a la brasa',
      description: 'Con papas y ensalada',
      price: 33.9,
      currency: 'PEN',
    ),
    Product(
      id: '2',
      name: 'Combo familiar',
      description: 'Incluye pollo entero',
      price: 79.9,
      currency: 'PEN',
    ),
  ];

  test('merchant product search matches name and description', () {
    expect(filterMerchantProducts(products, 'combo'), [products[1]]);
    expect(filterMerchantProducts(products, 'PAPAS'), [products[0]]);
    expect(filterMerchantProducts(products, '  '), products);
    expect(filterMerchantProducts(products, 'pizza'), isEmpty);
  });

  test('merchant product price uses familiar currency symbols', () {
    expect(merchantProductPrice(products.first), 'S/ 33.90');
    expect(
      merchantProductPrice(const Product(
        id: '3',
        name: 'Producto',
        description: '',
        price: 10,
        currency: 'USD',
      )),
      r'$ 10.00',
    );
  });
}
