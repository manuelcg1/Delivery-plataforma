import 'package:delivery_customer/features/home/data/customer_repository.dart';
import 'package:delivery_customer/features/orders/presentation/commerce_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const merchant = Merchant(
    id: 'merchant-1',
    code: 'tienda',
    name: 'Tienda',
    description: '',
    branchId: 'branch-1',
    branchName: 'Principal',
    currency: 'PEN',
  );

  testWidgets('product detail keeps the visual fallback without images',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ProductPage(
            merchant: merchant,
            product: Product(
              id: 'product-1',
              name: 'Producto',
              description: 'Descripción',
              price: 10,
              currency: 'PEN',
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.restaurant), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product detail renders an indicator for every gallery image',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ProductPage(
            merchant: merchant,
            product: Product(
              id: 'product-1',
              name: 'Producto',
              description: 'Descripción',
              price: 10,
              currency: 'PEN',
              images: [
                ProductImage(
                    id: '1',
                    url: 'https://invalid.test/1.webp',
                    altText: '',
                    sortOrder: 0,
                    primaryImage: true),
                ProductImage(
                    id: '2',
                    url: 'https://invalid.test/2.webp',
                    altText: '',
                    sortOrder: 1,
                    primaryImage: false),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNWidgets(2));
  });
}
