import 'package:delivery_customer/core/api/api_client.dart';
import 'package:delivery_customer/core/auth/session_store.dart';
import 'package:delivery_customer/core/widgets/cart_feedback.dart';
import 'package:delivery_customer/features/home/data/customer_repository.dart';
import 'package:delivery_customer/features/orders/data/commerce_repository.dart';
import 'package:delivery_customer/features/orders/presentation/commerce_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const merchant = Merchant(
    id: 'merchant',
    code: 'M',
    name: 'Comercio',
    description: '',
    branchId: 'branch',
    branchName: 'Sucursal',
    currency: 'PEN',
  );
  const product = Product(
    id: 'product',
    name: 'Hamburguesa cl\u00e1sica',
    description: '',
    price: 20,
    currency: 'PEN',
  );

  testWidgets('updates cart and shows success immediately before returning',
      (tester) async {
    final repository = _FakeCommerceRepository();
    await tester.pumpWidget(_testApp(repository, merchant, product));
    await tester.pumpAndSettle();
    expect(find.text('Carrito: 0'), findsOneWidget);

    await tester.tap(find.text('Abrir producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar al carrito'));
    await tester.pumpAndSettle();

    expect(repository.added, isTrue);
    expect(find.text('Agregar al carrito'), findsNothing);
    expect(find.text('Abrir producto'), findsOneWidget);
    expect(find.text('Carrito: 1'), findsOneWidget);
    expect(find.text('Producto agregado'), findsOneWidget);
    expect(find.text('1 \u00d7 Hamburguesa cl\u00e1sica'), findsOneWidget);
  });

  testWidgets('shows add error immediately and stays on product',
      (tester) async {
    final repository = _FakeCommerceRepository(fail: true);
    await tester.pumpWidget(_testApp(repository, merchant, product));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar al carrito'));
    await tester.pump();

    expect(find.text('No se pudo agregar el producto.'), findsOneWidget);
    expect(find.text('Agregar al carrito'), findsOneWidget);
  });
}

Widget _testApp(
    _FakeCommerceRepository repository, Merchant merchant, Product product) {
  return ProviderScope(
    overrides: [commerceRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      scaffoldMessengerKey: cartFeedbackMessengerKey,
      home: Consumer(builder: (context, ref, _) {
        final count = ref.watch(cartProvider).valueOrNull?.items.length ?? 0;
        return Scaffold(
            body: Column(children: [
          Text('Carrito: $count'),
          TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute<ProductAddedResult>(
                  builder: (_) =>
                      ProductPage(merchant: merchant, product: product),
                ),
              );
              if (result == null || !context.mounted) return;
              ref.invalidate(cartProvider);
              showProductAddedSnackBar(
                cartFeedbackMessengerKey.currentState!,
                productName: result.productName,
                quantity: result.quantity,
              );
            },
            child: const Text('Abrir producto'),
          ),
        ]));
      }),
    ),
  );
}

class _FakeCommerceRepository extends CommerceRepository {
  _FakeCommerceRepository({this.fail = false})
      : super(ApiClient('https://example.test',
            const SessionStore(FlutterSecureStorage())));
  final bool fail;
  bool added = false;

  @override
  Future<Cart> add(
      {required String merchantId,
      required String branchId,
      required String productId,
      int quantity = 1}) async {
    if (fail) throw StateError('failed');
    added = true;
    return cart();
  }

  @override
  Future<Cart> cart() async => Cart(
        items: added
            ? const [
                CartItem(
                    id: 'item',
                    name: 'Hamburguesa cl\u00e1sica',
                    quantity: 1,
                    subtotal: 20)
              ]
            : const [],
        total: added ? 20 : 0,
        currency: 'PEN',
        merchantId: 'merchant',
        branchId: 'branch',
        subtotal: added ? 20 : 0,
        discount: 0,
        tax: 0,
        deliveryFee: 0,
      );

  @override
  String errorMessage(Object error) => 'No se pudo agregar el producto.';
}
