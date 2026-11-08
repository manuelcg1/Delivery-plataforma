import 'package:cached_network_image/cached_network_image.dart';
import 'package:delivery_customer/features/home/data/customer_repository.dart';
import 'package:delivery_customer/features/home/presentation/merchant_catalog_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const merchant = Merchant(
    id: 'm',
    code: 'cafe',
    name: 'Café',
    description: 'Café y panes recién preparados.',
    branchId: 'b',
    branchName: 'Principal',
    currency: 'PEN',
    bannerUrl: 'https://example.test/banner.webp');
void main() {
  testWidgets(
      'merchant header uses its configured banner and branch information',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MerchantCatalogHeader(merchant: merchant))));
    expect(find.text('Café'), findsOneWidget);
    expect(find.text('Principal'), findsOneWidget);
    expect(find.text(merchant.description), findsOneWidget);
    expect(
        tester
            .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
            .imageUrl,
        merchant.bannerUrl);
    expect(find.text('Abierto'), findsNothing);
  });
  testWidgets('missing or failed banner retains merchant information',
      (tester) async {
    const noBanner = Merchant(
        id: 'm',
        code: 'c',
        name: 'Tienda',
        description: '',
        branchId: 'b',
        branchName: 'Sucursal',
        currency: 'PEN');
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MerchantCatalogHeader(merchant: noBanner))));
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    expect(find.text('Tienda'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MerchantCatalogHeader(merchant: merchant))));
    final image =
        tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: image.errorWidget!(
                tester.element(find.byType(CachedNetworkImage)),
                merchant.bannerUrl!,
                Exception('image failed')))));
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
  });
  testWidgets(
      'product row exposes description price detail and original tap without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    const product = Product(
        id: 'p',
        name: 'Sándwich de pollo artesanal',
        description:
            'Pollo deshilachado, lechuga y tomate en pan artesanal recién horneado.',
        price: 14.9,
        currency: 'PEN');
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
                body: MerchantCatalogProductCard(
                    product: product,
                    priceLabel: 'S/ 14.90',
                    onTap: () => taps++)))));
    expect(find.text(product.description), findsOneWidget);
    expect(find.text('S/ 14.90'), findsOneWidget);
    expect(find.text('Ver detalle'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Ver detalle'));
    expect(taps, 1);
  });
}
